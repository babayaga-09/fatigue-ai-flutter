import numpy as np
import pandas as pd

from touchline.models.form import (
    SEQ_FEATS,
    L,
    appearance_features,
    build_sequences,
    latest_windows,
    run_form,
)


def _feats(n_players=60, n_apps=60, seed=0):
    rng = np.random.default_rng(seed)
    rows = []
    for pid in range(n_players):
        skill = rng.uniform(0.0, 0.8)
        d = pd.Timestamp("2022-08-01")
        for i in range(n_apps):
            g = rng.poisson(skill * 0.6)
            a = rng.poisson(skill * 0.4)
            rows.append({"game_id": pid * 1000 + i, "player_id": pid, "club_id": 1, "date": d,
                         "competition_id": "GB1", "goals": g, "assists": a, "minutes": 90,
                         "yellow_cards": 0, "red_cards": 0, "season": 2022, "is_league": True,
                         "is_home": float(i % 2), "home_club_id": 1, "away_club_id": 2,
                         "opp_name": "X"})
            d += pd.Timedelta(days=21)
    eapps = pd.DataFrame(rows)
    pre = pd.DataFrame({"game_id": eapps.game_id, "elo_home": 1550.0, "elo_away": 1500.0})
    players = pd.DataFrame({"player_id": range(n_players), "position": "Attack",
                            "dob": pd.Timestamp("1998-01-01")})
    return appearance_features(eapps, pre), players


def test_build_sequences_shapes_and_targets():
    feats, players = _feats(n_players=2, n_apps=30)
    data = build_sequences(feats, players, pool_ids={0, 1}, stride=5)
    assert data.seq.shape[1:] == (L, len(SEQ_FEATS))
    first = feats[feats.player_id == data.player_id[0]]
    assert data.y[0] == first.ga.iloc[L:L + 5].sum()
    assert data.end_date[0] == first.date.iloc[L - 1]


def test_latest_windows_skips_short_histories():
    feats, players = _feats(n_players=2, n_apps=30)
    short = feats[(feats.player_id == 1)].head(4)
    feats2 = pd.concat([feats[feats.player_id == 0], short])
    w = latest_windows(feats2, players, ids=[0, 1])
    assert list(w.player_id) == [0]


def test_run_form_trains_and_reports_without_leakage():
    feats, players = _feats()
    data = build_sequences(feats, players, pool_ids=set(range(60)), stride=3)
    val_start, test_start = pd.Timestamp("2024-06-01"), pd.Timestamp("2025-01-01")
    model, m = run_form(data, val_start, test_start, epochs=3)
    train_end = data.end_date[data.end_date < np.datetime64(val_start)].max()
    assert pd.Timestamp(train_end) < val_start
    assert m["chosen"] in {"gru", "poisson_glm"} and m["n_test"] > 0
    assert m["poisson_deviance"] < m["baseline_poisson_deviance"] * 1.2
    preds = model.predict(data.subset(data.end_date >= np.datetime64(test_start)))
    assert (preds > 0).all()
