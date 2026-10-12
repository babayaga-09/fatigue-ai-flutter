"""F2 — manager effect: points above what the squad's strength predicted, shrunk for luck.

Strength must not learn from the manager's own results, or his effect leaks into the
expectation he is judged against (and odd/even game halves anti-correlate by construction).
So each club's rating is frozen at the start of the current stretch: the later of the
manager's first game and the season's first game. The opponent's rating stays live."""
import numpy as np
import pandas as pd


def club_game_results(lg: pd.DataFrame, model) -> pd.DataFrame:
    hg, ag = lg.home_goals.to_numpy(), lg.away_goals.to_numpy()
    hp = np.where(hg > ag, 3, np.where(hg == ag, 1, 0))
    ap = np.where(ag > hg, 3, np.where(hg == ag, 1, 0))
    base = {"game_id": lg.game_id.to_numpy(), "date": lg.date.to_numpy(),
            "season": lg.season.to_numpy(), "league": lg.competition_id.to_numpy()}
    home = pd.DataFrame({**base, "club_id": lg.home_club_id.to_numpy(),
                         "opp_id": lg.away_club_id.to_numpy(), "is_home": True,
                         "manager": lg.home_manager.to_numpy(), "points": hp,
                         "own_elo": lg.elo_home.to_numpy(), "opp_elo": lg.elo_away.to_numpy()})
    away = pd.DataFrame({**base, "club_id": lg.away_club_id.to_numpy(),
                         "opp_id": lg.home_club_id.to_numpy(), "is_home": False,
                         "manager": lg.away_manager.to_numpy(), "points": ap,
                         "own_elo": lg.elo_away.to_numpy(), "opp_elo": lg.elo_home.to_numpy()})
    out = pd.concat([home, away], ignore_index=True)
    out = out.sort_values(["club_id", "date", "game_id"]).reset_index(drop=True)
    # A new stint starts at each club's first game and whenever the manager changes.
    out["stint"] = (out.manager != out.groupby("club_id").manager.shift()).cumsum()
    frozen = out.groupby(["stint", "season"]).own_elo.transform("first")
    d = np.where(out.is_home, frozen - out.opp_elo, out.opp_elo - frozen)
    p = model.outcome_probs(d)
    out["xpts"] = np.where(out.is_home, 3 * p[:, 0] + p[:, 1], 3 * p[:, 2] + p[:, 1])
    out["pae"] = out.points - out.xpts
    return out.drop(columns=["own_elo", "opp_elo", "is_home"])


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
    """Split-half check: do a manager's odd and even games agree? Near zero means noise.
    The Spearman-Brown full-length reliability is only defined for a positive r."""
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
            "reliability": 2 * r / (1 + r) if r > 0 else None}


def _windows(res: pd.DataFrame, n: int = 10) -> pd.DataFrame:
    """Every point in a stint with n games behind it and n more ahead in the same stint and
    season: the mean PAE of the n before and the n after."""
    out = []
    for _, g in res.sort_values(["date", "game_id"]).groupby(["stint", "season"]):
        v = g.pae.to_numpy()
        if len(v) < 2 * n:
            continue
        c = np.concatenate([[0.0], np.cumsum(v)])
        i = np.arange(n, len(v) - n + 1)
        out.append(pd.DataFrame({"before": (c[i] - c[i - n]) / n,
                                 "after": (c[i + n] - c[i]) / n}))
    return pd.concat(out, ignore_index=True) if out else pd.DataFrame(columns=["before", "after"])


def bounce(res: pd.DataFrame, band: float = 0.05) -> dict:
    """Mid-season changes: the old manager's last 10, the new one's first 10 (every change
    with 10+ games) and games 11-30 (only those who lasted 30). The control is what clubs on an
    equally bad 10-game run did over their next 10 when they kept the manager."""
    cases = []
    for _, g in res.sort_values("date").groupby("club_id"):
        stints = [s for _, s in g.groupby("stint", sort=False)]
        for prev, cur in zip(stints, stints[1:], strict=False):
            if len(prev) < 10 or len(cur) < 10:
                continue
            if cur.season.iloc[0] != prev.season.iloc[-1]:
                continue
            cases.append((prev.pae.tail(10).mean(), cur.pae.head(10).mean(),
                          cur.pae.iloc[10:30].mean() if len(cur) >= 30 else np.nan))
    empty = {"n_changes": 0, "last10_before": None, "first10": None, "next20": None,
             "n_next20": 0, "control_next10": None, "n_controls": 0, "gap": None,
             "gap_ci": None}
    if not cases:
        return empty
    a = np.array(cases)
    w = _windows(res)
    gaps, matched, n_ctrl = [], [], 0
    for before, first10 in a[:, :2]:
        m = w.after[(w.before - before).abs() <= band]
        if len(m):
            matched.append(float(m.mean()))
            gaps.append(first10 - float(m.mean()))
            n_ctrl += len(m)
    nxt = a[~np.isnan(a[:, 2]), 2]
    ci = None
    if len(gaps) >= 10:
        g = np.array(gaps)
        rng = np.random.default_rng(0)
        boots = [g[rng.integers(0, len(g), len(g))].mean() for _ in range(2000)]
        ci = [float(np.percentile(boots, 2.5)), float(np.percentile(boots, 97.5))]
    return {"n_changes": len(a), "last10_before": float(a[:, 0].mean()),
            "first10": float(a[:, 1].mean()),
            "next20": float(nxt.mean()) if len(nxt) else None, "n_next20": int(len(nxt)),
            "control_next10": float(np.mean(matched)) if matched else None,
            "n_controls": int(n_ctrl),
            "gap": float(np.mean(gaps)) if gaps else None, "gap_ci": ci}
