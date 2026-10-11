import pandas as pd

from touchline.models.elo import EloParams, run_elo
from touchline.models.match_model import MatchModel
from touchline.season import league_snapshot, offline_clubs

MODEL = MatchModel((0.3, 0.25), (0.05, -0.25), -0.05)


def _teams():
    return pd.DataFrame({"fd_id": [57, 64, 1076], "club_id": [11, 31, -1076],
                         "name": ["Arsenal FC", "Liverpool FC", "Coventry City FC"],
                         "short": ["Arsenal", "Liverpool", "Coventry"], "crest": ["a", "b", "c"]})


def _matches(today):
    return pd.DataFrame({
        "fd_match_id": [1, 2, 3, 4],
        "utc": pd.to_datetime([today - pd.Timedelta(days=3), today - pd.Timedelta(days=60),
                               today + pd.Timedelta(days=2), today + pd.Timedelta(days=40)],
                              utc=True),
        "status": ["FINISHED", "FINISHED", "TIMED", "TIMED"], "matchday": [2, 1, 3, 4],
        "home_fd": [57, 64, 1076, 57], "away_fd": [64, 1076, 57, 1076],
        "home_goals": [2, 3, None, None], "away_goals": [0, 0, None, None],
        "home": [11, 31, -1076, 11], "away": [31, -1076, 11, -1076]})


def test_snapshot_handles_new_club_and_builds_records():
    today = pd.Timestamp("2026-10-04", tz="UTC")
    hist = pd.DataFrame({"date": pd.to_datetime(["2026-05-01", "2026-05-01"]),
                         "club_id": [11, 31], "rating": [1700.0, 1650.0]})
    clubs, fixtures = league_snapshot("GB1", _teams(), _matches(today), {11: 1700.0, 31: 1650.0},
                                      hist, EloParams(), MODEL, today, n_sims=200)
    by_id = {c["id"]: c for c in clubs}
    assert set(by_id) == {11, 31, -1076}
    assert by_id[-1076]["elo"] < 1650  # new club starts low
    assert by_id[11]["table"]["points"] == 3 and by_id[11]["form"] == ["W"]
    assert abs(sum(c["proj"]["p_title"] for c in clubs) - 1) < 1e-9
    ids = [f["id"] for f in fixtures]
    assert ids == [1, 3]  # last 7 days + next 14 days only
    assert fixtures[0]["score"] == [2, 0] and abs(sum(fixtures[1]["p"]) - 1) < 1e-9
    assert fixtures[1]["kickoff"].endswith("Z")


def test_offline_clubs_uses_last_tm_season(league_games):
    res = run_elo(league_games)
    tm_clubs = pd.DataFrame({"club_id": range(1, 7), "name": [f"C{i}" for i in range(1, 7)],
                             "league": "GB1", "last_season": 2022})
    clubs = offline_clubs(league_games, tm_clubs, res, 2022)
    assert len(clubs) == 6 and clubs[0]["proj"] is None
    assert sorted(c["table"]["pos"] for c in clubs) == list(range(1, 7))


def test_matches_already_in_history_are_not_replayed_in_elo():
    today = pd.Timestamp("2026-10-04", tz="UTC")
    hist = pd.DataFrame({"date": pd.to_datetime(["2026-05-01"] * 2), "club_id": [11, 31],
                         "rating": [1700.0, 1650.0]})
    args = ("GB1", _teams(), _matches(today), {11: 1700.0, 31: 1650.0}, hist, EloParams(),
            MODEL, today)
    replay, _ = league_snapshot(*args, n_sims=50)
    cutoff = (today - pd.Timedelta(days=1)).tz_localize(None)
    skip, _ = league_snapshot(*args, n_sims=50, history_until=cutoff)
    by = {c["id"]: c for c in skip}
    assert by[11]["elo"] == 1700.0 and by[11]["table"]["points"] == 3  # table still counts it
    assert {c["id"]: c for c in replay}[11]["elo"] != 1700.0


def test_snapshot_attaches_club_colours():
    today = pd.Timestamp("2026-10-04", tz="UTC")
    hist = pd.DataFrame({"date": pd.to_datetime(["2026-05-01"] * 2), "club_id": [11, 31],
                         "rating": [1700.0, 1650.0]})
    clubs, _ = league_snapshot("GB1", _teams(), _matches(today), {11: 1700.0, 31: 1650.0}, hist,
                               EloParams(), MODEL, today, n_sims=50,
                               colours={57: ["#DB0007", "#FFFFFF"]})
    by = {c["id"]: c for c in clubs}
    assert by[11]["colors"] == ["#DB0007", "#FFFFFF"]
    assert by[31]["colors"] is None


def test_colour_table_is_well_formed():
    import re

    from touchline.ingest.club_map import load_club_colours
    table = load_club_colours()
    assert len(table) >= 96
    assert all(len(v) == 2 and all(re.fullmatch(r"#[0-9A-F]{6}", c) for c in v)
               for v in table.values())
