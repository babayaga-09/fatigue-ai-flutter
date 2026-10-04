"""M3 — Monte Carlo season projection over remaining fixtures."""
import numpy as np
import pandas as pd


def league_table(club_ids, played: pd.DataFrame) -> pd.DataFrame:
    stats = {c: {"played": 0, "won": 0, "drawn": 0, "lost": 0, "gf": 0, "ga": 0}
             for c in club_ids}
    for h, a, hg, ag in played[["home", "away", "home_goals", "away_goals"]].itertuples(
            index=False):
        hg, ag = int(hg), int(ag)
        for club, gf, ga in ((h, hg, ag), (a, ag, hg)):
            if club not in stats:
                continue
            s = stats[club]
            s["played"] += 1
            s["gf"] += gf
            s["ga"] += ga
            s["won" if gf > ga else "drawn" if gf == ga else "lost"] += 1
    t = pd.DataFrame.from_dict(stats, orient="index").rename_axis("club_id").reset_index()
    t["gd"] = t.gf - t.ga
    t["points"] = 3 * t.won + t.drawn
    t = t.sort_values(["points", "gd", "gf"], ascending=False, kind="stable")
    t["pos"] = np.arange(1, len(t) + 1)
    return t.reset_index(drop=True)


def simulate_season(club_ids, played, remaining, score_mats, n_sims=10000, seed=0,
                    top_n=4, releg_n=3) -> pd.DataFrame:
    rng = np.random.default_rng(seed)
    clubs = list(club_ids)
    idx = {c: i for i, c in enumerate(clubs)}
    base = league_table(clubs, played).set_index("club_id").loc[clubs]
    n = len(clubs)
    pts = np.tile(base.points.to_numpy(float), (n_sims, 1))
    gd = np.tile(base.gd.to_numpy(float), (n_sims, 1))
    gf = np.tile(base.gf.to_numpy(float), (n_sims, 1))
    g = score_mats.shape[1] if len(score_mats) else 11
    for i, (h, a) in enumerate(remaining[["home", "away"]].itertuples(index=False)):
        if h not in idx or a not in idx:
            continue
        cum = score_mats[i].ravel().cumsum()
        k = np.minimum(np.searchsorted(cum, rng.random(n_sims) * cum[-1]), g * g - 1)
        hg, ag = k // g, k % g
        hi, ai = idx[h], idx[a]
        pts[:, hi] += np.where(hg > ag, 3, np.where(hg == ag, 1, 0))
        pts[:, ai] += np.where(ag > hg, 3, np.where(hg == ag, 1, 0))
        gd[:, hi] += hg - ag
        gd[:, ai] += ag - hg
        gf[:, hi] += hg
        gf[:, ai] += ag
    key = pts * 1e6 + (gd + 500) * 1e3 + gf + rng.random((n_sims, n)) * 0.1
    order = np.argsort(-key, axis=1)
    pos = np.empty_like(order)
    pos[np.arange(n_sims)[:, None], order] = np.arange(1, n + 1)
    return pd.DataFrame({
        "club_id": clubs,
        "exp_points": pts.mean(0),
        "exp_pos": pos.mean(0),
        "p_title": (pos == 1).mean(0),
        "p_top4": (pos <= top_n).mean(0),
        "p_releg": (pos > n - releg_n).mean(0),
    })
