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


def test_run_prospects_beats_value_only_baseline_without_leakage():
    rows = _rows()
    model, m = run_prospects(rows, test_season=2025)
    assert m["test_moves_season"] == 2024
    assert m["auc"] > m["baseline_auc"]
    cur = rows[rows.season == 2025].head(5)
    p = model.predict(cur)
    assert ((p >= 0) & (p <= 1)).all()
    assert len(model.explain(cur)[0]) == 3


def test_conversion_factor_per_feeder_league():
    f = conversion(_rows())
    assert set(f) == set(FEEDERS) and all(0 < v < 2 for v in f.values())
