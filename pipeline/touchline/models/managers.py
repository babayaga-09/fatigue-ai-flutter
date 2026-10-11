"""F2 — manager effect: points above what the squad's strength predicted, shrunk for luck."""
import numpy as np
import pandas as pd


def club_game_results(lg: pd.DataFrame, model) -> pd.DataFrame:
    p = model.outcome_probs(lg.d.to_numpy())
    hg, ag = lg.home_goals.to_numpy(), lg.away_goals.to_numpy()
    hp = np.where(hg > ag, 3, np.where(hg == ag, 1, 0))
    ap = np.where(ag > hg, 3, np.where(hg == ag, 1, 0))
    base = {"game_id": lg.game_id.to_numpy(), "date": lg.date.to_numpy(),
            "season": lg.season.to_numpy(), "league": lg.competition_id.to_numpy()}
    home = pd.DataFrame({**base, "club_id": lg.home_club_id.to_numpy(),
                         "opp_id": lg.away_club_id.to_numpy(),
                         "manager": lg.home_manager.to_numpy(), "points": hp,
                         "xpts": 3 * p[:, 0] + p[:, 1]})
    away = pd.DataFrame({**base, "club_id": lg.away_club_id.to_numpy(),
                         "opp_id": lg.home_club_id.to_numpy(),
                         "manager": lg.away_manager.to_numpy(), "points": ap,
                         "xpts": 3 * p[:, 2] + p[:, 1]})
    out = pd.concat([home, away], ignore_index=True)
    out["pae"] = out.points - out.xpts
    out = out.sort_values(["club_id", "date", "game_id"]).reset_index(drop=True)
    # A new stint starts at each club's first game and whenever the manager changes.
    out["stint"] = (out.manager != out.groupby("club_id").manager.shift()).cumsum()
    return out


def shrink_k(res: pd.DataFrame, min_games: int = 10) -> float:
    """Empirical-Bayes prior strength: within-game noise over between-manager variance."""
    g = res.groupby("stint").pae.agg(["mean", "var", "count"])
    g = g[g["count"] >= min_games]
    within = float(g["var"].mean())
    between = float(g["mean"].var() - (g["var"] / g["count"]).mean())
    return within / between if between > 1e-9 else 1e6


def manager_table(res: pd.DataFrame, season: int, k: float) -> pd.DataFrame:
    named = res[(res.season == season) & res.manager.notna()]
    cur = named.sort_values("date").groupby("club_id").tail(1)
    rows = []
    for club, stint, name, league in cur[["club_id", "stint", "manager", "league"]].itertuples(
            index=False):
        g = res[res.stint == stint].sort_values("date")
        n, mean = len(g), float(g.pae.mean())
        shrunk = mean * n / (n + k)
        rows.append({"name": name, "club": int(club), "league": league, "games": n,
                     "since": g.date.iloc[0], "pae_raw": mean, "pae": shrunk,
                     "per38": shrunk * 38,
                     "first10": float(g.pae.head(10).mean()) if n >= 10 else None})
    return pd.DataFrame(rows)


def reliability(res: pd.DataFrame, min_games: int = 40) -> dict:
    """Split-half check: do a manager's odd and even games agree? Near zero means noise."""
    halves = []
    for _, g in res.groupby("stint"):
        if len(g) < min_games:
            continue
        v = g.sort_values("date").pae.to_numpy()
        halves.append((v[0::2].mean(), v[1::2].mean()))
    if len(halves) < 5:
        return {"n_stints": len(halves), "split_half_r": None, "reliability": None}
    a = np.array(halves)
    r = float(np.corrcoef(a[:, 0], a[:, 1])[0, 1])
    return {"n_stints": len(halves), "split_half_r": r,
            "reliability": 2 * r / (1 + r) if r > -1 else None}


def bounce(res: pd.DataFrame) -> dict:
    """Mid-season changes: the old manager's last 10, the new one's first 10 and next 20."""
    out = []
    for _, g in res.sort_values("date").groupby("club_id"):
        stints = [s for _, s in g.groupby("stint", sort=False)]
        for prev, cur in zip(stints, stints[1:], strict=False):
            if len(prev) < 10 or len(cur) < 30:
                continue
            if cur.season.iloc[0] != prev.season.iloc[-1]:
                continue
            out.append((prev.pae.tail(10).mean(), cur.pae.head(10).mean(),
                        cur.pae.iloc[10:30].mean()))
    if not out:
        return {"n_changes": 0, "last10_before": None, "first10": None, "next20": None}
    a = np.array(out)
    return {"n_changes": len(out), "last10_before": float(a[:, 0].mean()),
            "first10": float(a[:, 1].mean()), "next20": float(a[:, 2].mean())}
