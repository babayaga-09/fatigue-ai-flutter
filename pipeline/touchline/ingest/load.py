"""Read the gzipped Transfermarkt CSVs into tidy DataFrames via DuckDB."""
from datetime import date
from pathlib import Path

import duckdb
import pandas as pd

from touchline.config import HISTORY_FROM_SEASON, RAW_DIR

_DATE_COLS = {"games": ["date"], "appearances": ["date"], "players": ["dob"],
              "valuations": ["date"], "transfers": ["date"]}


def load_tm(raw_dir: Path = RAW_DIR,
            from_season: int = HISTORY_FROM_SEASON) -> dict[str, pd.DataFrame]:
    con = duckdb.connect()
    r = Path(raw_dir).as_posix()

    def q(sql: str) -> pd.DataFrame:
        return con.sql(sql).df()

    def src(name: str) -> str:
        return f"read_csv_auto('{r}/{name}.csv.gz', header=true)"

    today = date.today().isoformat()
    out = {
        "games": q(f"""
            select game_id, competition_id, competition_type, season, cast(date as date) as date,
                   home_club_id, away_club_id,
                   cast(home_club_goals as int) as home_goals,
                   cast(away_club_goals as int) as away_goals,
                   home_club_name, away_club_name,
                   home_club_manager_name as home_manager,
                   away_club_manager_name as away_manager
            from {src('games')}
            where season >= {from_season} and home_club_goals is not null
              and competition_type <> 'national_team_competition'
            order by date, game_id"""),
        "appearances": q(f"""
            select game_id, player_id, player_club_id as club_id, cast(date as date) as date,
                   competition_id, goals, assists, minutes_played as minutes,
                   yellow_cards, red_cards
            from {src('appearances')}
            where cast(date as date) >= date '{from_season}-07-01'"""),
        "players": q(f"""
            select player_id, name, cast(cast(date_of_birth as timestamp) as date) as dob,
                   position, sub_position, foot, height_in_cm as height,
                   country_of_citizenship as nationality, current_club_id,
                   current_club_domestic_competition_id as league, last_season,
                   market_value_in_eur as market_value, image_url
            from {src('players')}"""),
        "valuations": q(f"""
            select player_id, cast(date as date) as date, market_value_in_eur as value
            from {src('player_valuations')}"""),
        "clubs": q(f"""
            select club_id, name, domestic_competition_id as league, last_season
            from {src('clubs')}"""),
        "transfers": q(f"""
            select player_id, cast(transfer_date as date) as date, from_club_name as from_club,
                   to_club_name as to_club, transfer_fee as fee, from_club_id, to_club_id
            from {src('transfers')}
            where cast(transfer_date as date) <= date '{today}'"""),
    }
    for table, cols in _DATE_COLS.items():
        for c in cols:
            out[table][c] = pd.to_datetime(out[table][c]).astype("datetime64[ns]")
    return out
