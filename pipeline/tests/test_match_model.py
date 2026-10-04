import numpy as np
import pandas as pd
import pytest

from touchline.models.match_model import (brier, evaluate, fit_match_model, log_loss,
                                          outcome_index, rps)


def _synthetic(n=4000, seed=1):
    rng = np.random.default_rng(seed)
    d = rng.normal(0, 150, n)
    hg = rng.poisson(np.exp(0.3 + 0.25 * d / 100))
    ag = rng.poisson(np.exp(0.05 - 0.25 * d / 100))
    return d, hg, ag


def test_fit_recovers_direction_and_probs_sum_to_one():
    d, hg, ag = _synthetic()
    m = fit_match_model(d, hg, ag)
    assert m.home_coef[1] > 0 and m.away_coef[1] < 0
    p = m.outcome_probs(np.array([-200.0, 0.0, 200.0]))
    assert np.allclose(p.sum(1), 1)
    assert p[2, 0] > p[0, 0]  # stronger home side more likely to win
    mats = m.score_matrices(np.array([0.0]))
    assert mats.shape == (1, 11, 11) and mats.sum() == pytest.approx(1)
    assert -0.2 <= m.rho <= 0.2


def test_metrics_perfect_and_uniform():
    y = np.array([0, 1, 2])
    perfect = np.eye(3)
    assert rps(perfect, y) == pytest.approx(0)
    assert brier(perfect, y) == pytest.approx(0)
    uniform = np.full((3, 3), 1 / 3)
    assert log_loss(uniform, y) == pytest.approx(np.log(3))


def test_outcome_index():
    assert list(outcome_index(np.array([2, 1, 0]), np.array([1, 1, 3]))) == [0, 1, 2]


def test_model_beats_base_rate_baseline():
    d, hg, ag = _synthetic(6000)
    df = pd.DataFrame({"d": d, "home_goals": hg, "away_goals": ag})
    m = fit_match_model(df.d[:4000], df.home_goals[:4000], df.away_goals[:4000])
    out = evaluate(m, df[:4000], df[4000:])
    assert out["rps"] < out["baseline_rps"]
