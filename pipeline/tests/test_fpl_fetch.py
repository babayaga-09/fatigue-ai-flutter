import json
import os
import time

import pandas as pd
import pytest

from touchline.fpl.fetch import COLUMNS, FplUnavailable, fetch_live, load_archive
from touchline.fpl.teams import UnmappedTeam, club_id

_BASE = {"name": ["A"], "position": ["GKP"], "team": ["Arsenal"], "opponent_team": [2],
         "fixture": [1], "was_home": [True], "kickoff_time": ["2022-08-05T19:00:00Z"],
         "minutes": [90], "starts": [1], "total_points": [6], "xP": [3.1],
         "expected_goals": [0.0], "expected_assists": [0.0], "goals_scored": [0],
         "assists": [0], "clean_sheets": [1], "goals_conceded": [0], "saves": [3],
         "bonus": [0], "yellow_cards": [0], "red_cards": [0], "value": [55], "selected": [10],
         "element": [7], "GW": [1]}


def test_load_archive_normalises_columns(tmp_path):
    pd.DataFrame(_BASE).to_csv(tmp_path / "merged_2022-23.csv", index=False)
    pd.DataFrame({**_BASE, "defensive_contribution": [4]}).to_csv(
        tmp_path / "merged_2025-26.csv", index=False)
    a = load_archive(["2022-23", "2025-26"], tmp_path)
    assert list(a.columns) == COLUMNS
    assert list(a.defensive_contribution) == [0, 4]
    assert set(a.position) == {"GK"}
    assert str(a.kickoff_time.dt.tz) == "UTC"


def test_fetch_live_uses_cache_and_fails_cleanly(tmp_path):
    calls = []

    def ok(url):
        calls.append(url)
        return json.dumps({"url": url}).encode()

    first = fetch_live(tmp_path, get=ok)
    second = fetch_live(tmp_path, get=ok)
    assert first == second and len(calls) == 2  # bootstrap + fixtures, once

    def down(url):
        raise OSError("no network")

    old = time.time() - 7200
    os.utime(tmp_path / "fpl_live.json", (old, old))
    assert fetch_live(tmp_path, get=down) == first  # stale cache beats nothing
    with pytest.raises(FplUnavailable):
        fetch_live(tmp_path / "empty", get=down)


def test_every_archive_team_maps():
    import glob
    files = glob.glob("data/raw/fpl/teams_*.csv")
    if not files:
        pytest.skip("archive not downloaded")
    for f in files:
        for name in pd.read_csv(f).name:
            assert club_id(name) > 0


def test_unmapped_team_raises():
    with pytest.raises(UnmappedTeam):
        club_id("Real Madrid")
