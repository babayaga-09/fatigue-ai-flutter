import numpy as np
import pandas as pd

from touchline.models.prospects import FEEDERS, build_rows, conversion, run_prospects


def _stats(rng, n_players=1500):
    seasons = np.arange(2014, 2026)
    rows, top = [], []
    for pid in range(n_players):
        lg = rng.choice(list(FEEDERS))
        skill = rng.normal()
        for s in seasons:
            share = float(np.clip(0.5 + 0.2 * skill + rng.normal(0, 0.1), 0.15, 1))
            ga90 = max(0.0, 0.3 + 0.15 * skill + rng.normal(0, 0.05))
            rows.append({"player_id": pid, "season": s, "league": lg, "club_id": 100 + pid % 50,
                         "minutes": share * 34 * 90, "apps": 30, "goals": 5, "assists": 3,
                         "team_games": 34, "ga90": ga90, "g90": ga90 / 2, "a90": ga90 / 2,
                         "minutes_share": share})
            if rng.random() < 0.08:  # moves up next season
                top.append({"player_id": pid, "season": s + 1, "league": "GB1", "club_id": 1,
                            "minutes": 1000, "apps": 20, "goals": 2, "assists": 2,
                            "team_games": 38, "ga90": ga90 * 0.6, "g90": 0.1, "a90": 0.1,
                            "minutes_share": float(np.clip(0.3 + 0.25 * skill
                                                           + rng.normal(0, 0.1), 0, 1))})
    return pd.DataFrame(rows), pd.DataFrame(top)


def _rows(seed=0):
    rng = np.random.default_rng(seed)
    feeder, top5 = _stats(rng)
    players = pd.DataFrame({"player_id": feeder.player_id.unique(),
                            "dob": pd.Timestamp("1998-01-01"), "position": "Attack"})
    vals = feeder[["player_id", "season"]].assign(
        date=lambda d: pd.to_datetime((d.season + 1).astype(str) + "-05-01"),
        value=lambda d: 1e6 * (1 + d.player_id % 7))[["player_id", "date", "value"]]
    hist = pd.DataFrame({"date": pd.to_datetime(["2010-01-01"]), "club_id": [100],
                         "rating": [1500.0]})
    return build_rows(feeder, top5, players, vals, hist)


def test_build_rows_labels_movers_and_uses_pre_move_value():
    rows = _rows()
    assert rows.moved.any() and not rows.moved.all()
    assert set(rows.loc[rows.moved, "regular"].unique()) <= {0, 1}
    assert rows.mv.notna().any()


def test_run_prospects_rolling_folds_and_ci():
    rows = _rows()
    model, m = run_prospects(rows, test_season=2025)
    assert m["test_moves_seasons"] == [2020, 2021, 2022, 2023, 2024]
    assert m["n_test"] == sum(m["n_test_by_season"].values())
    assert m["auc"] > m["baseline_auc"]
    lo, hi = m["auc_gain_ci"]
    assert lo <= m["auc"] - m["baseline_auc"] <= hi
    assert m["chosen"] == "model"
    cur = rows[rows.season == 2025].head(5)
    p = model.predict(cur)
    assert ((p >= 0) & (p <= 1)).all()
    assert len(model.explain(cur)[0]) == 3


def test_conversion_factor_per_feeder_league():
    f = conversion(_rows())
    assert set(f) == set(FEEDERS) and all(0 < v < 2 for v in f.values())


def test_falls_back_to_price_when_model_does_not_beat_it():
    rows = _rows()
    # make outcome depend on value only, so the tree model has nothing to add
    rows["log_value"] = np.log(1e6 * (1 + rows.player_id % 7))
    rows["regular"] = (rows.player_id % 7 >= 4).astype(int)  # price alone is perfect
    model, m = run_prospects(rows, test_season=2025)
    assert m["chosen"] == "value_only" and m["auc"] <= m["baseline_auc"]
    assert model.explain(rows.head(2)) == [[], []]
    p = model.predict(rows.head(5))
    assert ((p >= 0) & (p <= 1)).all()


def test_moves_come_from_transfers_and_value_is_read_before_the_move():
    feeder = pd.DataFrame([{"player_id": 1, "season": 2022, "league": "NL1", "club_id": 100,
                            "minutes": 2500, "apps": 30, "goals": 5, "assists": 3,
                            "team_games": 34, "ga90": 0.3, "g90": 0.2, "a90": 0.1,
                            "minutes_share": 0.8}])
    top5 = pd.DataFrame(columns=["player_id", "season", "minutes_share", "ga90"])
    players = pd.DataFrame({"player_id": [1], "dob": [pd.Timestamp("2000-01-01")],
                            "position": ["Attack"]})
    vals = pd.DataFrame({"player_id": [1, 1],
                         "date": pd.to_datetime(["2023-01-10", "2023-03-01"]),
                         "value": [5e6, 20e6]})  # second valuation is after the move
    hist = pd.DataFrame({"date": pd.to_datetime(["2010-01-01"]), "club_id": [100],
                         "rating": [1500.0]})
    transfers = pd.DataFrame({"player_id": [1], "date": pd.to_datetime(["2023-01-31"]),
                              "to_club_id": [7]})
    top5_clubs = pd.DataFrame({"season": [2023], "club_id": [7]})
    r = build_rows(feeder, top5, players, vals, hist, transfers, top5_clubs).iloc[0]
    assert bool(r.moved) and r.regular == 0  # moved up, never played: not a regular
    assert r.mv == 5e6  # the valuation before the transfer, not after
