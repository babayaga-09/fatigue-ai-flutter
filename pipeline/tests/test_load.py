import pandas as pd

from touchline.ingest.load import load_tm


def _w(path, df):
    df.to_csv(path, index=False, compression="gzip")


def test_load_tm_filters_and_types(tmp_path):
    _w(tmp_path / "games.csv.gz", pd.DataFrame({
        "game_id": [1, 2, 3, 4], "competition_id": ["GB1", "GB1", "FIWC", "GB1"],
        "competition_type": ["domestic_league", "domestic_league",
                             "national_team_competition", "domestic_league"],
        "season": [2024, 2010, 2024, 2025], "date": ["2024-08-10"] * 3 + ["2025-08-10"],
        "home_club_id": [1, 1, 9, 1], "away_club_id": [2, 2, 8, 2],
        "home_club_goals": [2, 1, 0, None], "away_club_goals": [1, 1, 0, None],
        "home_club_name": ["A"] * 4, "away_club_name": ["B"] * 4}))
    _w(tmp_path / "appearances.csv.gz", pd.DataFrame({
        "appearance_id": ["1_7"], "game_id": [1], "player_id": [7], "player_club_id": [1],
        "player_current_club_id": [1], "date": ["2024-08-10"], "player_name": ["X"],
        "competition_id": ["GB1"], "yellow_cards": [0], "red_cards": [0], "goals": [1],
        "assists": [0], "minutes_played": [90]}))
    _w(tmp_path / "players.csv.gz", pd.DataFrame({
        "player_id": [7], "name": ["X"], "date_of_birth": ["2000-01-01 00:00:00"],
        "position": ["Attack"], "sub_position": ["Centre-Forward"], "foot": ["right"],
        "height_in_cm": [180], "country_of_citizenship": ["England"], "current_club_id": [1],
        "current_club_domestic_competition_id": ["GB1"], "last_season": [2025],
        "market_value_in_eur": [1000000], "image_url": ["http://img"]}))
    _w(tmp_path / "player_valuations.csv.gz", pd.DataFrame({
        "player_id": [7], "date": ["2024-07-01"], "market_value_in_eur": [900000]}))
    _w(tmp_path / "clubs.csv.gz", pd.DataFrame({
        "club_id": [1], "name": ["A"], "domestic_competition_id": ["GB1"], "last_season": [2025]}))
    _w(tmp_path / "transfers.csv.gz", pd.DataFrame({
        "player_id": [7, 7], "transfer_date": ["2023-07-01", "2099-06-30"],
        "from_club_name": ["Y", "A"], "to_club_name": ["A", "Z"],
        "transfer_fee": [5000000.0, None]}))

    tm = load_tm(tmp_path, from_season=2012)

    assert list(tm["games"].game_id) == [1]  # pre-2012, national-team and unplayed dropped
    assert tm["games"]["date"].dtype == "datetime64[ns]"
    assert tm["appearances"].loc[0, "minutes"] == 90
    assert tm["players"].loc[0, "dob"] == pd.Timestamp("2000-01-01")
    assert tm["valuations"].loc[0, "value"] == 900000
    assert list(tm["transfers"].fee) == [5000000.0]  # future-dated rows dropped
