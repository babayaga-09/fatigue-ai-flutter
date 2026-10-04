"""Minimal football-data.org v4 client (free tier: 10 requests/minute)."""
import time

import httpx
import pandas as pd

FD_BASE = "https://api.football-data.org/v4"


class FootballData:
    def __init__(self, token: str, client: httpx.Client | None = None,
                 min_interval: float = 6.5, retry_wait: float = 60.0):
        self._client = client or httpx.Client(base_url=FD_BASE, timeout=30)
        self._headers = {"X-Auth-Token": token}
        self._min_interval = min_interval
        self._retry_wait = retry_wait
        self._last = 0.0

    def _get(self, path: str, params: dict | None = None) -> dict:
        for attempt in range(2):
            wait = self._min_interval - (time.monotonic() - self._last)
            if wait > 0:
                time.sleep(wait)
            r = self._client.get(path, params=params, headers=self._headers)
            self._last = time.monotonic()
            if r.status_code == 200:
                return r.json()
            if attempt == 0 and (r.status_code == 429 or r.status_code >= 500):
                time.sleep(self._retry_wait)
                continue
            r.raise_for_status()
        r.raise_for_status()
        return {}

    def season_teams(self, code: str, season: int) -> pd.DataFrame:
        d = self._get(f"/competitions/{code}/teams", {"season": season})
        return pd.DataFrame([{"fd_id": t["id"], "name": t["name"],
                              "short": t.get("shortName") or t["name"], "crest": t.get("crest")}
                             for t in d.get("teams", [])])

    def season_matches(self, code: str, season: int) -> pd.DataFrame:
        d = self._get(f"/competitions/{code}/matches", {"season": season})
        rows = []
        for m in d.get("matches", []):
            ft = (m.get("score") or {}).get("fullTime") or {}
            rows.append({"fd_match_id": m["id"], "utc": m["utcDate"], "status": m["status"],
                         "matchday": m.get("matchday"), "home_fd": m["homeTeam"]["id"],
                         "away_fd": m["awayTeam"]["id"], "home_goals": ft.get("home"),
                         "away_goals": ft.get("away")})
        df = pd.DataFrame(rows, columns=["fd_match_id", "utc", "status", "matchday", "home_fd",
                                         "away_fd", "home_goals", "away_goals"])
        df["utc"] = pd.to_datetime(df["utc"], utc=True)
        return df
