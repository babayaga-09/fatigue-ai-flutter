import numpy as np
import pandas as pd

from touchline.fpl.minutes import (
    FEATURES,
    apply_availability,
    baseline_last_gw,
    brier_multi,
    fit_minutes,
    minutes_class,
)


def _rows(n_players=300, n_gw=20, seed=0):
    """Regulars start, rotators flip a coin, bench players rarely play; patterns persist."""
    rng = np.random.default_rng(seed)
    rows = []
    for p in range(n_players):
        kind = p % 3
        hist = []
        for gw in range(1, n_gw + 1):
            r = rng.random()
            mins = (90 if r < 0.9 else 0) if kind == 0 else \
                (90 if r < 0.5 else (20 if r < 0.8 else 0)) if kind == 1 else \
                (15 if r < 0.2 else 0)
            last = hist[-6:]
            rows.append({"element": p, "gw": gw, "minutes": mins,
                         "min_last1": hist[-1] if hist else 0, "min_last3": sum(hist[-3:]),
                         "min_last6": sum(last),
                         "starts_last3": sum(m >= 60 for m in hist[-3:]),
                         "starts_last6": sum(m >= 60 for m in last),
                         "played_share": np.mean([m > 0 for m in hist]) if hist else 0.0,
                         "gws_seen": len(hist), "value": 50 + kind, "position": "MID"})
            hist.append(mins)
    return pd.DataFrame(rows)


def test_minutes_probs_sum_to_one_and_beat_last_gw_baseline():
    d = _rows()
    train, val, test = d[d.gw <= 12], d[(d.gw > 12) & (d.gw <= 15)], d[d.gw > 15]
    m = fit_minutes(train, val)
    p = m.predict(test)
    assert p.shape == (len(test), 3)
    assert np.allclose(p.sum(axis=1), 1.0)
    y = minutes_class(test.minutes)
    assert brier_multi(p, y) < brier_multi(baseline_last_gw(test), y)
    assert set(FEATURES) <= set(d.columns) | {"position"}


def test_chance_of_playing_scales_play_probability():
    p = np.array([[0.1, 0.1, 0.8]])
    q = apply_availability(p, np.array([25.0]))
    assert np.isclose(q.sum(), 1.0)
    assert 1 - q[0, 0] <= 0.25 + 1e-9
    assert np.allclose(apply_availability(p, np.array([np.nan])), p)  # unknown = unchanged
