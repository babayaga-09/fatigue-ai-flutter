import pandas as pd

from touchline.models.budget import greedy_signings, plan_signings


def _cands():
    return pd.DataFrame({
        "player_id": [1, 2, 3, 4, 5],
        "pos": ["Attack", "Attack", "Midfield", "Midfield", "Defender"],
        "price": [60.0, 30.0, 40.0, 25.0, 20.0],
        "score": [80.0, 45.0, 50.0, 40.0, 30.0]})


def test_ilp_respects_budget_and_needs_and_beats_greedy():
    c = _cands()
    pick = plan_signings(c, budget=100, needs={"Attack": 1, "Midfield": 1})
    chosen = c[c.player_id.isin(pick)]
    assert chosen.price.sum() <= 100
    assert sorted(chosen.pos) == ["Attack", "Midfield"]
    greedy = c[c.player_id.isin(greedy_signings(c, 100, {"Attack": 1, "Midfield": 1}))]
    assert chosen.score.sum() >= greedy.score.sum()
    assert set(pick) == {1, 3}  # 60 + 40 = 100 <= 100, score 130 beats {1, 4} = 120


def test_infeasible_returns_empty():
    assert plan_signings(_cands(), budget=10, needs={"Attack": 1}) == []
