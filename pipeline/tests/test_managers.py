import numpy as np
import pandas as pd

from touchline.models.managers import (
    bounce,
    club_game_results,
    manager_table,
    reliability,
    shrink_k,
)


class _Flat:
    def outcome_probs(self, d):
        return np.tile([0.45, 0.27, 0.28], (len(d), 1))


def test_club_game_results_two_rows_per_game_and_stints():
    lg = pd.DataFrame({
        "game_id": [1, 2, 3], "date": pd.to_datetime(["2024-08-01", "2024-08-08", "2024-08-15"]),
        "season": [2024] * 3, "competition_id": ["GB1"] * 3,
        "home_club_id": [1, 2, 1], "away_club_id": [2, 1, 2],
        "home_goals": [2, 0, 1], "away_goals": [0, 0, 3],
        "home_manager": ["A", "B", "C"], "away_manager": ["B", "A", "B"], "d": [0.0] * 3})
    r = club_game_results(lg, _Flat())
    assert len(r) == 6
    c1 = r[r.club_id == 1].sort_values("date")
    assert list(c1.points) == [3, 1, 0]
    assert abs(c1.iloc[0].pae - (3 - (3 * 0.45 + 0.27))) < 1e-9
    assert c1.stint.nunique() == 2  # A, A, then C


def _res(seed=0):
    rng = np.random.default_rng(seed)
    rows, gid = [], 0
    day = pd.Timestamp("2014-08-01")
    for club in range(1, 21):
        managers = [(f"M{club}a", 0.4 if club <= 5 else 0.0, 80), (f"M{club}b", 0.0, 60)]
        for name, skill, n in managers:
            for i in range(n):
                gid += 1
                rows.append({"game_id": gid, "date": day + pd.Timedelta(days=gid),
                             "season": 2014 + i // 38 + (0 if name.endswith("a") else 2),
                             "league": "GB1", "club_id": club, "opp_id": 0, "manager": name,
                             "points": 0, "xpts": 0.0, "pae": skill + rng.normal(0, 1.2)})
    res = pd.DataFrame(rows).sort_values(["club_id", "date"]).reset_index(drop=True)
    res["stint"] = (res.manager != res.groupby("club_id").manager.shift()).cumsum()
    return res


def test_shrinkage_tames_tiny_samples_and_table_ranks_current_managers():
    res = _res()
    tiny = pd.DataFrame([{**res.iloc[-1].to_dict(), "game_id": 10 ** 6 + i,
                          "date": res.date.max() + pd.Timedelta(days=i + 1), "season": 2016,
                          "manager": "Lucky", "pae": 3.0, "club_id": 99} for i in range(3)])
    tiny["stint"] = res.stint.max() + 1
    res = pd.concat([res, tiny], ignore_index=True)
    k = shrink_k(res)
    assert k > 3
    t = manager_table(res, 2016, k).set_index("name")
    assert t.loc["Lucky", "pae"] < 3.0 * 3 / (3 + 3)  # heavily shrunk
    assert "M1b" in t.index or "M1a" in t.index


def test_reliability_detects_persistent_effects_and_bounce_reports():
    res = _res()
    r = reliability(res, min_games=40)
    assert r["n_stints"] >= 5 and r["split_half_r"] is not None
    b = bounce(res)
    assert set(b) == {"n_changes", "last10_before", "first10", "next20"}
