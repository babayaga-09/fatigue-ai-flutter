import numpy as np
import pandas as pd

from touchline.features.players import (add_prev_season, build_player_rows, enrich_appearances,
                                        season_ref_date, season_stats)


def _games():
    return pd.DataFrame({
        "game_id": [1, 2, 3], "competition_id": ["GB1", "GB1", "CL"],
        "competition_type": ["domestic_league", "domestic_league", "international_cup"],
        "season": [2024, 2024, 2024],
        "date": pd.to_datetime(["2024-08-10", "2024-08-17", "2024-09-18"]),
        "home_club_id": [1, 2, 1], "away_club_id": [2, 1, 50],
        "home_goals": [1, 0, 2], "away_goals": [0, 0, 1],
        "home_club_name": ["A", "B", "A"], "away_club_name": ["B", "A", "Z"]})


def _apps():
    return pd.DataFrame({
        "game_id": [1, 2, 3, 99], "player_id": [7, 7, 7, 7], "club_id": [1, 1, 1, 1],
        "date": pd.to_datetime(["2024-08-10", "2024-08-17", "2024-09-18", "2024-10-10"]),
        "competition_id": ["GB1", "GB1", "CL", "FIWCQ"], "goals": [1, 0, 1, 0],
        "assists": [0, 1, 0, 0], "minutes": [90, 90, 45, 90],
        "yellow_cards": [0, 1, 0, 0], "red_cards": [0, 0, 0, 0]})


def test_enrich_marks_home_league_and_season():
    e = enrich_appearances(_apps(), _games())
    assert list(e.is_league) == [True, True, False, False]
    assert list(e.is_home) == [1.0, 0.0, 1.0, 0.5]
    assert list(e.season) == [2024] * 4  # game 99 (not in games) gets season from date
    assert list(e.opp_name[:3]) == ["B", "B", "Z"]


def test_season_stats_aggregates():
    s = season_stats(enrich_appearances(_apps(), _games()), _games()).iloc[0]
    assert s.apps == 4 and s.minutes == 315 and s.league_minutes == 180
    assert s.club_id == 1 and s.league == "GB1" and s.team_games == 2
    assert np.isclose(s.minutes_share, 1.0)
    assert np.isclose(s.ga90, 3 / (315 / 90))


def test_prev_season_and_rows_with_target():
    stats = season_stats(enrich_appearances(_apps(), _games()), _games())
    prev = stats.assign(season=2023)
    stats = add_prev_season(pd.concat([prev, stats], ignore_index=True))
    assert stats[stats.season == 2024].prev_minutes.iloc[0] == 315
    players = pd.DataFrame({"player_id": [7], "dob": pd.to_datetime(["2000-07-01"]),
                            "position": ["Attack"], "sub_position": ["Centre-Forward"],
                            "foot": ["left"], "height": [180.0]})
    vals = pd.DataFrame({"player_id": [7, 7],
                         "date": pd.to_datetime(["2025-06-20", "2023-01-01"]),
                         "value": [5_000_000, 1_000_000]})
    hist = pd.DataFrame({"date": pd.to_datetime(["2025-05-01"]), "club_id": [1],
                         "rating": [1600.0]})
    rows = build_player_rows(stats, players, vals, hist, min_league_minutes=100)
    r = rows[rows.season == 2024].iloc[0]
    assert r.target_value == 5_000_000 and np.isclose(r.age, 25.0, atol=0.01)
    assert r.club_elo == 1600.0
    assert season_ref_date(2024) == pd.Timestamp("2025-07-01")


def test_missing_player_fields_do_not_crash():
    stats = season_stats(enrich_appearances(_apps(), _games()), _games())
    players = pd.DataFrame({"player_id": [7], "dob": [pd.NaT], "position": [None],
                            "sub_position": [None], "foot": [None], "height": [np.nan]})
    empty_vals = pd.DataFrame({"player_id": pd.Series([], dtype=int),
                               "date": pd.Series([], dtype="datetime64[ns]"),
                               "value": pd.Series([], dtype=float)})
    empty_hist = pd.DataFrame({"date": pd.Series([], dtype="datetime64[ns]"),
                               "club_id": pd.Series([], dtype=int),
                               "rating": pd.Series([], dtype=float)})
    rows = build_player_rows(add_prev_season(stats), players, empty_vals, empty_hist,
                             min_league_minutes=100, with_target=False)
    assert len(rows) == 1 and np.isnan(rows.iloc[0].age)
