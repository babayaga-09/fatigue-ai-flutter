"""Touchline pipeline: python -m touchline.run --help"""
import argparse
import json
import logging
import os
import sys
from dataclasses import asdict
from datetime import datetime, timezone
from pathlib import Path

import pandas as pd
from dotenv import load_dotenv

from touchline import config
from touchline.export.bundle import sanitize, write_bundle
from touchline.features.players import (add_prev_season, build_player_rows, enrich_appearances,
                                        season_stats)
from touchline.ingest.club_map import load_overrides
from touchline.ingest.download import download_tables
from touchline.ingest.football_data import FootballData
from touchline.ingest.load import load_tm
from touchline.models import (budget, elo, form, match_model, similarity, trending, valuator,
                              workload)
from touchline.season import build_current_season, offline_clubs

log = logging.getLogger("touchline")

GATES = [("club_elo", "favourite_accuracy", "baseline_home_pick_accuracy", "higher"),
         ("match_model", "rps", "baseline_rps", "lower"),
         ("valuator", "mae_eur", "baseline_mae_eur", "lower"),
         ("form", "poisson_deviance", "baseline_poisson_deviance", "lower")]

BUDGET_CASES = [(50, {"Attack": 1}),
                (100, {"Attack": 1, "Midfield": 1, "Defender": 1}),
                (200, {"Attack": 2, "Midfield": 2, "Defender": 2, "Goalkeeper": 1})]


def check_gates(metrics: dict) -> list[str]:
    fails = []
    for model, key, base, better in GATES:
        m = metrics[model]
        ok = m[key] > m[base] if better == "higher" else m[key] < m[base]
        if not ok:
            fails.append(f"{model}: {key}={m[key]:.4f} does not beat {base}={m[base]:.4f}")
    return fails


def _season_label(s: int) -> str:
    return f"{s}/{str(s + 1)[-2:]}"


def _fmt(d: pd.Timestamp) -> str:
    return d.strftime("%Y-%m-%d")


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="Build the Touchline data bundle.")
    ap.add_argument("--skip-download", action="store_true")
    ap.add_argument("--offline", action="store_true", help="skip football-data.org")
    ap.add_argument("--fast", action="store_true", help="fewer sims/epochs for smoke runs")
    ap.add_argument("--no-gate", action="store_true")
    ap.add_argument("--out", type=Path, default=config.OUT_DIR)
    args = ap.parse_args(argv)
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(message)s")
    load_dotenv(config.ROOT / ".env")

    if not args.skip_download:
        log.info("downloading dataset")
        download_tables(force=True)
    tm = load_tm()
    games, players, vals = tm["games"], tm["players"], tm["valuations"].sort_values("date")
    leagues = list(config.LEAGUES)
    lg_games = games[games.competition_id.isin(leagues)]
    test_season = int(lg_games.season.max())
    log.info("test season %s", test_season)
    metrics: dict = {}

    # M1 — club Elo
    params, _ = elo.tune_elo(games, (games.season == test_season - 1)
                             & games.competition_id.isin(leagues))
    elo_res = elo.run_elo(games, params)
    metrics["club_elo"] = {"params": asdict(params),
                           **elo.evaluate_favourites(games, elo_res.pre, test_season,
                                                     params.home_adv)}
    log.info("M1 %s", metrics["club_elo"])

    # M2 — match model (evaluated on the held-out season, then refit on everything)
    lg = lg_games.merge(elo_res.pre, on="game_id")
    lg["d"] = lg.elo_home - lg.elo_away
    train = lg[(lg.season >= config.MODEL_FROM_SEASON) & (lg.season < test_season)]
    test = lg[lg.season == test_season]
    m2 = match_model.fit_match_model(train.d, train.home_goals, train.away_goals)
    metrics["match_model"] = match_model.evaluate(m2, train, test)
    full = lg[lg.season >= config.MODEL_FROM_SEASON]
    m2_final = match_model.fit_match_model(full.d, full.home_goals, full.away_goals)
    log.info("M2 %s", metrics["match_model"])

    # Clubs + M3 season projection
    token = os.environ.get("FOOTBALL_API_KEY", "").strip()
    today = pd.Timestamp.now(tz="UTC")
    if args.offline or not token:
        clubs, fixtures = offline_clubs(games, tm["clubs"], elo_res, test_season), []
        clubs_through = _fmt(lg_games.date.max())
    else:
        fd = FootballData(token)
        clubs, fixtures = build_current_season(fd, tm["clubs"], elo_res, params, m2_final,
                                               config.current_season(), load_overrides(), today,
                                               n_sims=2000 if args.fast else 10000)
        clubs_through = _fmt(today)
    log.info("clubs %d fixtures %d", len(clubs), len(fixtures))

    # Player features
    eapps = enrich_appearances(tm["appearances"], games)
    stats = add_prev_season(season_stats(eapps, games))
    rows = build_player_rows(stats, players, vals, elo_res.history)

    # M4 — valuator; display population = players at a top-5 club with test-season stats
    val_model, metrics["valuator"] = valuator.run_valuator(rows, test_season)
    log.info("M4 %s", metrics["valuator"])
    cur = players[players.league.isin(leagues) & (players.last_season >= test_season)]
    disp = stats[(stats.season == test_season) & stats.player_id.isin(cur.player_id)]
    disp_rows = build_player_rows(disp, players, vals, elo_res.history,
                                  min_league_minutes=config.MIN_DISPLAY_MINUTES,
                                  with_target=False)
    fair = dict(zip(disp_rows.player_id, val_model.predict(disp_rows)))
    why = dict(zip(disp_rows.player_id, val_model.explain(disp_rows)))

    # M5 — form forecast
    feats = form.appearance_features(eapps, elo_res.pre)
    pool = set(stats[(stats.league_minutes > 0)
                     & (stats.season >= config.MODEL_FROM_SEASON)].player_id)
    seqs = form.build_sequences(feats, players, pool, stride=10 if args.fast else 5)
    form_model, metrics["form"] = form.run_form(
        seqs, pd.Timestamp(test_season - 1, 7, 1), pd.Timestamp(test_season, 7, 1),
        epochs=3 if args.fast else 15)
    log.info("M5 %s", metrics["form"])
    latest = form.latest_windows(feats, players, set(disp.player_id))
    forecast = dict(zip(latest.player_id, form_model.predict(latest)))

    # M6 — workload
    wl = workload.workload_table(tm["appearances"], players, pd.Timestamp(test_season, 7, 1),
                                 set(disp.player_id)).set_index("player_id")
    metrics["workload"] = {"n": int(len(wl)), "bands": wl.band.value_counts().to_dict(),
                           "flagged": int(wl.flag.sum())}

    # M7 — similarity among qualified players
    sim = similarity.similar_players(disp_rows)

    # Trending
    last5 = feats[feats.player_id.isin(disp.player_id)].groupby("player_id").tail(5)
    l5 = last5.groupby("player_id").agg(last5_ga=("ga", "sum"), last5_minutes=("minutes", "sum"))
    v_now = vals.groupby("player_id").value.last()
    v_ago = vals[vals.date <= vals.date.max() - pd.Timedelta(days=182)].groupby(
        "player_id").value.last()
    tr_in = disp[["player_id", "minutes", "ga90"]].set_index("player_id").join(l5)
    tr_in["value_now"] = v_now
    tr_in["value_6m_ago"] = v_ago
    tr_in["forecast_ga5"] = pd.Series(forecast, dtype=float)
    trend = trending.trending(tr_in.reset_index()).set_index("player_id")

    # Assemble player records
    pinfo = players.set_index("player_id")
    st = disp.set_index("player_id")
    yearly = vals.assign(y=vals.date.dt.year).groupby(["player_id", "y"]).tail(1)
    yearly = yearly[yearly.date >= vals.date.max() - pd.Timedelta(days=6 * 365)]
    hist_by = {p: g for p, g in yearly[yearly.player_id.isin(disp.player_id)].groupby("player_id")}
    transfers = tm["transfers"].sort_values("date")
    tr_by = {p: g.tail(5) for p, g in
             transfers[transfers.player_id.isin(disp.player_id)].groupby("player_id")}
    l5_by = {p: g for p, g in last5.groupby("player_id")}
    now_naive = today.tz_localize(None)
    out_players = []
    for pid in disp.player_id:
        p, s = pinfo.loc[pid], st.loc[pid]
        qualified = s.minutes >= config.MIN_DISPLAY_MINUTES
        fv = fair.get(pid) if qualified else None
        mv = float(p.market_value) if pd.notna(p.market_value) else None
        w = wl.loc[pid] if pid in wl.index else None
        out_players.append({
            "id": int(pid), "name": p["name"], "img": p.image_url,
            "club": int(p.current_club_id) if pd.notna(p.current_club_id) else None,
            "league": p.league, "pos": p.position, "sub_pos": p.sub_position,
            "age": round((now_naive - p.dob).days / 365.25, 1) if pd.notna(p.dob) else None,
            "nat": p.nationality, "foot": p.foot, "height": p.height,
            "market_value": mv, "fair_value": round(float(fv), -5) if fv else None,
            "value_gap_pct": (fv - mv) / mv if (fv and mv) else None,
            "value_why": why.get(pid) if fv else None,
            "season": {"apps": int(s.apps), "minutes": int(s.minutes), "goals": int(s.goals),
                       "assists": int(s.assists), "ga90": round(float(s.ga90), 2)},
            "form": {"last5": [{"date": _fmt(r.date), "opp": r.opp_name, "ga": int(r.ga),
                                "min": int(r.minutes)} for r in l5_by[pid].itertuples()]
                     if pid in l5_by else [],
                     "forecast_ga5": round(float(forecast[pid]), 2)
                     if (pid in forecast and qualified) else None},
            "workload": None if w is None else {
                "index": int(w["index"]), "band": w.band, "acwr": round(float(w.acwr), 2),
                "season_minutes": int(w.season_minutes), "congested_apps": int(w.congested_apps),
                "flag": bool(w.flag), "as_of": _fmt(w.ref_date)},
            "value_history": [[_fmt(r.date), int(r.value)] for r in hist_by[pid].itertuples()]
            if pid in hist_by else [],
            "transfers": [{"date": _fmt(r.date), "from": r.from_club, "to": r.to_club,
                           "fee": r.fee} for r in tr_by[pid].itertuples()]
            if pid in tr_by else [],
            "similar": sim.get(int(pid), []),
            "trend": {"score": trend.loc[pid, "trend_score"],
                      "reasons": trend.loc[pid, "reasons"]},
        })

    # M8 — budget planner golden cases (the app ports the planner and checks against these)
    cand = pd.DataFrame([{"player_id": p["id"], "pos": p["pos"],
                          "price": p["market_value"] / 1e6, "score": p["fair_value"] / 1e6}
                         for p in out_players if p["fair_value"] and p["market_value"]])
    score = cand.set_index("player_id").score
    cases = []
    for b, needs in BUDGET_CASES:
        ilp = budget.plan_signings(cand, b, needs)
        gr = budget.greedy_signings(cand, b, needs)
        cases.append({"budget_m": b, "needs": needs, "ilp": ilp, "greedy": gr,
                      "ilp_score": float(score.loc[ilp].sum()),
                      "greedy_score": float(score.loc[gr].sum())})
    metrics["budget"] = {"cases": [{k: c[k] for k in ("budget_m", "ilp_score", "greedy_score")}
                                   for c in cases]}

    bundle = {
        "schema_version": config.SCHEMA_VERSION,
        "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "data_through": {"players": _fmt(tm["appearances"].date.max()), "clubs": clubs_through},
        "player_season": _season_label(test_season),
        "leagues": [{"id": k, "fd": v[0], "name": v[1]} for k, v in config.LEAGUES.items()],
        "clubs": clubs, "fixtures": fixtures, "players": out_players, "models": metrics,
    }
    args.out.mkdir(parents=True, exist_ok=True)
    size = write_bundle(bundle, args.out / config.BUNDLE_NAME)
    (args.out / "metrics.json").write_text(json.dumps(sanitize(metrics), indent=2))
    (args.out / "budget_cases.json").write_text(json.dumps(sanitize(cases), indent=2))
    log.info("bundle %.2f MB, %d players", size / 1e6, len(out_players))

    fails = check_gates(metrics)
    for f in fails:
        log.error("GATE FAILED %s", f)
    return 1 if (fails and not args.no_gate) else 0


if __name__ == "__main__":
    sys.exit(main())
