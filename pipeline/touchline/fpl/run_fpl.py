"""Build the FPL bundle: python -m touchline.fpl.run_fpl [--train]

--train  refit the minutes model on the archive, evaluate on the latest complete season against
         FPL's own expected points, and save both (weekly job).
default  load the saved model, pull live FPL data, score the next six gameweeks, pre-solve
         Wildcard and Free Hit squads, write out/fpl-bundle.json.gz (daily job)."""
import argparse
import gzip
import json
import logging
import pickle
from datetime import UTC, datetime
from pathlib import Path

import numpy as np
import pandas as pd

from touchline import config
from touchline.fpl import fetch, optimise
from touchline.fpl.evaluate import bootstrap_mae_gain, evaluate, gate
from touchline.fpl.features import fixture_strength, gw_table, player_gw_features, position_priors
from touchline.fpl.minutes import baseline_last_gw, brier_multi, fit_minutes, minutes_class
from touchline.fpl.model import model_rows, strength_context
from touchline.fpl.points import PARTS, per_gameweek, predict_points
from touchline.fpl.teams import club_id
from touchline.ingest.load import load_tm

log = logging.getLogger("touchline.fpl")
TRAIN = ["2022-23", "2023-24", "2024-25"]
TEST = "2025-26"
HORIZON = 6
POS = {1: "GK", 2: "DEF", 3: "MID", 4: "FWD"}
BUDGETS = list(range(950, 1101, 10))
GRID_POOL = 150
SCHEMA = 1


def season_label(events: list[dict]) -> str:
    y = int(events[0]["deadline_time"][:4])
    return f"{y}-{(y + 1) % 100:02d}"


def next_gameweek(events: list[dict], now: datetime) -> dict | None:
    """First gameweek whose deadline is still ahead (a passed deadline moves on)."""
    for e in sorted(events, key=lambda e: e["id"]):
        if not e["finished"] and pd.Timestamp(e["deadline_time"]) > pd.Timestamp(now):
            return e
    return None


def live_history(boot: dict, season: str, get=fetch._get) -> pd.DataFrame:
    """This season's finished gameweeks in the archive's shape, from event/{gw}/live."""
    teams = {t["id"]: t["name"] for t in boot["teams"]}
    els = {e["id"]: e for e in boot["elements"]}
    rows = []
    for ev in boot["events"]:
        if not ev["finished"]:
            continue
        live = json.loads(get(f"{fetch.API}/event/{ev['id']}/live/"))
        for el in live["elements"]:
            meta = els.get(el["id"])
            if meta is None:
                continue
            s = el["stats"]
            rows.append({
                "season": season, "gw": ev["id"], "element": el["id"],
                "name": f"{meta['first_name']} {meta['second_name']}",
                "position": POS[meta["element_type"]], "team": teams[meta["team"]],
                "minutes": s["minutes"], "starts": s.get("starts", 0),
                "total_points": s["total_points"], "xP": np.nan,
                "expected_goals": float(s.get("expected_goals", 0) or 0),
                "expected_assists": float(s.get("expected_assists", 0) or 0),
                "goals_scored": s["goals_scored"], "assists": s["assists"],
                "clean_sheets": s["clean_sheets"], "goals_conceded": s["goals_conceded"],
                "saves": s["saves"], "bonus": s["bonus"], "yellow_cards": s["yellow_cards"],
                "red_cards": s["red_cards"],
                "defensive_contribution": s.get("defensive_contribution", 0),
                "value": meta["now_cost"], "selected": 0,
                "fixture": el["explain"][0]["fixture"] if el["explain"] else 0,
                "opponent_team": 0, "was_home": False, "kickoff_time": pd.NaT,
            })
    return pd.DataFrame(rows)


def target_rows(boot: dict, season: str, gw: int) -> pd.DataFrame:
    """An empty row per current player at the target gameweek, so walk-forward features are
    computed for it from everything before."""
    teams = {t["id"]: t["name"] for t in boot["teams"]}
    return pd.DataFrame([{
        "season": season, "gw": gw, "element": e["id"],
        "name": f"{e['first_name']} {e['second_name']}", "position": POS[e["element_type"]],
        "team": teams[e["team"]], "value": e["now_cost"], "selected": 0, "xP": np.nan,
        **dict.fromkeys(["minutes", "starts", "total_points", "expected_goals",
                         "expected_assists", "goals_scored", "assists", "clean_sheets",
                         "goals_conceded", "saves", "bonus", "yellow_cards", "red_cards",
                         "defensive_contribution", "fixture", "opponent_team"], 0),
        "was_home": False, "kickoff_time": pd.NaT,
    } for e in boot["elements"]])


def horizon_rows(feats_now: pd.DataFrame, boot: dict, fixtures: list[dict], gws: list[int],
                 strength: pd.DataFrame) -> pd.DataFrame:
    """Player-fixture rows for each horizon gameweek; blank gameweeks simply have no row."""
    team_id = {t["name"]: t["id"] for t in boot["teams"]}
    feats_now = feats_now.assign(team_id=feats_now.team.map(team_id))
    st = strength[strength.event.isin(gws)]
    rows = feats_now.drop(columns=["gw"]).merge(
        st[["fixture", "event", "team", "att_mult", "p_cs", "lam_against", "lam_for"]],
        left_on="team_id", right_on="team", suffixes=("", "_fx")).rename(columns={"event": "gw"})
    return rows.drop(columns=["team_fx"], errors="ignore")


def train(raw: Path, out: Path, tm: dict) -> dict:
    hist, model = strength_context(tm, pd.Timestamp(f"{TEST[:4]}-07-01", tz="UTC"))
    rows = model_rows(TRAIN + [TEST], TRAIN, raw, hist, model)
    is_val = (rows.season == TRAIN[-1]) & (rows.gw >= 30)
    tr, val, te = rows[rows.season.isin(TRAIN) & ~is_val], rows[is_val], rows[rows.season == TEST]
    mm = fit_minutes(tr, val)
    y = minutes_class(te.minutes)
    pred = per_gameweek(predict_points(te, mm))
    act = gw_table(fetch.load_archive([TEST], raw)).merge(
        te.groupby(["season", "gw", "element"]).min_last3.first().reset_index(),
        on=["season", "gw", "element"])
    m = evaluate(pred, act)
    m.update({"mae_gain_ci": bootstrap_mae_gain(pred, act),
              "minutes_brier": brier_multi(mm.predict(te), y),
              "minutes_brier_baseline": brier_multi(baseline_last_gw(te), y),
              "train_seasons": TRAIN, "test_season": TEST})
    m["source"] = gate(m)
    log.info("FPL eval %s", m)
    # the shipped minutes model learns from every season, early-stopped on the latest's end
    alln = rows[~((rows.season == TEST) & (rows.gw >= 30))]
    final = fit_minutes(alln, rows[(rows.season == TEST) & (rows.gw >= 30)])
    (out / "fpl_models").mkdir(parents=True, exist_ok=True)
    (out / "fpl_models" / "minutes.pkl").write_bytes(pickle.dumps(final))
    (out / "fpl_metrics.json").write_text(json.dumps(m, indent=2))
    (out / "fpl_cases.json").write_text(json.dumps(optimise.golden_cases()))
    return m


def score_live(raw: Path, out: Path, tm: dict, now: datetime, live: dict | None = None) -> dict:
    mm = pickle.loads((out / "fpl_models" / "minutes.pkl").read_bytes())
    metrics = json.loads((out / "fpl_metrics.json").read_text())
    live = live or fetch.fetch_live(raw)
    boot, fixtures = live["bootstrap"], live["fixtures"]
    season = season_label(boot["events"])
    nxt = next_gameweek(boot["events"], now)
    if nxt is None:
        raise SystemExit("season over: no upcoming gameweek")
    gws = [e["id"] for e in sorted(boot["events"], key=lambda e: e["id"])
           if e["id"] >= nxt["id"]][:HORIZON]

    arch = fetch.load_archive(TRAIN + [TEST], raw)
    cur = pd.concat([live_history(boot, season), target_rows(boot, season, nxt["id"])],
                    ignore_index=True)
    gwt = gw_table(pd.concat([arch, cur], ignore_index=True))
    feats = player_gw_features(gwt, position_priors(gwt[gwt.season != season]))
    now_feats = feats[(feats.season == season) & (feats.gw == nxt["id"])]

    hist, model = strength_context(tm, pd.Timestamp(now))
    names = {t["id"]: t["name"] for t in boot["teams"]}
    fx = pd.DataFrame([f for f in fixtures if f.get("event")])
    fx["kickoff_time"] = pd.to_datetime(fx.kickoff_time, utc=True)
    strength = fixture_strength(fx[["id", "event", "kickoff_time", "team_h", "team_a"]], names,
                                hist, model)
    rows = horizon_rows(now_feats, boot, fixtures, gws, strength)
    els = {e["id"]: e for e in boot["elements"]}
    first = rows.gw == gws[0]
    chance = rows.element.map(lambda i: els[i]["chance_of_playing_next_round"])
    long_out = rows.element.map(lambda i: els[i]["status"] in ("i", "s", "u", "n")
                                and els[i]["chance_of_playing_next_round"] == 0)
    rows["chance"] = np.where(first | long_out, chance.astype(float), np.nan)
    rows["season"] = season
    pred = per_gameweek(predict_points(rows, mm))
    source = metrics.get("source", "fpl")
    return build_bundle(boot, nxt, gws, pred, metrics, source, now, season)


def build_bundle(boot, nxt, gws, pred, metrics, source, now, season) -> dict:
    teams = {t["id"]: t for t in boot["teams"]}
    by = {(r.element, r.gw): r for r in pred.itertuples()}
    players, xmap = [], {}
    for e in boot["elements"]:
        if e.get("removed"):
            continue
        xs = [round(float(by[(e["id"], g)].xpts), 2) if (e["id"], g) in by else 0.0
              for g in gws]
        if source == "fpl":  # FPL's own number for next gameweek, repeated (flagged)
            xs = [round(float(e.get("ep_next") or 0.0), 2)] * len(gws)
        nxt_row = by.get((e["id"], gws[0]))
        why = {p: round(float(getattr(nxt_row, p)), 2) for p in PARTS} if nxt_row and \
            source == "ours" else None
        xmap[e["id"]] = xs
        players.append({
            "id": e["id"], "name": e["web_name"],
            "full": f"{e['first_name']} {e['second_name']}", "team": e["team"],
            "pos": POS[e["element_type"]], "price": e["now_cost"], "status": e["status"],
            "news": e["news"] or None, "chance": e["chance_of_playing_next_round"],
            "sel": float(e["selected_by_percent"]),
            "p_play": round(float(nxt_row.p_play), 3) if nxt_row else 0.0,
            "xpts": xs, "why": why,
        })
    pool = [optimise.Player(p["id"], p["pos"], p["team"], p["price"]) for p in players
            if p["status"] != "u"]
    horizon5 = {p.id: sum(xmap[p.id][:5]) for p in pool}
    top = sorted(pool, key=lambda p: -horizon5[p.id])[:GRID_POOL]
    cheap = [p for pos in optimise.SQUAD for p in
             sorted((q for q in pool if q.pos == pos), key=lambda q: q.price)[:10]]
    grid_pool = list({p.id: p for p in top + cheap}.values())
    wildcard = [{"budget": b, "squad": optimise.solve_squad(grid_pool, b, horizon5)}
                for b in BUDGETS]
    free_hit = [{"gw": g, "budget": b,
                 "squad": optimise.solve_squad(grid_pool, b, {p.id: xmap[p.id][k]
                                                              for p in grid_pool})}
                for k, g in enumerate(gws) for b in BUDGETS]
    return {
        "fpl_schema_version": SCHEMA, "generated_at": now.strftime("%Y-%m-%dT%H:%M:%SZ"),
        "season": season, "source": source, "next_gw": nxt["id"],
        "gameweeks": [{"id": e["id"], "name": e["name"], "deadline": e["deadline_time"]}
                      for e in boot["events"] if e["id"] in gws],
        "teams": [{"id": t["id"], "name": t["name"], "short": t["short_name"],
                   "club_id": club_id(t["name"])} for t in teams.values()],
        "players": players, "wildcard": wildcard, "free_hit": free_hit, "models": metrics,
    }


def main(argv=None) -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--train", action="store_true")
    ap.add_argument("--out", type=Path, default=config.OUT_DIR)
    args = ap.parse_args(argv)
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(message)s")
    raw = config.DATA_DIR / "raw" / "fpl"
    tm = load_tm()
    if args.train:
        train(raw, args.out, tm)
    bundle = score_live(raw, args.out, tm, datetime.now(UTC))
    data = json.dumps(bundle, separators=(",", ":")).encode()
    (args.out / "fpl-bundle.json.gz").write_bytes(gzip.compress(data, mtime=0))
    log.info("fpl bundle %.2f MB, %d players, gw %s, source %s", len(data) / 1e6,
             len(bundle["players"]), bundle["next_gw"], bundle["source"])


if __name__ == "__main__":
    main()
