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
        "home_manager": ["A", "B", "C"], "away_manager": ["B", "A", "B"],
        "elo_home": [1500.0] * 3, "elo_away": [1500.0] * 3})
    r = club_game_results(lg, _Flat())
    assert len(r) == 6
    c1 = r[r.club_id == 1].sort_values("date")
    assert list(c1.points) == [3, 1, 0]
    assert abs(c1.iloc[0].pae - (3 - (3 * 0.45 + 0.27))) < 1e-9
    assert c1.stint.nunique() == 2  # A, A, then C


class _Linear:
    """P(home win) rises with the rating gap, so frozen vs live ratings are visible."""
    def outcome_probs(self, d):
        ph = np.clip(0.45 + np.asarray(d) / 1000, 0.05, 0.9)
        return np.stack([ph, np.full_like(ph, 0.05), 0.95 - ph], axis=1)


def test_own_rating_is_frozen_within_a_stint_and_season():
    lg = pd.DataFrame({
        "game_id": [1, 2, 3, 4],
        "date": pd.to_datetime(["2024-08-01", "2024-08-08", "2024-08-15", "2025-08-15"]),
        "season": [2024, 2024, 2024, 2025], "competition_id": ["GB1"] * 4,
        "home_club_id": [1, 1, 1, 1], "away_club_id": [2, 3, 4, 5],
        "home_goals": [3, 3, 3, 3], "away_goals": [0, 0, 0, 0],
        "home_manager": ["A"] * 4, "away_manager": ["X", "Y", "Z", "W"],
        "elo_home": [1500.0, 1600.0, 1700.0, 1800.0], "elo_away": [1500.0] * 4})
    c1 = club_game_results(lg, _Linear()).query("club_id == 1").sort_values("date")
    # the club's own winning run does not raise what it is expected to take this season
    assert c1.xpts.iloc[0] == c1.xpts.iloc[1] == c1.xpts.iloc[2]
    # a new season re-reads the rating
    assert c1.xpts.iloc[3] > c1.xpts.iloc[0]


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


def test_table_skips_trailing_games_with_no_manager_name():
    res = _res()
    last = res[res.season == 2016].sort_values("date").iloc[-1]
    gap = pd.DataFrame([{**last.to_dict(), "game_id": 10 ** 7, "manager": None,
                         "date": res.date.max() + pd.Timedelta(days=1),
                         "stint": res.stint.max() + 1}])
    t = manager_table(pd.concat([res, gap], ignore_index=True), 2016, 5.0)
    assert t.name.notna().all()
    assert int(last.club_id) in set(t.club)


def test_reliability_detects_persistent_effects_and_bounce_reports():
    res = _res()
    r = reliability(res, min_games=40)
    assert r["n_stints"] >= 5
    assert r["split_half_r"] > 0  # planted skill shows up in both halves
    assert r["reliability"] > r["split_half_r"]


def _stint(club, name, paes, start_gid):
    day = pd.Timestamp("2020-08-01")
    return [{"game_id": start_gid + i, "date": day + pd.Timedelta(days=7 * (start_gid + i)),
             "season": 2020, "league": "GB1", "club_id": club, "opp_id": 0, "manager": name,
             "points": 0, "xpts": 0.0, "pae": v} for i, v in enumerate(paes)]


def test_bounce_counts_short_spells_and_compares_with_clubs_that_kept_the_manager():
    rows = (_stint(1, "A", [0.0] * 30 + [-1.0] * 10, 0)
            + _stint(1, "B", [0.0] * 15, 40)
            + _stint(2, "C", [0.0] * 20 + [-1.0] * 10 + [0.0] * 30, 100))
    res = pd.DataFrame(rows).sort_values(["club_id", "date"]).reset_index(drop=True)
    res["stint"] = (res.manager != res.groupby("club_id").manager.shift()).cumsum()
    b = bounce(res)
    assert b["n_changes"] == 1  # B lasted 15 games: counted for first10
    assert b["last10_before"] == -1.0 and b["first10"] == 0.0
    assert b["next20"] is None and b["n_next20"] == 0
    assert b["control_next10"] == 0.0 and b["n_controls"] >= 1
    assert b["gap"] == 0.0 and b["gap_ci"] is None  # one case: too few for an interval
