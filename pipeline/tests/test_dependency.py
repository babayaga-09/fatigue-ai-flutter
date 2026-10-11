import numpy as np
import pandas as pd

from touchline.models.dependency import dependency, split_half_stability


def _data():
    days = pd.date_range("2024-08-01", periods=20, freq="7D")
    res = pd.DataFrame({"game_id": range(1, 21), "club_id": 1, "season": 2024, "date": days,
                        "pae": [0.5] * 15 + [-0.5] * 5})
    apps = []
    for gid in range(1, 16):
        apps.append({"player_id": 10, "game_id": gid, "club_id": 1, "season": 2024,
                     "minutes": 90})
    for gid in range(1, 20):
        apps.append({"player_id": 11, "game_id": gid, "club_id": 1, "season": 2024,
                     "minutes": 90})
    return pd.DataFrame(apps), res


def test_key_player_scores_high_and_rarely_missing_player_is_excluded():
    apps, res = _data()
    d = dependency(apps, res, {10: 1, 11: 1}, 2024).set_index("player_id")
    assert 10 in d.index and 11 not in d.index  # 11 missed only one game
    assert d.loc[10, "played"] == 15 and d.loc[10, "missed"] == 5
    assert np.isclose(d.loc[10, "index"], 1.0 * 5 / (5 + 5.0))


def test_split_half_stability_returns_shape():
    apps, res = _data()
    out = split_half_stability(apps, res, {10: 1, 11: 1}, 2024)
    assert set(out) == {"n", "r"}
