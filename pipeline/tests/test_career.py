import numpy as np
import pandas as pd

from touchline.models.career import H, build, run_career, yearly_panel


def _panel(n=900, seed=0):
    rng = np.random.default_rng(seed)
    vals, players = [], []
    for pid in range(n):
        born = 1985 + int(rng.integers(0, 15))
        players.append({"player_id": pid, "dob": pd.Timestamp(born, 1, 1),
                        "position": rng.choice(["Attack", "Midfield", "Defender"])})
        lv = 14 + rng.normal(0, 1)
        for season in range(2010, 2026):
            age = season + 1 - born
            lv += (0.35 if age < 24 else 0.05 if age < 28 else -0.25) + rng.normal(0, 0.15)
            vals.append({"player_id": pid, "date": pd.Timestamp(season + 1, 5, 1),
                         "value": float(np.exp(lv))})
    stats = pd.DataFrame(columns=["player_id", "season", "minutes", "ga90"])
    return yearly_panel(pd.DataFrame(vals), pd.DataFrame(players), stats)


def test_panel_one_value_per_season_and_build_targets():
    panel = _panel(50)
    assert not panel.duplicated(["player_id", "season"]).any()
    d = build(panel, [2018])
    assert d.x.shape[1:] == (6, d.x.shape[2]) and d.y.shape == (len(d.meta), H)
    assert np.isfinite(d.y).all()


def test_run_career_beats_ageing_curve_with_ordered_quantiles():
    panel = _panel()
    model, m = run_career(panel, test_end=2022, epochs=8)
    assert m["mae_h1"] < m["baseline_mae_h1"]
    q = model.predict(build(panel, [2022]))
    assert (np.diff(q, axis=2) >= 0).all()  # p10 <= p50 <= p90
    assert 0.3 < m["coverage_h1"] <= 1.0
