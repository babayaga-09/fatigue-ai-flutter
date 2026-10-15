"""FPL data: the open per-gameweek archive (vaastav/Fantasy-Premier-League, MIT) for training and
evaluation, and the live FPL API for the current season."""
import json
import time
import urllib.request
from pathlib import Path

import pandas as pd

ARCHIVE = "https://raw.githubusercontent.com/vaastav/Fantasy-Premier-League/master/data"
API = "https://fantasy.premierleague.com/api"
_UA = {"User-Agent": "Mozilla/5.0 (Touchline; +https://github.com/babayaga-09/fatigue-ai-flutter)"}

COLUMNS = ["season", "gw", "element", "name", "position", "team", "opponent_team", "fixture",
           "was_home", "kickoff_time", "minutes", "starts", "total_points", "xP",
           "expected_goals", "expected_assists", "goals_scored", "assists", "clean_sheets",
           "goals_conceded", "saves", "bonus", "yellow_cards", "red_cards",
           "defensive_contribution", "value", "selected"]


class FplUnavailable(RuntimeError):
    pass


def _get(url: str) -> bytes:
    req = urllib.request.Request(url, headers=_UA)
    with urllib.request.urlopen(req, timeout=30) as r:
        return r.read()


def _cached(raw_dir: Path, name: str, url: str) -> Path:
    path = Path(raw_dir) / name
    if not path.exists():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(_get(url))
    return path


def load_archive(seasons: list[str], raw_dir: Path) -> pd.DataFrame:
    frames = []
    for s in seasons:
        p = _cached(raw_dir, f"merged_{s}.csv", f"{ARCHIVE}/{s}/gws/merged_gw.csv")
        d = pd.read_csv(p, encoding="utf-8", encoding_errors="replace", low_memory=False)
        d["season"] = s
        d["gw"] = d["GW"] if "GW" in d else d["round"]
        if "defensive_contribution" not in d:
            d["defensive_contribution"] = 0
        d["position"] = d["position"].replace({"GKP": "GK"})
        d["kickoff_time"] = pd.to_datetime(d["kickoff_time"], utc=True)
        frames.append(d[COLUMNS])
    return pd.concat(frames, ignore_index=True)


def load_fixtures(season: str, raw_dir: Path) -> pd.DataFrame:
    p = _cached(raw_dir, f"fixtures_{season}.csv", f"{ARCHIVE}/{season}/fixtures.csv")
    f = pd.read_csv(p)
    f["kickoff_time"] = pd.to_datetime(f["kickoff_time"], utc=True)
    return f[["id", "event", "kickoff_time", "team_h", "team_a"]]


def teams(season: str, raw_dir: Path) -> dict[int, str]:
    p = _cached(raw_dir, f"teams_{season}.csv", f"{ARCHIVE}/{season}/teams.csv")
    t = pd.read_csv(p)
    return dict(zip(t["id"].astype(int), t["name"], strict=True))


def fetch_live(cache_dir: Path, max_age_s: int = 3600, get=_get) -> dict:
    """bootstrap-static and fixtures, cached on disk; a failed fetch falls back to the cache."""
    cache = Path(cache_dir) / "fpl_live.json"
    if cache.exists() and time.time() - cache.stat().st_mtime < max_age_s:
        return json.loads(cache.read_text(encoding="utf-8"))
    try:
        live = {"bootstrap": json.loads(get(f"{API}/bootstrap-static/")),
                "fixtures": json.loads(get(f"{API}/fixtures/"))}
    except Exception as e:  # network, HTTP or JSON failure
        if cache.exists():
            return json.loads(cache.read_text(encoding="utf-8"))
        raise FplUnavailable(f"FPL API unavailable and no cached copy: {e}") from e
    cache.parent.mkdir(parents=True, exist_ok=True)
    cache.write_text(json.dumps(live), encoding="utf-8")
    return live
