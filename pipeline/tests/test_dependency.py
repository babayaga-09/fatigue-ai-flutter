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


def test_games_before_he_joined_and_cameos_are_not_missed_games():
    apps, res = _data()
    # player 12 joined in game 6; plays 90 in 6-15, a 20-minute cameo in 16, absent 17-20
    extra = [{"player_id": 12, "game_id": g, "club_id": 1, "season": 2024,
              "minutes": 90 if g <= 15 else 20} for g in range(6, 17)]
    apps = pd.concat([apps, pd.DataFrame(extra)], ignore_index=True)
    d = dependency(apps, res, {12: 1}, 2024).set_index("player_id")
    assert d.loc[12, "played"] == 10 and d.loc[12, "missed"] == 4


def test_split_half_stability_tracks_a_consistent_effect():
    rng = np.random.default_rng(0)
    days = pd.date_range("2024-08-01", periods=38, freq="7D")
    res_rows, apps = [], []
    for club in range(1, 21):
        skill = rng.normal(0, 1.0)
        absent = set(rng.choice(np.arange(1, 39), 10, replace=False).tolist())
        for g in range(1, 39):
            gid = club * 100 + g
            plays = g not in absent
            res_rows.append({"game_id": gid, "club_id": club, "season": 2024,
                             "date": days[g - 1],
                             "pae": (skill if plays else -skill) + rng.normal(0, 0.3)})
            if plays:
                apps.append({"player_id": club, "game_id": gid, "club_id": club,
                             "season": 2024, "minutes": 90})
    out = split_half_stability(pd.DataFrame(apps), pd.DataFrame(res_rows),
                               {c: c for c in range(1, 21)}, 2024)
    assert out["n"] == 20 and out["r"] > 0.8
