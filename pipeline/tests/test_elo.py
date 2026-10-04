import pandas as pd
import pytest

from touchline.models.elo import EloParams, evaluate_favourites, expected_home, run_elo, tune_elo


def test_expected_home_symmetry():
    assert expected_home(1500, 1500, 0) == pytest.approx(0.5)
    assert expected_home(1600, 1500, 0) > 0.5
    assert expected_home(1500, 1500, 65) > 0.5


def test_ratings_are_zero_sum_and_order_strength(league_games):
    # non-top-5 competition id: every club starts at init, so the total is conserved
    res = run_elo(league_games.assign(competition_id="XX"), EloParams(k=20, home_adv=65))
    r = res.ratings
    assert sum(r.values()) == pytest.approx(1500 * len(r), abs=1e-6)
    assert r[1] > r[6]  # strongest beats weakest
    assert len(res.pre) == len(league_games)
    assert set(res.history.columns) == {"date", "club_id", "rating"}


def test_pre_ratings_are_pre_match(league_games):
    res = run_elo(league_games.head(1))
    assert res.pre.iloc[0].elo_home == 1500 and res.pre.iloc[0].elo_away == 1500


def test_new_league_club_starts_low(league_games):
    extra = league_games.iloc[[-1]].copy()
    extra["game_id"] = 999999
    extra["date"] = extra["date"] + pd.Timedelta(days=5)
    extra["home_club_id"] = 77  # brand new club in the league
    res = run_elo(pd.concat([league_games, extra], ignore_index=True))
    assert res.pre.iloc[-1].elo_home < 1500


def test_start_ratings_are_continued(league_games):
    res = run_elo(league_games.head(1), start={1: 1700.0, 2: 1400.0})
    assert res.pre.iloc[0].elo_home == 1700.0


def test_tune_and_evaluate(league_games):
    val = league_games.season == 2021
    params, grid = tune_elo(league_games, val)
    assert isinstance(params, EloParams) and len(grid) == 12
    res = run_elo(league_games, params)
    m = evaluate_favourites(league_games, res.pre, 2022, params.home_adv)
    assert m["n"] > 0 and 0 <= m["favourite_accuracy"] <= 1
