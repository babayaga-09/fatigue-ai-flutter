"""M1 — club Elo ratings with home advantage and margin-of-victory scaling."""
from dataclasses import dataclass
from itertools import product

import numpy as np
import pandas as pd

from touchline.config import LEAGUES


@dataclass(frozen=True)
class EloParams:
    k: float = 20.0
    home_adv: float = 65.0
    init: float = 1500.0


@dataclass
class EloResult:
    ratings: dict[int, float]
    pre: pd.DataFrame
    history: pd.DataFrame


def expected_home(r_home, r_away, home_adv):
    return 1.0 / (1.0 + 10 ** ((r_away - (r_home + home_adv)) / 400.0))


def _mov(goal_diff: int, winner_edge: float) -> float:
    if goal_diff == 0:
        return 1.0
    return float(np.log(abs(goal_diff) + 1) * (2.2 / (winner_edge * 0.001 + 2.2)))


def run_elo(games: pd.DataFrame, params: EloParams = EloParams(),
            start: dict[int, float] | None = None) -> EloResult:
    """Process games in date order. Clubs first seen in a top-5 league start at the 15th
    percentile of that league's recently active ratings (promoted sides are weak)."""
    g = games.sort_values(["date", "game_id"])
    ratings: dict[int, float] = dict(start or {})
    league_seen: dict[str, dict[int, pd.Timestamp]] = {}
    pre_h, pre_a, hist = [], [], []
    cols = ["game_id", "date", "competition_id", "home_club_id", "away_club_id",
            "home_goals", "away_goals"]
    for _, date, comp, h, a, hg, ag in g[cols].itertuples(index=False):
        h, a = int(h), int(a)
        for club in (h, a):
            if club not in ratings:
                ratings[club] = _start_rating(comp, date, league_seen, ratings, params)
        if comp in LEAGUES:
            seen = league_seen.setdefault(comp, {})
            seen[h] = date
            seen[a] = date
        rh, ra = ratings[h], ratings[a]
        pre_h.append(rh)
        pre_a.append(ra)
        gd = int(hg) - int(ag)
        score = 1.0 if gd > 0 else 0.5 if gd == 0 else 0.0
        e = expected_home(rh, ra, params.home_adv)
        edge = (rh + params.home_adv - ra) if gd > 0 else (ra - rh - params.home_adv)
        delta = params.k * _mov(gd, edge) * (score - e)
        ratings[h] = rh + delta
        ratings[a] = ra - delta
        hist.append((date, h, ratings[h]))
        hist.append((date, a, ratings[a]))
    pre = pd.DataFrame({"game_id": g["game_id"].to_numpy(), "elo_home": pre_h,
                        "elo_away": pre_a})
    history = pd.DataFrame(hist, columns=["date", "club_id", "rating"])
    return EloResult(ratings=ratings, pre=pre, history=history)


def _start_rating(comp, date, league_seen, ratings, params) -> float:
    if comp not in LEAGUES or comp not in league_seen:
        return params.init
    recent = [ratings[c] for c, d in league_seen[comp].items()
              if c in ratings and (date - d).days <= 365]
    return float(np.percentile(recent, 15)) if len(recent) >= 5 else params.init


def tune_elo(games: pd.DataFrame, val_mask: pd.Series) -> tuple[EloParams, list[dict]]:
    """Grid-search k / home advantage by Brier score of the expected result on val games."""
    val_ids = set(games.loc[val_mask, "game_id"])
    grid = []
    for k, hadv in product([15, 20, 25, 30], [45, 65, 85]):
        p = EloParams(k=k, home_adv=hadv)
        res = run_elo(games, p)
        v = games[games.game_id.isin(val_ids)].merge(res.pre, on="game_id")
        e = expected_home(v.elo_home.to_numpy(), v.elo_away.to_numpy(), hadv)
        s = np.sign(v.home_goals - v.away_goals).to_numpy() * 0.5 + 0.5
        grid.append({"k": k, "home_adv": hadv, "brier": float(np.mean((e - s) ** 2))})
    best = min(grid, key=lambda r: r["brier"])
    return EloParams(k=best["k"], home_adv=best["home_adv"]), grid


def evaluate_favourites(games, pre, season: int, home_adv: float) -> dict:
    lg = games[(games.season == season) & games.competition_id.isin(list(LEAGUES))]
    dec = lg[lg.home_goals != lg.away_goals].merge(pre, on="game_id")
    home_won = (dec.home_goals > dec.away_goals).to_numpy()
    pick_home = (dec.elo_home + home_adv >= dec.elo_away).to_numpy()
    return {"test_season": season, "n": len(dec),
            "favourite_accuracy": float((pick_home == home_won).mean()) if len(dec) else 0.0,
            "baseline_home_pick_accuracy": float(home_won.mean()) if len(dec) else 0.0}
