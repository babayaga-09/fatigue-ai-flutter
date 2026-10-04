"""M7 — "plays like X": k-NN over standardised per-90 profiles within a position group."""
import numpy as np
import pandas as pd
from sklearn.neighbors import NearestNeighbors

PROFILE = {"g90": 1.0, "a90": 1.0, "minutes_share": 0.7, "yellow90": 0.3, "age": 0.5,
           "club_elo": 0.5}
ROLE_WEIGHT = 1.5


def similar_players(df: pd.DataFrame, k: int = 8) -> dict[int, list[int]]:
    out: dict[int, list[int]] = {}
    for _, g in df.groupby("position"):
        ids = g.player_id.to_numpy()
        if len(g) == 1:
            out[int(ids[0])] = []
            continue
        x = g[list(PROFILE)].astype(float)
        x = (x - x.mean()) / x.std(ddof=0).replace(0, 1)
        x = x.fillna(0) * pd.Series(PROFILE)
        roles = pd.get_dummies(g.sub_position.fillna("?")).astype(float) * ROLE_WEIGHT
        mat = np.hstack([x.to_numpy(), roles.to_numpy()])
        nn = NearestNeighbors(n_neighbors=min(k + 1, len(g))).fit(mat)
        _, idx = nn.kneighbors(mat)
        for row, neigh in enumerate(idx):
            out[int(ids[row])] = [int(ids[j]) for j in neigh if j != row][:k]
    return out
