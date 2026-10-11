"""F3 — can't-live-without index: results with vs without a player, opponent-adjusted.

Residual = actual - expected points from the match model, so a player missing only easy games
is not mistaken for a key man. Correlation, not causation."""
import numpy as np
import pandas as pd


def dependency(eapps: pd.DataFrame, res: pd.DataFrame, club_of: dict, season: int,
               min_played: int = 5, min_missed: int = 3, k: float = 5.0) -> pd.DataFrame:
    s_res = res[res.season == season]
    by_club = {c: (g.game_id.to_numpy(), g.pae.to_numpy()) for c, g in s_res.groupby("club_id")}
    played = eapps[(eapps.season == season) & (eapps.minutes >= 45)]
    played_by = played.groupby("player_id").game_id.apply(set).to_dict()
    rows = []
    for pid, club in club_of.items():
        if club not in by_club:
            continue
        gids, pae = by_club[club]
        mask = np.isin(gids, list(played_by.get(pid, set())))
        n_p, n_m = int(mask.sum()), int((~mask).sum())
        if n_p < min_played or n_m < min_missed:
            continue
        diff = float(pae[mask].mean() - pae[~mask].mean())
        rows.append({"player_id": pid, "index": diff * n_m / (n_m + k), "played": n_p,
                     "missed": n_m})
    return pd.DataFrame(rows, columns=["player_id", "index", "played", "missed"])


def split_half_stability(eapps, res, club_of, season) -> dict:
    """Index from the first half of the season vs the second half, across players."""
    s = res[res.season == season]
    cut = s.date.median()
    a = dependency(eapps, s[s.date <= cut], club_of, season, min_played=3, min_missed=2)
    b = dependency(eapps, s[s.date > cut], club_of, season, min_played=3, min_missed=2)
    m = a.merge(b, on="player_id", suffixes=("_a", "_b"))
    r = float(np.corrcoef(m.index_a, m.index_b)[0, 1]) if len(m) >= 10 else None
    return {"n": int(len(m)), "r": r}
