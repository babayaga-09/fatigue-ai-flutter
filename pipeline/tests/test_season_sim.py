import numpy as np
import pandas as pd
import pytest

from touchline.models.season_sim import league_table, simulate_season


def test_league_table_points_and_order():
    played = pd.DataFrame({"home": [1, 2, 3], "away": [2, 3, 1],
                           "home_goals": [2, 1, 0], "away_goals": [0, 1, 3]})
    t = league_table([1, 2, 3], played)
    assert list(t.club_id) == [1, 2, 3]
    assert t.set_index("club_id").loc[1, "points"] == 6
    assert list(t.pos) == [1, 2, 3]


def _sure_win_mats(n, g=11):
    m = np.zeros((n, g, g))
    m[:, 3, 0] = 1.0  # home always wins 3-0
    return m


def test_simulation_is_deterministic_when_outcomes_certain():
    remaining = pd.DataFrame({"home": [1, 1, 2], "away": [2, 3, 3]})
    played = pd.DataFrame(columns=["home", "away", "home_goals", "away_goals"])
    out = simulate_season([1, 2, 3], played, remaining, _sure_win_mats(3), n_sims=200,
                          top_n=1, releg_n=1).set_index("club_id")
    assert out.loc[1, "p_title"] == pytest.approx(1.0)
    assert out.loc[3, "p_releg"] == pytest.approx(1.0)
    assert out.loc[1, "exp_points"] == pytest.approx(6.0)


def test_probabilities_sum_correctly():
    rng = np.random.default_rng(0)
    clubs = list(range(1, 7))
    remaining = pd.DataFrame([(h, a) for h in clubs for a in clubs if h != a],
                             columns=["home", "away"])
    mats = rng.random((len(remaining), 11, 11))
    mats /= mats.sum(axis=(1, 2), keepdims=True)
    played = pd.DataFrame(columns=["home", "away", "home_goals", "away_goals"])
    out = simulate_season(clubs, played, remaining, mats, n_sims=500)
    assert out.p_title.sum() == pytest.approx(1.0)
    assert out.p_top4.sum() == pytest.approx(4.0)
    assert out.p_releg.sum() == pytest.approx(3.0)


def test_no_remaining_fixtures_uses_current_table():
    played = pd.DataFrame({"home": [1], "away": [2], "home_goals": [1], "away_goals": [0]})
    empty = pd.DataFrame(columns=["home", "away"])
    out = simulate_season([1, 2], played, empty, np.zeros((0, 11, 11)), n_sims=50,
                          top_n=1, releg_n=1).set_index("club_id")
    assert out.loc[1, "p_title"] == 1.0 and out.loc[2, "p_releg"] == 1.0
