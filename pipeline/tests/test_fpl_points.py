import numpy as np
import pandas as pd
import pytest

from touchline.fpl.evaluate import evaluate, gate
from touchline.fpl.points import per_gameweek, predict_points


class _Mins:
    """Certain 90 minutes for everyone."""
    def predict(self, d):
        return np.tile([0.0, 0.0, 1.0], (len(d), 1))

    def expected_minutes(self, p):
        return p[:, 2] * 90.0


def _row(element=1, gw=1, fixture=1, pos="FWD", xg=0.5):
    return dict(season="2024-25", gw=gw, element=element, fixture=fixture, position=pos,
                expected_goals_90=xg, expected_assists_90=0.0, saves_90=0.0, bonus_90=0.0,
                yellow_cards_90=0.0, red_cards_90=0.0, dc_rate=0.0, att_mult=1.0, p_cs=0.0,
                lam_against=1.0)


def test_double_gameweek_sums_fixtures():
    rows = pd.DataFrame([_row(fixture=1), _row(fixture=2)])
    pred = predict_points(rows, _Mins())
    assert pred.xpts.tolist() == pytest.approx([2 + 0.5 * 4] * 2)
    gw = per_gameweek(pred)
    assert len(gw) == 1 and gw.xpts.item() == pytest.approx(8.0)
    assert gw.p_play.item() == pytest.approx(1.0)


def test_breakdown_columns_sum_to_xpts():
    pred = predict_points(pd.DataFrame([_row(pos="DEF")]), _Mins())
    parts = pred[["minutes", "attack", "defence", "bonus", "other"]].sum(axis=1)
    assert parts.item() == pytest.approx(pred.xpts.item())


def _season(noise_ours, noise_fpl, seed=0):
    rng = np.random.default_rng(seed)
    rows = []
    for gw in range(1, 11):
        for el in range(40):
            truth = rng.poisson(2 + el % 5)
            rows.append(dict(season="2025-26", gw=gw, element=el, total_points=truth,
                             xP=truth + rng.normal(0, noise_fpl), selected=1000 - el,
                             min_last3=90, xpts=truth + rng.normal(0, noise_ours)))
    d = pd.DataFrame(rows)
    return d[["season", "gw", "element", "xpts"]], d.drop(columns="xpts")


def test_evaluate_on_synthetic_where_truth_is_known():
    pred, actual = _season(noise_ours=0.5, noise_fpl=2.5)
    m = evaluate(pred, actual)
    assert m["mae"] < m["mae_fpl"] and m["spearman"] > m["spearman_fpl"]
    assert m["gameweeks"] == 10 and m["n"] == 400


def test_gate_requires_both_mae_and_captaincy():
    base = {"mae": 1.0, "mae_fpl": 2.0, "captain_points": 100, "captain_points_fpl": 90}
    assert gate(base) == "ours"
    assert gate({**base, "captain_points": 80}) == "fpl"
    assert gate({**base, "mae": 3.0}) == "fpl"
