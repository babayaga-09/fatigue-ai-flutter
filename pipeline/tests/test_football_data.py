import httpx
import pandas as pd
import pytest

from touchline.ingest.football_data import FD_BASE, FootballData

MATCHES = {"matches": [
    {"id": 1, "utcDate": "2026-08-15T14:00:00Z", "status": "FINISHED", "matchday": 1,
     "homeTeam": {"id": 57}, "awayTeam": {"id": 64},
     "score": {"fullTime": {"home": 2, "away": 1}}},
    {"id": 2, "utcDate": "2026-10-10T14:00:00Z", "status": "TIMED", "matchday": 8,
     "homeTeam": {"id": 64}, "awayTeam": {"id": 57},
     "score": {"fullTime": {"home": None, "away": None}}},
]}
TEAMS = {"teams": [{"id": 57, "name": "Arsenal FC", "shortName": "Arsenal", "crest": "c57"}]}


def _client(handler):
    return httpx.Client(base_url=FD_BASE, transport=httpx.MockTransport(handler))


def test_parses_matches_and_teams_and_sends_token():
    seen = {}

    def handler(req):
        seen["token"] = req.headers["X-Auth-Token"]
        return httpx.Response(200, json=MATCHES if req.url.path.endswith("matches") else TEAMS)

    fd = FootballData("tok", client=_client(handler), min_interval=0)
    m = fd.season_matches("PL", 2026)
    assert list(m.status) == ["FINISHED", "TIMED"]
    assert m.loc[0, "home_goals"] == 2 and pd.isna(m.loc[1, "home_goals"])
    assert str(m.utc.dt.tz) == "UTC"
    t = fd.season_teams("PL", 2026)
    assert t.loc[0, "short"] == "Arsenal" and seen["token"] == "tok"


def test_retries_once_on_429_then_succeeds():
    calls = []

    def handler(req):
        calls.append(1)
        return httpx.Response(429) if len(calls) == 1 else httpx.Response(200, json=TEAMS)

    fd = FootballData("tok", client=_client(handler), min_interval=0, retry_wait=0)
    assert len(fd.season_teams("PL", 2026)) == 1 and len(calls) == 2


def test_raises_after_second_failure():
    fd = FootballData("tok", client=_client(lambda r: httpx.Response(429)), min_interval=0,
                      retry_wait=0)
    with pytest.raises(httpx.HTTPStatusError):
        fd.season_teams("PL", 2026)
