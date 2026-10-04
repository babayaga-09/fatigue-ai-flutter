"""Current-season club snapshot: Elo continued into the live season, table, projections."""
import numpy as np
import pandas as pd

from touchline.config import LEAGUES
from touchline.ingest.club_map import map_clubs
from touchline.models.elo import EloParams, EloResult, run_elo
from touchline.models.match_model import MatchModel
from touchline.models.season_sim import league_table, simulate_season

_DONE = {"FINISHED", "AWARDED"}
_DEAD = {"CANCELLED"}
_TABLE_KEYS = ["pos", "played", "points", "gd", "gf", "ga"]


def _iso(ts: pd.Timestamp) -> str:
    return ts.tz_convert("UTC").strftime("%Y-%m-%dT%H:%M:%SZ")


def _form(club: int, played: pd.DataFrame) -> list[str]:
    rows = played[(played.home == club) | (played.away == club)].sort_values("utc").tail(5)
    out = []
    for h, hg, ag in rows[["home", "home_goals", "away_goals"]].itertuples(index=False):
        gf, ga = (hg, ag) if h == club else (ag, hg)
        out.append("W" if gf > ga else "D" if gf == ga else "L")
    return out


def _rating_at(history: pd.DataFrame, club: int, when: pd.Timestamp, default: float) -> float:
    h = history[(history.club_id == club) & (history.date <= when)]
    return float(h.rating.iloc[-1]) if len(h) else default


def league_snapshot(league, teams, matches, ratings, history, params: EloParams,
                    model: MatchModel, today: pd.Timestamp, n_sims: int = 10000):
    ids = [int(c) for c in teams.club_id]
    ratings = dict(ratings)
    known = [ratings[c] for c in ids if c in ratings]
    if len(known) >= 5:
        floor = float(np.percentile(known, 15))
    else:
        floor = min(known) if known else params.init
    for c in ids:
        if c not in ratings:
            ratings[c] = floor
    start = {c: ratings[c] for c in ids}

    played = matches[matches.status.isin(_DONE)].copy()
    played["home_goals"] = played.home_goals.astype(int)
    played["away_goals"] = played.away_goals.astype(int)
    games = pd.DataFrame({"game_id": played.fd_match_id,
                          "date": played.utc.dt.tz_localize(None),
                          "competition_id": league, "home_club_id": played.home,
                          "away_club_id": played.away, "home_goals": played.home_goals,
                          "away_goals": played.away_goals})
    res = run_elo(games, params, start=start)
    now = res.ratings
    hist = pd.concat([history[history.club_id.isin(ids)], res.history]).sort_values("date")

    table = league_table(ids, played).set_index("club_id")
    remaining = matches[~matches.status.isin(_DONE | _DEAD)].reset_index(drop=True)
    d_rem = np.array([now[h] - now[a] for h, a in zip(remaining.home, remaining.away)], float)
    mats = model.score_matrices(d_rem) if len(remaining) else np.zeros((0, 11, 11))
    sim = simulate_season(ids, played, remaining, mats, n_sims=n_sims).set_index("club_id")

    name = dict(zip(teams.club_id, teams.short))
    crest = dict(zip(teams.club_id, teams.crest))
    month_ago = (today - pd.Timedelta(days=30)).tz_localize(None)
    clubs = []
    for c in ids:
        t, s = table.loc[c], sim.loc[c]
        clubs.append({
            "id": c, "name": name[c], "crest": crest[c], "league": league,
            "elo": round(now[c], 1),
            "elo_change_30d": round(now[c] - _rating_at(hist, c, month_ago, start[c]), 1),
            "form": _form(c, played),
            "table": {k: int(t[k]) for k in _TABLE_KEYS},
            "proj": {"exp_points": round(float(s.exp_points), 1),
                     "exp_pos": round(float(s.exp_pos), 2),
                     "p_title": float(s.p_title), "p_top4": float(s.p_top4),
                     "p_releg": float(s.p_releg)},
        })

    fixtures = []
    pre = res.pre.set_index("game_id")
    recent = played[played.utc >= today - pd.Timedelta(days=7)]
    for r in recent.itertuples(index=False):
        d = pre.loc[r.fd_match_id, "elo_home"] - pre.loc[r.fd_match_id, "elo_away"]
        fixtures.append(_fixture(r, league, model, d, [int(r.home_goals), int(r.away_goals)]))
    soon = remaining[(remaining.utc >= today) & (remaining.utc <= today + pd.Timedelta(days=14))]
    for r in soon.itertuples(index=False):
        fixtures.append(_fixture(r, league, model, now[r.home] - now[r.away], None))
    fixtures.sort(key=lambda f: f["kickoff"])
    return clubs, fixtures


def _fixture(r, league, model, d, score):
    p = model.outcome_probs(np.array([d]))[0]
    lh, la = model.rates(np.array([d]))
    return {"id": int(r.fd_match_id), "league": league, "kickoff": _iso(r.utc),
            "home": int(r.home), "away": int(r.away), "status": r.status, "score": score,
            "p": [float(x) for x in p], "xg": [round(float(lh[0]), 2), round(float(la[0]), 2)]}


def build_current_season(fd, tm_clubs, elo_res: EloResult, params, model, season, overrides,
                         today: pd.Timestamp, n_sims: int = 10000):
    clubs, fixtures = [], []
    for league, (code, _) in LEAGUES.items():
        teams = fd.season_teams(code, season)
        matches = fd.season_matches(code, season)
        mapping = map_clubs(teams.assign(tm_league=league), tm_clubs, overrides)
        teams["club_id"] = [mapping.get(int(f), -int(f)) for f in teams.fd_id]
        idmap = dict(zip(teams.fd_id, teams.club_id))
        matches["home"] = matches.home_fd.map(idmap)
        matches["away"] = matches.away_fd.map(idmap)
        c, f = league_snapshot(league, teams, matches, elo_res.ratings, elo_res.history,
                               params, model, today, n_sims)
        clubs += c
        fixtures += f
    return clubs, fixtures


def offline_clubs(games, tm_clubs, elo_res: EloResult, season: int) -> list[dict]:
    clubs = []
    names = dict(zip(tm_clubs.club_id, tm_clubs.name))
    for league in LEAGUES:
        lg = games[(games.season == season) & (games.competition_id == league)]
        if lg.empty:
            continue
        played = lg.rename(columns={"home_club_id": "home", "away_club_id": "away",
                                    "date": "utc"})
        ids = sorted(set(played.home) | set(played.away))
        table = league_table(ids, played).set_index("club_id")
        for c in ids:
            t = table.loc[c]
            clubs.append({"id": int(c), "name": names.get(c, str(c)), "crest": None,
                          "league": league, "elo": round(elo_res.ratings.get(c, 1500.0), 1),
                          "elo_change_30d": 0.0, "form": _form(c, played),
                          "table": {k: int(t[k]) for k in _TABLE_KEYS}, "proj": None})
    return clubs
