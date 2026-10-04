# Touchline Pipeline (Plan 1 of 2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A reproducible Python pipeline that turns the open Transfermarkt dataset + football-data.org current-season fixtures into eight evaluated models and one versioned, gzipped JSON bundle the Flutter app (Plan 2) will read.

**Architecture:** Pure-function modules that take/return pandas DataFrames (testable with tiny synthetic frames), wired together by `touchline/run.py`. DuckDB reads the gzipped CSVs; LightGBM, PyTorch (GRU), scikit-learn and SciPy do the modelling. Output: `data/out/touchline-bundle.json.gz` + `data/out/metrics.json`. A baseline gate fails the run if a model stops beating its baseline.

**Tech Stack:** Python 3.12, duckdb, pandas, numpy, scipy, scikit-learn, lightgbm, torch (CPU), httpx, python-dotenv, pytest, ruff.

**Spec:** `docs/superpowers/specs/2026-10-04-touchline-design.md`

## Global Constraints

- Leagues (Transfermarkt id → football-data code, name): `GB1→PL Premier League`, `ES1→PD LaLiga`, `L1→BL1 Bundesliga`, `IT1→SA Serie A`, `FR1→FL1 Ligue 1`.
- Dataset base URL: `https://pub-e682421888d945d684bcae8890b0ec20.r2.dev/data/{table}.csv.gz` (CC0).
- History used from season 2012; models train from season 2014 (Elo warm-up).
- Time-based splits only. `test_season` = latest Transfermarkt season present for the 5 leagues (2025 = 2025/26 today); `val_season = test_season - 1`.
- football-data.org free tier: ≤10 requests/minute → client spaces calls ≥6.5 s. Token from env `FOOTBALL_API_KEY`, never written to any output.
- Bundle: `schema_version: 1`, valid strict JSON (no NaN/Infinity), gzip, all money in EUR integers.
- Model outputs for players with < 900 minutes in the display season are `null` (app shows "Not enough minutes yet") — never fabricated.
- Workload is a *risk index*, never called injury probability.
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- All commands run from `C:\Users\91750\touchline\pipeline` using `.venv/Scripts/python` (Git Bash paths).

## Data reality (discovered 2026-10-04)

The Transfermarkt dataset currently ends at the 2025/26 season (last appearance 2026-06-28); the 2026/27 season is not yet in it. Therefore: **club side is live** (football-data.org 2026/27 results + fixtures, Elo continued from history), **player side shows 2025/26** and is labelled as such. The pipeline is season-agnostic: when the dataset adds 2026/27, `test_season` advances automatically.

## Review Focus

1. **NaN in output** — any NaN/inf reaching the bundle makes it invalid JSON for Dart → `sanitize()` converts to null and `json.dumps(allow_nan=False)` enforces it (Task 13 test).
2. **Unmapped football-data club** (promoted side never in Transfermarkt, e.g. Coventry) → gets id `-fd_id` and a bottom-of-league starting Elo, no crash (Tasks 6 & 7 tests).
3. **Player with missing fields** (no DOB, no valuations, no position, zero minutes) → features become NaN, model outputs null, no crash (Tasks 8, 9 tests).
4. **football-data 429 / transient error** → one retry after 60 s, then raise so the refresh workflow fails and the previous Release stays live (Task 6 test).
5. **Leakage** — test-season rows in training would inflate metrics → explicit split assertions (Tasks 9, 10 tests).

---

## File Structure

```
pipeline/
  pyproject.toml
  .gitignore                      (data/raw, data/out, .venv, caches)
  touchline/
    __init__.py
    config.py                     paths, leagues, constants, current_season()
    ingest/__init__.py
    ingest/download.py            download_tables()
    ingest/load.py                load_tm() -> dict[str, DataFrame]
    ingest/football_data.py       FootballData client (rate-limited, retry)
    ingest/club_map.py            norm_tokens(), similarity(), map_clubs(), load_overrides()
    ingest/club_overrides.json    manual fd_id -> tm club_id fixes
    models/__init__.py
    models/elo.py                 M1
    models/match_model.py         M2
    models/season_sim.py          M3
    models/valuator.py            M4
    models/form.py                M5 (GRU + baselines)
    models/workload.py            M6
    models/similarity.py          M7
    models/budget.py              M8
    models/trending.py            trending score
    features/__init__.py
    features/players.py           appearance enrichment, season stats, valuation rows
    season.py                     current-season club snapshot (Elo update, table, sim, fixtures)
    export/__init__.py
    export/bundle.py              sanitize(), write_bundle(), validate_bundle(), player_record()
    run.py                        orchestration CLI + baseline gate
  tests/
    conftest.py                   synthetic data factories
    test_*.py                     one per module
docs/bundle-schema.md
.github/workflows/ci.yml
.github/workflows/refresh.yml
```

---

### Task 1: Scaffold, config, dataset download

**Files:**
- Create: `pipeline/pyproject.toml`, `pipeline/.gitignore`, `pipeline/touchline/__init__.py`, `pipeline/touchline/config.py`, `pipeline/touchline/ingest/__init__.py`, `pipeline/touchline/ingest/download.py`
- Test: `pipeline/tests/test_config_download.py`

**Interfaces:**
- Produces: `config.LEAGUES: dict[str, tuple[str, str]]`, `config.RAW_DIR`, `config.OUT_DIR`, `config.TM_BASE`, `config.TM_TABLES`, `config.HISTORY_FROM_SEASON=2012`, `config.MODEL_FROM_SEASON=2014`, `config.SCHEMA_VERSION=1`, `config.current_season(today: date | None) -> int`; `download_tables(dest: Path, tables: list[str], force: bool=False, client: httpx.Client | None=None) -> list[Path]`

- [ ] **Step 1: Create the venv and project files**

`pipeline/pyproject.toml`:
```toml
[project]
name = "touchline-pipeline"
version = "0.1.0"
requires-python = ">=3.11"
dependencies = [
  "duckdb>=1.1", "pandas>=2.2", "numpy>=1.26", "scipy>=1.13",
  "scikit-learn>=1.5", "lightgbm>=4.3", "torch>=2.3",
  "httpx>=0.27", "python-dotenv>=1.0",
]

[project.optional-dependencies]
dev = ["pytest>=8", "ruff>=0.6"]

[build-system]
requires = ["setuptools>=69"]
build-backend = "setuptools.build_meta"

[tool.setuptools.packages.find]
include = ["touchline*"]

[tool.setuptools.package-data]
touchline = ["ingest/*.json"]

[tool.pytest.ini_options]
testpaths = ["tests"]
markers = ["slow: needs the real downloaded dataset"]

[tool.ruff]
line-length = 100
```

`pipeline/.gitignore`:
```
.venv/
data/raw/
data/out/
__pycache__/
.pytest_cache/
.ruff_cache/
*.egg-info/
```

Run:
```bash
cd /c/Users/91750/touchline/pipeline
.venv/Scripts/python -m pip install -q --upgrade pip
.venv/Scripts/python -m pip install -q torch --index-url https://download.pytorch.org/whl/cpu
.venv/Scripts/python -m pip install -q -e ".[dev]"
```

`pipeline/touchline/__init__.py`: empty. `pipeline/touchline/ingest/__init__.py`: empty.

- [ ] **Step 2: Write the failing tests**

`pipeline/tests/test_config_download.py`:
```python
import gzip
from datetime import date

import httpx

from touchline import config
from touchline.ingest.download import download_tables


def test_current_season_rolls_over_in_july():
    assert config.current_season(date(2026, 10, 4)) == 2026
    assert config.current_season(date(2026, 6, 30)) == 2025
    assert config.current_season(date(2026, 7, 1)) == 2026


def test_leagues_cover_top_five():
    assert set(config.LEAGUES) == {"GB1", "ES1", "L1", "IT1", "FR1"}
    assert config.LEAGUES["GB1"] == ("PL", "Premier League")


def test_download_writes_files_and_skips_existing(tmp_path):
    calls = []

    def handler(request):
        calls.append(request.url.path)
        return httpx.Response(200, content=gzip.compress(b"a,b\n1,2\n"))

    client = httpx.Client(transport=httpx.MockTransport(handler))
    paths = download_tables(tmp_path, ["games", "clubs"], client=client)
    assert [p.name for p in paths] == ["games.csv.gz", "clubs.csv.gz"]
    assert gzip.decompress(paths[0].read_bytes()) == b"a,b\n1,2\n"
    download_tables(tmp_path, ["games", "clubs"], client=client)
    assert len(calls) == 2  # second call reused cached files
    download_tables(tmp_path, ["games"], client=client, force=True)
    assert len(calls) == 3
```

- [ ] **Step 3: Run to verify failure**

Run: `.venv/Scripts/python -m pytest tests/test_config_download.py -v`
Expected: FAIL — `ModuleNotFoundError: touchline.config`

- [ ] **Step 4: Implement**

`pipeline/touchline/config.py`:
```python
"""Project-wide constants. Everything tunable lives here."""
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = ROOT / "data"
RAW_DIR = DATA_DIR / "raw"
OUT_DIR = DATA_DIR / "out"

TM_BASE = "https://pub-e682421888d945d684bcae8890b0ec20.r2.dev/data"
TM_TABLES = ["competitions", "clubs", "players", "games", "appearances",
             "player_valuations", "transfers"]

# Transfermarkt competition id -> (football-data.org code, display name)
LEAGUES: dict[str, tuple[str, str]] = {
    "GB1": ("PL", "Premier League"),
    "ES1": ("PD", "LaLiga"),
    "L1": ("BL1", "Bundesliga"),
    "IT1": ("SA", "Serie A"),
    "FR1": ("FL1", "Ligue 1"),
}

HISTORY_FROM_SEASON = 2012
MODEL_FROM_SEASON = 2014
SCHEMA_VERSION = 1
MIN_DISPLAY_MINUTES = 900
BUNDLE_NAME = "touchline-bundle.json.gz"


def current_season(today: date | None = None) -> int:
    """Season label = calendar year it starts in (2026 = 2026/27)."""
    today = today or date.today()
    return today.year if today.month >= 7 else today.year - 1
```

`pipeline/touchline/ingest/download.py`:
```python
"""Download the Transfermarkt open dataset tables (CC0)."""
from pathlib import Path

import httpx

from touchline.config import RAW_DIR, TM_BASE, TM_TABLES


def download_tables(dest: Path = RAW_DIR, tables: list[str] = TM_TABLES, force: bool = False,
                    client: httpx.Client | None = None, base: str = TM_BASE) -> list[Path]:
    dest.mkdir(parents=True, exist_ok=True)
    own = client is None
    client = client or httpx.Client(timeout=300, follow_redirects=True)
    paths = []
    try:
        for t in tables:
            path = dest / f"{t}.csv.gz"
            if force or not path.exists():
                tmp = dest / f"{t}.part"
                with client.stream("GET", f"{base}/{t}.csv.gz") as r:
                    r.raise_for_status()
                    with open(tmp, "wb") as f:
                        for chunk in r.iter_bytes(1 << 20):
                            f.write(chunk)
                tmp.replace(path)
            paths.append(path)
    finally:
        if own:
            client.close()
    return paths
```

- [ ] **Step 5: Run tests — expect PASS**

Run: `.venv/Scripts/python -m pytest tests/test_config_download.py -v`

- [ ] **Step 6: Commit**

```bash
cd /c/Users/91750/touchline
git add pipeline/pyproject.toml pipeline/.gitignore pipeline/touchline pipeline/tests
git commit -m "feat(pipeline): scaffold, config and dataset download"
```

---

### Task 2: Load Transfermarkt tables

**Files:**
- Create: `pipeline/touchline/ingest/load.py`
- Test: `pipeline/tests/test_load.py`

**Interfaces:**
- Consumes: `config.RAW_DIR`, `config.HISTORY_FROM_SEASON`
- Produces: `load_tm(raw_dir: Path, from_season: int) -> dict[str, DataFrame]` with keys and columns:
  - `games`: game_id, competition_id, competition_type, season, date, home_club_id, away_club_id, home_goals, away_goals, home_club_name, away_club_name (played games only, no national-team comps)
  - `appearances`: game_id, player_id, club_id, date, competition_id, goals, assists, minutes, yellow_cards, red_cards
  - `players`: player_id, name, dob, position, sub_position, foot, height, nationality, current_club_id, league, last_season, market_value, image_url
  - `valuations`: player_id, date, value
  - `clubs`: club_id, name, league, last_season
  - `transfers`: player_id, date, from_club, to_club, fee
  - All date columns are `datetime64[ns]`.

- [ ] **Step 1: Write the failing test**

`pipeline/tests/test_load.py`:
```python
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
```

- [ ] **Step 2: Run — expect FAIL** (`ModuleNotFoundError: touchline.ingest.load`)

Run: `.venv/Scripts/python -m pytest tests/test_load.py -v`

- [ ] **Step 3: Implement**

`pipeline/touchline/ingest/load.py`:
```python
"""Read the gzipped Transfermarkt CSVs into tidy DataFrames via DuckDB."""
from datetime import date
from pathlib import Path

import duckdb
import pandas as pd

from touchline.config import HISTORY_FROM_SEASON, RAW_DIR

_DATE_COLS = {"games": ["date"], "appearances": ["date"], "players": ["dob"],
              "valuations": ["date"], "transfers": ["date"]}


def load_tm(raw_dir: Path = RAW_DIR, from_season: int = HISTORY_FROM_SEASON) -> dict[str, pd.DataFrame]:
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
                   cast(home_club_goals as int) as home_goals, cast(away_club_goals as int) as away_goals,
                   home_club_name, away_club_name
            from {src('games')}
            where season >= {from_season} and home_club_goals is not null
              and competition_type <> 'national_team_competition'
            order by date, game_id"""),
        "appearances": q(f"""
            select game_id, player_id, player_club_id as club_id, cast(date as date) as date,
                   competition_id, goals, assists, minutes_played as minutes, yellow_cards, red_cards
            from {src('appearances')}
            where cast(date as date) >= date '{from_season}-07-01'"""),
        "players": q(f"""
            select player_id, name, cast(cast(date_of_birth as timestamp) as date) as dob, position,
                   sub_position, foot, height_in_cm as height,
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
                   to_club_name as to_club, transfer_fee as fee
            from {src('transfers')}
            where cast(transfer_date as date) <= date '{today}'"""),
    }
    for table, cols in _DATE_COLS.items():
        for c in cols:
            out[table][c] = pd.to_datetime(out[table][c]).astype("datetime64[ns]")
    return out
```

- [ ] **Step 4: Run — expect PASS**

- [ ] **Step 5: Commit**

```bash
git add pipeline/touchline/ingest/load.py pipeline/tests/test_load.py
git commit -m "feat(pipeline): load Transfermarkt tables via DuckDB"
```

---

### Task 3: M1 — Club Elo ratings

**Files:**
- Create: `pipeline/touchline/models/__init__.py` (empty), `pipeline/touchline/models/elo.py`
- Create: `pipeline/tests/conftest.py`
- Test: `pipeline/tests/test_elo.py`

**Interfaces:**
- Consumes: games DataFrame (Task 2 shape; needs game_id, date, competition_id, home_club_id, away_club_id, home_goals, away_goals)
- Produces:
  - `EloParams(k: float=20, home_adv: float=65, init: float=1500)` (frozen dataclass)
  - `expected_home(r_home, r_away, home_adv) -> float | ndarray`
  - `EloResult(ratings: dict[int, float], pre: DataFrame[game_id, elo_home, elo_away], history: DataFrame[date, club_id, rating])`
  - `run_elo(games, params=EloParams(), start: dict[int, float] | None=None) -> EloResult`
  - `tune_elo(games, val_mask: pd.Series) -> tuple[EloParams, list[dict]]`
  - `evaluate_favourites(games, pre, season, home_adv) -> dict` keys: test_season, n, favourite_accuracy, baseline_home_pick_accuracy

- [ ] **Step 1: Shared test factory**

`pipeline/tests/conftest.py`:
```python
import numpy as np
import pandas as pd
import pytest


def make_league_games(n_seasons=3, n_clubs=6, league="GB1", seed=0, first_season=2020,
                      start_id=1):
    """Double round-robin seasons where club strength = club index (club 0 strongest)."""
    rng = np.random.default_rng(seed)
    strength = np.linspace(1.0, -1.0, n_clubs)
    rows, gid = [], start_id
    for s in range(n_seasons):
        season = first_season + s
        day = pd.Timestamp(season, 8, 1)
        for h in range(n_clubs):
            for a in range(n_clubs):
                if h == a:
                    continue
                lh = np.exp(0.25 + 0.5 * (strength[h] - strength[a]))
                la = np.exp(0.0 + 0.5 * (strength[a] - strength[h]))
                rows.append({"game_id": gid, "competition_id": league,
                             "competition_type": "domestic_league", "season": season,
                             "date": day, "home_club_id": h + 1, "away_club_id": a + 1,
                             "home_goals": int(rng.poisson(lh)), "away_goals": int(rng.poisson(la)),
                             "home_club_name": f"C{h + 1}", "away_club_name": f"C{a + 1}"})
                gid += 1
                day += pd.Timedelta(days=3)
    return pd.DataFrame(rows)


@pytest.fixture
def league_games():
    return make_league_games()
```

- [ ] **Step 2: Write the failing tests**

`pipeline/tests/test_elo.py`:
```python
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
```

- [ ] **Step 3: Run — expect FAIL** (`ModuleNotFoundError`)

Run: `.venv/Scripts/python -m pytest tests/test_elo.py -v`

- [ ] **Step 4: Implement**

`pipeline/touchline/models/elo.py`:
```python
"""M1 — club Elo ratings with home advantage and margin-of-victory scaling."""
from dataclasses import dataclass
from itertools import product

import numpy as np
import pandas as pd

from touchline.config import LEAGUES


@dataclass(frozen=True)
class EloParams:
    k: float = 20.0
    home_adv: float = 65.0
    init: float = 1500.0


@dataclass
class EloResult:
    ratings: dict[int, float]
    pre: pd.DataFrame
    history: pd.DataFrame


def expected_home(r_home, r_away, home_adv):
    return 1.0 / (1.0 + 10 ** ((r_away - (r_home + home_adv)) / 400.0))


def _mov(goal_diff: int, winner_edge: float) -> float:
    if goal_diff == 0:
        return 1.0
    return float(np.log(abs(goal_diff) + 1) * (2.2 / (winner_edge * 0.001 + 2.2)))


def run_elo(games: pd.DataFrame, params: EloParams = EloParams(),
            start: dict[int, float] | None = None) -> EloResult:
    """Process games in date order. Clubs first seen in a top-5 league start at the 15th
    percentile of that league's recently active ratings (promoted sides are weak)."""
    g = games.sort_values(["date", "game_id"])
    ratings: dict[int, float] = dict(start or {})
    league_seen: dict[str, dict[int, pd.Timestamp]] = {}
    pre_h, pre_a, hist = [], [], []
    cols = ["game_id", "date", "competition_id", "home_club_id", "away_club_id",
            "home_goals", "away_goals"]
    for gid, date, comp, h, a, hg, ag in g[cols].itertuples(index=False):
        h, a = int(h), int(a)
        for club in (h, a):
            if club not in ratings:
                ratings[club] = _start_rating(comp, date, league_seen, ratings, params)
        if comp in LEAGUES:
            seen = league_seen.setdefault(comp, {})
            seen[h] = date
            seen[a] = date
        rh, ra = ratings[h], ratings[a]
        pre_h.append(rh)
        pre_a.append(ra)
        gd = int(hg) - int(ag)
        score = 1.0 if gd > 0 else 0.5 if gd == 0 else 0.0
        e = expected_home(rh, ra, params.home_adv)
        edge = (rh + params.home_adv - ra) if gd > 0 else (ra - rh - params.home_adv)
        delta = params.k * _mov(gd, edge) * (score - e)
        ratings[h] = rh + delta
        ratings[a] = ra - delta
        hist.append((date, h, ratings[h]))
        hist.append((date, a, ratings[a]))
    pre = pd.DataFrame({"game_id": g["game_id"].to_numpy(), "elo_home": pre_h, "elo_away": pre_a})
    history = pd.DataFrame(hist, columns=["date", "club_id", "rating"])
    return EloResult(ratings=ratings, pre=pre, history=history)


def _start_rating(comp, date, league_seen, ratings, params) -> float:
    if comp not in LEAGUES or comp not in league_seen:
        return params.init
    recent = [ratings[c] for c, d in league_seen[comp].items()
              if c in ratings and (date - d).days <= 365]
    return float(np.percentile(recent, 15)) if len(recent) >= 5 else params.init


def tune_elo(games: pd.DataFrame, val_mask: pd.Series) -> tuple[EloParams, list[dict]]:
    """Grid-search k / home advantage by Brier score of the expected result on val games."""
    val_ids = set(games.loc[val_mask, "game_id"])
    grid = []
    for k, hadv in product([15, 20, 25, 30], [45, 65, 85]):
        p = EloParams(k=k, home_adv=hadv)
        res = run_elo(games, p)
        v = games[games.game_id.isin(val_ids)].merge(res.pre, on="game_id")
        e = expected_home(v.elo_home.to_numpy(), v.elo_away.to_numpy(), hadv)
        s = np.sign(v.home_goals - v.away_goals).to_numpy() * 0.5 + 0.5
        grid.append({"k": k, "home_adv": hadv, "brier": float(np.mean((e - s) ** 2))})
    best = min(grid, key=lambda r: r["brier"])
    return EloParams(k=best["k"], home_adv=best["home_adv"]), grid


def evaluate_favourites(games, pre, season: int, home_adv: float) -> dict:
    lg = games[(games.season == season) & games.competition_id.isin(list(LEAGUES))]
    dec = lg[lg.home_goals != lg.away_goals].merge(pre, on="game_id")
    home_won = (dec.home_goals > dec.away_goals).to_numpy()
    pick_home = (dec.elo_home + home_adv >= dec.elo_away).to_numpy()
    return {"test_season": season, "n": int(len(dec)),
            "favourite_accuracy": float((pick_home == home_won).mean()) if len(dec) else 0.0,
            "baseline_home_pick_accuracy": float(home_won.mean()) if len(dec) else 0.0}
```

Note: the conftest league uses `"GB1"`, so the new-club rule is exercised.

- [ ] **Step 5: Run — expect PASS**

- [ ] **Step 6: Commit**

```bash
git add pipeline/touchline/models pipeline/tests/conftest.py pipeline/tests/test_elo.py
git commit -m "feat(pipeline): M1 club Elo with tuning and evaluation"
```

---

### Task 4: M2 — Match outcome model (Elo-Poisson + Dixon-Coles)

**Files:**
- Create: `pipeline/touchline/models/match_model.py`
- Test: `pipeline/tests/test_match_model.py`

**Interfaces:**
- Consumes: Elo differences (`elo_home - elo_away`) from Task 3
- Produces:
  - `MatchModel(home_coef: tuple[float, float], away_coef: tuple[float, float], rho: float)` with `.rates(elo_diff) -> (lh, la)`, `.score_matrices(elo_diff, max_goals=10) -> ndarray (n, G, G)` indexed `[match, home_goals, away_goals]`, `.outcome_probs(elo_diff) -> ndarray (n, 3)` columns home/draw/away, `.to_dict()`
  - `fit_match_model(elo_diff, home_goals, away_goals) -> MatchModel`
  - `outcome_index(hg, ag) -> ndarray[int]` (0 home, 1 draw, 2 away)
  - `rps(p, y)`, `log_loss(p, y)`, `brier(p, y)` -> float
  - `evaluate(model, train: DataFrame[d, home_goals, away_goals], test: same) -> dict` keys n_test, rps, log_loss, brier, baseline_rps, baseline_log_loss, baseline_brier, rho

- [ ] **Step 1: Write the failing tests**

`pipeline/tests/test_match_model.py`:
```python
import numpy as np
import pytest

from touchline.models.match_model import (brier, evaluate, fit_match_model, log_loss,
                                          outcome_index, rps)


def _synthetic(n=4000, seed=1):
    rng = np.random.default_rng(seed)
    d = rng.normal(0, 150, n)
    hg = rng.poisson(np.exp(0.3 + 0.25 * d / 100))
    ag = rng.poisson(np.exp(0.05 - 0.25 * d / 100))
    return d, hg, ag


def test_fit_recovers_direction_and_probs_sum_to_one():
    d, hg, ag = _synthetic()
    m = fit_match_model(d, hg, ag)
    assert m.home_coef[1] > 0 and m.away_coef[1] < 0
    p = m.outcome_probs(np.array([-200.0, 0.0, 200.0]))
    assert np.allclose(p.sum(1), 1)
    assert p[2, 0] > p[0, 0]  # stronger home side more likely to win
    mats = m.score_matrices(np.array([0.0]))
    assert mats.shape == (1, 11, 11) and mats.sum() == pytest.approx(1)
    assert -0.2 <= m.rho <= 0.2


def test_metrics_perfect_and_uniform():
    y = np.array([0, 1, 2])
    perfect = np.eye(3)
    assert rps(perfect, y) == pytest.approx(0)
    assert brier(perfect, y) == pytest.approx(0)
    uniform = np.full((3, 3), 1 / 3)
    assert log_loss(uniform, y) == pytest.approx(np.log(3))


def test_outcome_index():
    assert list(outcome_index(np.array([2, 1, 0]), np.array([1, 1, 3]))) == [0, 1, 2]


def test_model_beats_base_rate_baseline():
    d, hg, ag = _synthetic(6000)
    import pandas as pd
    df = pd.DataFrame({"d": d, "home_goals": hg, "away_goals": ag})
    m = fit_match_model(df.d[:4000], df.home_goals[:4000], df.away_goals[:4000])
    out = evaluate(m, df[:4000], df[4000:])
    assert out["rps"] < out["baseline_rps"]
```

- [ ] **Step 2: Run — expect FAIL**

- [ ] **Step 3: Implement**

`pipeline/touchline/models/match_model.py`:
```python
"""M2 — match outcome model: Poisson goals driven by Elo gap + Dixon-Coles low-score fix."""
from dataclasses import asdict, dataclass

import numpy as np
from scipy.optimize import minimize_scalar
from scipy.stats import poisson
from sklearn.linear_model import PoissonRegressor


@dataclass
class MatchModel:
    home_coef: tuple[float, float]
    away_coef: tuple[float, float]
    rho: float

    def rates(self, elo_diff):
        d = np.asarray(elo_diff, dtype=float) / 100.0
        lh = np.exp(self.home_coef[0] + self.home_coef[1] * d)
        la = np.exp(self.away_coef[0] + self.away_coef[1] * d)
        return lh, la

    def score_matrices(self, elo_diff, max_goals: int = 10) -> np.ndarray:
        lh, la = self.rates(elo_diff)
        g = np.arange(max_goals + 1)
        ph = poisson.pmf(g[None, :], lh[:, None])
        pa = poisson.pmf(g[None, :], la[:, None])
        m = ph[:, :, None] * pa[:, None, :]
        r = self.rho
        m[:, 0, 0] *= 1 - lh * la * r
        m[:, 0, 1] *= 1 + lh * r
        m[:, 1, 0] *= 1 + la * r
        m[:, 1, 1] *= 1 - r
        m = np.clip(m, 0, None)
        return m / m.sum(axis=(1, 2), keepdims=True)

    def outcome_probs(self, elo_diff) -> np.ndarray:
        m = self.score_matrices(elo_diff)
        home = np.tril(m, -1).sum(axis=(1, 2))
        draw = np.trace(m, axis1=1, axis2=2)
        away = np.triu(m, 1).sum(axis=(1, 2))
        return np.stack([home, draw, away], axis=1)

    def to_dict(self) -> dict:
        return asdict(self)


def _tau(x, y, lh, la, rho):
    t = np.ones_like(lh)
    t = np.where((x == 0) & (y == 0), 1 - lh * la * rho, t)
    t = np.where((x == 0) & (y == 1), 1 + lh * rho, t)
    t = np.where((x == 1) & (y == 0), 1 + la * rho, t)
    t = np.where((x == 1) & (y == 1), 1 - rho, t)
    return t


def fit_match_model(elo_diff, home_goals, away_goals) -> MatchModel:
    d = (np.asarray(elo_diff, dtype=float) / 100.0).reshape(-1, 1)
    hg, ag = np.asarray(home_goals), np.asarray(away_goals)
    rh = PoissonRegressor(alpha=0.0, max_iter=300).fit(d, hg)
    ra = PoissonRegressor(alpha=0.0, max_iter=300).fit(d, ag)
    model = MatchModel((float(rh.intercept_), float(rh.coef_[0])),
                       (float(ra.intercept_), float(ra.coef_[0])), 0.0)
    lh, la = model.rates(d[:, 0] * 100)

    def nll(rho):
        t = _tau(hg, ag, lh, la, rho)
        return np.inf if np.any(t <= 0) else -np.sum(np.log(t))

    model.rho = float(minimize_scalar(nll, bounds=(-0.2, 0.2), method="bounded").x)
    return model


def outcome_index(hg, ag) -> np.ndarray:
    hg, ag = np.asarray(hg), np.asarray(ag)
    return np.where(hg > ag, 0, np.where(hg == ag, 1, 2))


def rps(p, y) -> float:
    o = np.eye(3)[np.asarray(y)]
    cp, co = np.cumsum(p, 1)[:, :2], np.cumsum(o, 1)[:, :2]
    return float(np.mean(np.sum((cp - co) ** 2, axis=1) / 2))


def log_loss(p, y) -> float:
    return float(-np.mean(np.log(np.clip(p[np.arange(len(y)), np.asarray(y)], 1e-12, 1))))


def brier(p, y) -> float:
    o = np.eye(3)[np.asarray(y)]
    return float(np.mean(np.sum((p - o) ** 2, axis=1)))


def evaluate(model: MatchModel, train, test) -> dict:
    y = outcome_index(test.home_goals, test.away_goals)
    p = model.outcome_probs(test.d.to_numpy())
    base = np.bincount(outcome_index(train.home_goals, train.away_goals), minlength=3) / len(train)
    pb = np.tile(base, (len(test), 1))
    return {"n_test": int(len(test)), "rps": rps(p, y), "log_loss": log_loss(p, y),
            "brier": brier(p, y), "baseline_rps": rps(pb, y),
            "baseline_log_loss": log_loss(pb, y), "baseline_brier": brier(pb, y),
            "rho": model.rho}
```

- [ ] **Step 4: Run — expect PASS**

- [ ] **Step 5: Commit**

```bash
git add pipeline/touchline/models/match_model.py pipeline/tests/test_match_model.py
git commit -m "feat(pipeline): M2 Elo-Poisson match model with Dixon-Coles correction"
```

---

### Task 5: M3 — Season Monte Carlo projection

**Files:**
- Create: `pipeline/touchline/models/season_sim.py`
- Test: `pipeline/tests/test_season_sim.py`

**Interfaces:**
- Consumes: `MatchModel.score_matrices` output (Task 4)
- Produces:
  - `league_table(club_ids: list[int], played: DataFrame[home, away, home_goals, away_goals]) -> DataFrame[club_id, played, won, drawn, lost, gf, ga, gd, points, pos]` (sorted by pos)
  - `simulate_season(club_ids, played, remaining: DataFrame[home, away], score_mats: ndarray (len(remaining), G, G), n_sims=10000, seed=0, top_n=4, releg_n=3) -> DataFrame[club_id, exp_points, exp_pos, p_title, p_top4, p_releg]`

- [ ] **Step 1: Write the failing tests**

`pipeline/tests/test_season_sim.py`:
```python
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
```

- [ ] **Step 2: Run — expect FAIL**

- [ ] **Step 3: Implement**

`pipeline/touchline/models/season_sim.py`:
```python
"""M3 — Monte Carlo season projection over remaining fixtures."""
import numpy as np
import pandas as pd


def league_table(club_ids, played: pd.DataFrame) -> pd.DataFrame:
    t = pd.DataFrame({"club_id": list(club_ids)}).set_index("club_id")
    for c in ["played", "won", "drawn", "lost", "gf", "ga"]:
        t[c] = 0
    for h, a, hg, ag in played[["home", "away", "home_goals", "away_goals"]].itertuples(index=False):
        hg, ag = int(hg), int(ag)
        for club, gf, ga in ((h, hg, ag), (a, ag, hg)):
            if club not in t.index:
                continue
            t.loc[club, "played"] += 1
            t.loc[club, "gf"] += gf
            t.loc[club, "ga"] += ga
            t.loc[club, "won" if gf > ga else "drawn" if gf == ga else "lost"] += 1
    t["gd"] = t.gf - t.ga
    t["points"] = 3 * t.won + t.drawn
    t = t.reset_index().sort_values(["points", "gd", "gf"], ascending=False, kind="stable")
    t["pos"] = np.arange(1, len(t) + 1)
    return t.reset_index(drop=True)


def simulate_season(club_ids, played, remaining, score_mats, n_sims=10000, seed=0,
                    top_n=4, releg_n=3) -> pd.DataFrame:
    rng = np.random.default_rng(seed)
    clubs = list(club_ids)
    idx = {c: i for i, c in enumerate(clubs)}
    base = league_table(clubs, played).set_index("club_id").loc[clubs]
    n = len(clubs)
    pts = np.tile(base.points.to_numpy(float), (n_sims, 1))
    gd = np.tile(base.gd.to_numpy(float), (n_sims, 1))
    gf = np.tile(base.gf.to_numpy(float), (n_sims, 1))
    g = score_mats.shape[1] if len(score_mats) else 11
    for i, (h, a) in enumerate(remaining[["home", "away"]].itertuples(index=False)):
        if h not in idx or a not in idx:
            continue
        cum = score_mats[i].ravel().cumsum()
        k = np.searchsorted(cum, rng.random(n_sims) * cum[-1])
        hg, ag = k // g, k % g
        hi, ai = idx[h], idx[a]
        pts[:, hi] += np.where(hg > ag, 3, np.where(hg == ag, 1, 0))
        pts[:, ai] += np.where(ag > hg, 3, np.where(hg == ag, 1, 0))
        gd[:, hi] += hg - ag
        gd[:, ai] += ag - hg
        gf[:, hi] += hg
        gf[:, ai] += ag
    key = pts * 1e6 + (gd + 500) * 1e3 + gf + rng.random((n_sims, n)) * 0.1
    order = np.argsort(-key, axis=1)
    pos = np.empty_like(order)
    pos[np.arange(n_sims)[:, None], order] = np.arange(1, n + 1)
    return pd.DataFrame({
        "club_id": clubs,
        "exp_points": pts.mean(0),
        "exp_pos": pos.mean(0),
        "p_title": (pos == 1).mean(0),
        "p_top4": (pos <= top_n).mean(0),
        "p_releg": (pos > n - releg_n).mean(0),
    })
```

- [ ] **Step 4: Run — expect PASS**

- [ ] **Step 5: Commit**

```bash
git add pipeline/touchline/models/season_sim.py pipeline/tests/test_season_sim.py
git commit -m "feat(pipeline): M3 season Monte Carlo projection"
```

---

### Task 6: football-data.org client + club name mapping

**Files:**
- Create: `pipeline/touchline/ingest/football_data.py`, `pipeline/touchline/ingest/club_map.py`, `pipeline/touchline/ingest/club_overrides.json`
- Test: `pipeline/tests/test_football_data.py`, `pipeline/tests/test_club_map.py`

**Interfaces:**
- Produces:
  - `FootballData(token: str, client: httpx.Client | None=None, min_interval: float=6.5, retry_wait: float=60)`
    - `.season_teams(code: str, season: int) -> DataFrame[fd_id, name, short, crest]`
    - `.season_matches(code: str, season: int) -> DataFrame[fd_match_id, utc (datetime64[ns, UTC]), status, matchday, home_fd, away_fd, home_goals, away_goals]`
  - `norm_tokens(name) -> list[str]`, `similarity(a, b) -> float`
  - `map_clubs(fd_teams: DataFrame[fd_id, name, short, tm_league], tm_clubs: DataFrame[club_id, name, league], overrides: dict[int, int], threshold=0.7) -> dict[int, int]` (one-to-one)
  - `load_overrides() -> dict[int, int]`

- [ ] **Step 1: Write the failing tests**

`pipeline/tests/test_football_data.py`:
```python
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
```

`pipeline/tests/test_club_map.py`:
```python
import pandas as pd

from touchline.ingest.club_map import map_clubs, norm_tokens, similarity


def test_norm_tokens_strips_noise_and_accents():
    assert norm_tokens("Club Atlético de Madrid") == ["atletico", "madrid"]
    assert norm_tokens("1. FSV Mainz 05") == ["mainz"]


def test_similarity_prefers_exact_over_subset():
    assert similarity("Paris Saint-Germain FC", "Paris Saint-Germain") > \
        similarity("Paris Saint-Germain FC", "Paris FC")


def test_map_real_names_one_to_one():
    fd = pd.DataFrame([
        (524, "Paris Saint-Germain FC", "PSG", "FR1"), (1045, "Paris FC", "Paris FC", "FR1"),
        (98, "AC Milan", "Milan", "IT1"), (108, "FC Internazionale Milano", "Inter", "IT1"),
        (110, "SS Lazio", "Lazio", "IT1"), (5, "FC Bayern München", "Bayern", "L1"),
        (77, "Athletic Club", "Athletic", "ES1"), (1076, "Coventry City FC", "Coventry City", "GB1"),
    ], columns=["fd_id", "name", "short", "tm_league"])
    tm = pd.DataFrame([
        (583, "Paris Saint-Germain", "FR1"), (10004, "Paris FC", "FR1"),
        (5, "AC Milan", "IT1"), (46, "Inter Milan", "IT1"),
        (398, "Società Sportiva Lazio S.p.A.", "IT1"), (27, "Bayern Munich", "L1"),
        (621, "Athletic Bilbao", "ES1"), (603, "Cardiff City", "GB1"), (1003, "Leicester City", "GB1"),
    ], columns=["club_id", "name", "league"])
    m = map_clubs(fd, tm, overrides={})
    assert m == {524: 583, 1045: 10004, 98: 5, 108: 46, 110: 398, 5: 27, 77: 621}
    assert 1076 not in m  # Coventry is new to the dataset


def test_overrides_win():
    fd = pd.DataFrame([(1, "Foo", "Foo", "GB1")], columns=["fd_id", "name", "short", "tm_league"])
    tm = pd.DataFrame([(9, "Bar", "GB1")], columns=["club_id", "name", "league"])
    assert map_clubs(fd, tm, overrides={1: 9}) == {1: 9}
```

- [ ] **Step 2: Run — expect FAIL**

- [ ] **Step 3: Implement**

`pipeline/touchline/ingest/football_data.py`:
```python
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
```

`pipeline/touchline/ingest/club_map.py`:
```python
"""Map football-data.org teams to Transfermarkt club ids by fuzzy name matching."""
import json
import re
import unicodedata
from difflib import SequenceMatcher
from pathlib import Path

import pandas as pd

_STOP = {"fc", "afc", "cf", "sc", "ac", "ssc", "as", "us", "rc", "rcd", "cd", "ud", "sd", "ca",
         "club", "de", "del", "la", "football", "calcio", "futbol", "balompie", "sv", "tsg", "bc",
         "cfc", "fsv", "osc", "s", "p", "a"}
_OVERRIDES = Path(__file__).with_name("club_overrides.json")


def norm_tokens(name: str) -> list[str]:
    s = unicodedata.normalize("NFKD", str(name)).encode("ascii", "ignore").decode().lower()
    s = re.sub(r"[^a-z0-9 ]", " ", s)
    return [t for t in s.split() if t not in _STOP and not t.isdigit()]


def similarity(a: str, b: str) -> float:
    ta, tb = norm_tokens(a), norm_tokens(b)
    if not ta or not tb:
        return 0.0
    sa, sb = set(ta), set(tb)
    jac = len(sa & sb) / len(sa | sb)
    if sa <= sb or sb <= sa:
        return 0.9 + 0.1 * jac
    seq = SequenceMatcher(None, " ".join(sorted(ta)), " ".join(sorted(tb))).ratio()
    return max(jac, seq) * 0.9  # non-subset matches never outrank subset matches


def map_clubs(fd_teams: pd.DataFrame, tm_clubs: pd.DataFrame, overrides: dict[int, int],
              threshold: float = 0.7) -> dict[int, int]:
    present = set(fd_teams.fd_id)
    result = {int(k): int(v) for k, v in overrides.items() if int(k) in present}
    used = set(result.values())
    cands = []
    for t in fd_teams.itertuples(index=False):
        if t.fd_id in result:
            continue
        for c in tm_clubs[tm_clubs.league == t.tm_league].itertuples(index=False):
            s = max(similarity(t.name, c.name), similarity(t.short, c.name))
            if s >= threshold:
                cands.append((s, int(t.fd_id), int(c.club_id)))
    for _, fd, tm in sorted(cands, reverse=True):
        if fd in result or tm in used:
            continue
        result[fd] = tm
        used.add(tm)
    return result


def load_overrides() -> dict[int, int]:
    return {int(k): int(v) for k, v in json.loads(_OVERRIDES.read_text()).items()}
```

`pipeline/touchline/ingest/club_overrides.json`:
```json
{}
```

- [ ] **Step 4: Run — expect PASS.** If `test_map_real_names_one_to_one` fails on one pair, fix the scoring (not the test) — these are real names from both sources.

- [ ] **Step 5: Commit**

```bash
git add pipeline/touchline/ingest pipeline/tests/test_football_data.py pipeline/tests/test_club_map.py
git commit -m "feat(pipeline): football-data client and club name mapping"
```

---

### Task 7: Current-season club snapshot

**Files:**
- Create: `pipeline/touchline/season.py`
- Test: `pipeline/tests/test_season.py`

**Interfaces:**
- Consumes: `run_elo`, `EloParams`, `EloResult` (T3); `MatchModel` (T4); `league_table`, `simulate_season` (T5); `FootballData`, `map_clubs` (T6)
- Produces:
  - `league_snapshot(league: str, teams: DataFrame[fd_id, club_id, name, short, crest], matches: DataFrame (T6 shape + home, away club ids), ratings: dict[int, float], history: DataFrame[date, club_id, rating], params, model, today: pd.Timestamp, n_sims=10000) -> tuple[list[dict], list[dict]]` — (club records, fixture records), shapes as in `docs/bundle-schema.md` (Task 13)
  - `build_current_season(fd, tm_clubs, elo_res, params, model, season, overrides, today, n_sims=10000) -> tuple[list[dict], list[dict]]`
  - `offline_clubs(games, tm_clubs, elo_res, season) -> list[dict]` — last completed TM season final tables, `proj=None`, no fixtures

Club record: `{"id", "name", "crest", "league", "elo", "elo_change_30d", "form": [..last 5 "W"/"D"/"L", oldest→newest], "table": {"pos","played","points","gd","gf","ga"}, "proj": {"exp_points","exp_pos","p_title","p_top4","p_releg"} | None}`
Fixture record: `{"id", "league", "kickoff" (ISO UTC), "home", "away", "status", "score": [h, a] | None, "p": [home, draw, away], "xg": [lh, la]}` — fixtures within the last 7 days (finished, with pre-match probabilities) and next 14 days.

- [ ] **Step 1: Write the failing tests**

`pipeline/tests/test_season.py`:
```python
import numpy as np
import pandas as pd

from touchline.models.elo import EloParams
from touchline.models.match_model import MatchModel
from touchline.season import league_snapshot, offline_clubs
from touchline.models.elo import run_elo

MODEL = MatchModel((0.3, 0.25), (0.05, -0.25), -0.05)


def _teams():
    return pd.DataFrame({"fd_id": [57, 64, 1076], "club_id": [11, 31, -1076],
                         "name": ["Arsenal FC", "Liverpool FC", "Coventry City FC"],
                         "short": ["Arsenal", "Liverpool", "Coventry"], "crest": ["a", "b", "c"]})


def _matches(today):
    return pd.DataFrame({
        "fd_match_id": [1, 2, 3, 4],
        "utc": pd.to_datetime([today - pd.Timedelta(days=3), today - pd.Timedelta(days=60),
                               today + pd.Timedelta(days=2), today + pd.Timedelta(days=40)], utc=True),
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
```

- [ ] **Step 2: Run — expect FAIL**

- [ ] **Step 3: Implement**

`pipeline/touchline/season.py`:
```python
"""Current-season club snapshot: Elo continued into the live season, table, projections."""
import numpy as np
import pandas as pd

from touchline.config import LEAGUES
from touchline.ingest.club_map import map_clubs
from touchline.models.elo import EloParams, EloResult, run_elo
from touchline.models.match_model import MatchModel
from touchline.models.season_sim import league_table, simulate_season

_DONE = {"FINISHED", "AWARDED"}
_DEAD = {"CANCELLED"}


def _iso(ts: pd.Timestamp) -> str:
    return ts.tz_convert("UTC").strftime("%Y-%m-%dT%H:%M:%SZ")


def _form(club: int, played: pd.DataFrame) -> list[str]:
    rows = played[(played.home == club) | (played.away == club)].sort_values("utc").tail(5)
    out = []
    for h, hg, ag in rows[["home", "home_goals", "away_goals"]].itertuples(index=False):
        gf, ga = (hg, ag) if h == club else (ag, hg)
        out.append("W" if gf > ga else "D" if gf == ga else "L")
    return out


def _rating_at(history: pd.DataFrame, club: int, when: pd.Timestamp, default: float) -> float:
    h = history[(history.club_id == club) & (history.date <= when)]
    return float(h.rating.iloc[-1]) if len(h) else default


def league_snapshot(league, teams, matches, ratings, history, params: EloParams,
                    model: MatchModel, today: pd.Timestamp, n_sims: int = 10000):
    ids = [int(c) for c in teams.club_id]
    ratings = dict(ratings)
    known = [ratings[c] for c in ids if c in ratings]
    floor = float(np.percentile(known, 15)) if len(known) >= 5 else (min(known) if known else params.init)
    for c in ids:
        if c not in ratings:
            ratings[c] = floor
    start = {c: ratings[c] for c in ids}

    played = matches[matches.status.isin(_DONE)].copy()
    played["home_goals"] = played.home_goals.astype(int)
    played["away_goals"] = played.away_goals.astype(int)
    games = pd.DataFrame({"game_id": played.fd_match_id,
                          "date": played.utc.dt.tz_localize(None),
                          "competition_id": league, "home_club_id": played.home,
                          "away_club_id": played.away, "home_goals": played.home_goals,
                          "away_goals": played.away_goals})
    res = run_elo(games, params, start=start)
    now = res.ratings
    hist = pd.concat([history[history.club_id.isin(ids)], res.history]).sort_values("date")

    table = league_table(ids, played).set_index("club_id")
    remaining = matches[~matches.status.isin(_DONE | _DEAD)].reset_index(drop=True)
    d_rem = np.array([now[h] - now[a] for h, a in zip(remaining.home, remaining.away)], float)
    mats = model.score_matrices(d_rem) if len(remaining) else np.zeros((0, 11, 11))
    sim = simulate_season(ids, played, remaining, mats, n_sims=n_sims).set_index("club_id")

    name = dict(zip(teams.club_id, teams.short))
    crest = dict(zip(teams.club_id, teams.crest))
    month_ago = (today - pd.Timedelta(days=30)).tz_localize(None)
    clubs = []
    for c in ids:
        t, s = table.loc[c], sim.loc[c]
        clubs.append({
            "id": c, "name": name[c], "crest": crest[c], "league": league,
            "elo": round(now[c], 1),
            "elo_change_30d": round(now[c] - _rating_at(hist, c, month_ago, start[c]), 1),
            "form": _form(c, played),
            "table": {k: int(t[k]) for k in ["pos", "played", "points", "gd", "gf", "ga"]},
            "proj": {"exp_points": round(float(s.exp_points), 1),
                     "exp_pos": round(float(s.exp_pos), 2),
                     "p_title": float(s.p_title), "p_top4": float(s.p_top4),
                     "p_releg": float(s.p_releg)},
        })

    fixtures = []
    pre = res.pre.set_index("game_id")
    recent = played[played.utc >= today - pd.Timedelta(days=7)]
    for r in recent.itertuples(index=False):
        d = pre.loc[r.fd_match_id, "elo_home"] - pre.loc[r.fd_match_id, "elo_away"]
        fixtures.append(_fixture(r, league, model, d, [int(r.home_goals), int(r.away_goals)]))
    soon = remaining[(remaining.utc >= today) & (remaining.utc <= today + pd.Timedelta(days=14))]
    for r in soon.itertuples(index=False):
        fixtures.append(_fixture(r, league, model, now[r.home] - now[r.away], None))
    fixtures.sort(key=lambda f: f["kickoff"])
    return clubs, fixtures


def _fixture(r, league, model, d, score):
    p = model.outcome_probs(np.array([d]))[0]
    lh, la = model.rates(np.array([d]))
    return {"id": int(r.fd_match_id), "league": league, "kickoff": _iso(r.utc),
            "home": int(r.home), "away": int(r.away), "status": r.status, "score": score,
            "p": [float(x) for x in p], "xg": [round(float(lh[0]), 2), round(float(la[0]), 2)]}


def build_current_season(fd, tm_clubs, elo_res: EloResult, params, model, season, overrides,
                         today: pd.Timestamp, n_sims: int = 10000):
    clubs, fixtures = [], []
    for league, (code, _) in LEAGUES.items():
        teams = fd.season_teams(code, season)
        matches = fd.season_matches(code, season)
        mapping = map_clubs(teams.assign(tm_league=league), tm_clubs, overrides)
        teams["club_id"] = [mapping.get(int(f), -int(f)) for f in teams.fd_id]
        idmap = dict(zip(teams.fd_id, teams.club_id))
        matches["home"] = matches.home_fd.map(idmap)
        matches["away"] = matches.away_fd.map(idmap)
        c, f = league_snapshot(league, teams, matches, elo_res.ratings, elo_res.history,
                               params, model, today, n_sims)
        clubs += c
        fixtures += f
    return clubs, fixtures


def offline_clubs(games, tm_clubs, elo_res: EloResult, season: int) -> list[dict]:
    clubs = []
    names = dict(zip(tm_clubs.club_id, tm_clubs.name))
    for league in LEAGUES:
        lg = games[(games.season == season) & (games.competition_id == league)]
        if lg.empty:
            continue
        played = lg.rename(columns={"home_club_id": "home", "away_club_id": "away",
                                    "date": "utc"})
        ids = sorted(set(played.home) | set(played.away))
        table = league_table(ids, played).set_index("club_id")
        for c in ids:
            t = table.loc[c]
            clubs.append({"id": int(c), "name": names.get(c, str(c)), "crest": None,
                          "league": league, "elo": round(elo_res.ratings.get(c, 1500.0), 1),
                          "elo_change_30d": 0.0, "form": _form(c, played),
                          "table": {k: int(t[k]) for k in ["pos", "played", "points", "gd", "gf", "ga"]},
                          "proj": None})
    return clubs
```

- [ ] **Step 4: Run — expect PASS**

- [ ] **Step 5: Commit**

```bash
git add pipeline/touchline/season.py pipeline/tests/test_season.py
git commit -m "feat(pipeline): current-season club snapshot with live Elo and projections"
```

---

### Task 8: Player features

**Files:**
- Create: `pipeline/touchline/features/__init__.py` (empty), `pipeline/touchline/features/players.py`
- Test: `pipeline/tests/test_player_features.py`

**Interfaces:**
- Consumes: Task 2 tables, Elo `history` (T3)
- Produces:
  - `POS_GROUPS = ["Attack", "Midfield", "Defender", "Goalkeeper"]`
  - `season_ref_date(season: int) -> pd.Timestamp` (July 1 after the season)
  - `enrich_appearances(apps, games) -> DataFrame` — apps + season, is_league, is_home (1/0/0.5), opp_name, sorted by player/date
  - `season_stats(eapps, games) -> DataFrame[player_id, season, apps, minutes, goals, assists, yellow, red, league_apps, league_minutes, club_id, league, team_games, ga90, g90, a90, yellow90, minutes_share]`
  - `add_prev_season(stats) -> stats + prev_minutes, prev_ga90`
  - `build_player_rows(stats, players, valuations, history, min_league_minutes=450, with_target=True) -> DataFrame` adding age, position, sub_position, foot, height, club_elo, and (if with_target) target_value (valuation nearest the ref date within 90 days, rows without target dropped)

- [ ] **Step 1: Write the failing tests**

`pipeline/tests/test_player_features.py`:
```python
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
    vals = pd.DataFrame({"player_id": [7, 7], "date": pd.to_datetime(["2025-06-20", "2023-01-01"]),
                         "value": [5_000_000, 1_000_000]})
    hist = pd.DataFrame({"date": pd.to_datetime(["2025-05-01"]), "club_id": [1], "rating": [1600.0]})
    rows = build_player_rows(stats, players, vals, hist, min_league_minutes=100)
    r = rows[rows.season == 2024].iloc[0]
    assert r.target_value == 5_000_000 and np.isclose(r.age, 25.0, atol=0.01)
    assert r.club_elo == 1600.0
    assert season_ref_date(2024) == pd.Timestamp("2025-07-01")


def test_missing_player_fields_do_not_crash():
    stats = season_stats(enrich_appearances(_apps(), _games()), _games())
    players = pd.DataFrame({"player_id": [7], "dob": [pd.NaT], "position": [None],
                            "sub_position": [None], "foot": [None], "height": [np.nan]})
    rows = build_player_rows(add_prev_season(stats), players,
                             pd.DataFrame(columns=["player_id", "date", "value"]).astype(
                                 {"player_id": int, "date": "datetime64[ns]", "value": float}),
                             pd.DataFrame({"date": pd.to_datetime([]), "club_id": pd.Series([], dtype=int),
                                           "rating": pd.Series([], dtype=float)}),
                             min_league_minutes=100, with_target=False)
    assert len(rows) == 1 and np.isnan(rows.iloc[0].age)
```

- [ ] **Step 2: Run — expect FAIL**

- [ ] **Step 3: Implement**

`pipeline/touchline/features/players.py`:
```python
"""Per-appearance enrichment and per-(player, season) feature tables."""
import numpy as np
import pandas as pd

from touchline.config import LEAGUES

POS_GROUPS = ["Attack", "Midfield", "Defender", "Goalkeeper"]
_LEAGUES = list(LEAGUES)


def season_ref_date(season: int) -> pd.Timestamp:
    return pd.Timestamp(int(season) + 1, 7, 1)


def _season_from_date(d: pd.Series) -> pd.Series:
    return pd.Series(np.where(d.dt.month >= 7, d.dt.year, d.dt.year - 1), index=d.index)


def enrich_appearances(apps: pd.DataFrame, games: pd.DataFrame) -> pd.DataFrame:
    g = games[["game_id", "season", "home_club_id", "away_club_id", "home_club_name",
               "away_club_name"]]
    e = apps.merge(g, on="game_id", how="left")
    e["season"] = e["season"].fillna(_season_from_date(e["date"])).astype(int)
    e["is_league"] = e["competition_id"].isin(_LEAGUES)
    known = e["home_club_id"].notna()
    home = known & (e["club_id"] == e["home_club_id"])
    e["is_home"] = np.where(~known, 0.5, home.astype(float))
    e["opp_name"] = np.where(home, e["away_club_name"], e["home_club_name"])
    e.loc[~known, "opp_name"] = None
    return e.sort_values(["player_id", "date", "game_id"]).reset_index(drop=True)


def season_stats(eapps: pd.DataFrame, games: pd.DataFrame) -> pd.DataFrame:
    keys = ["player_id", "season"]
    agg = eapps.groupby(keys).agg(apps=("game_id", "size"), minutes=("minutes", "sum"),
                                  goals=("goals", "sum"), assists=("assists", "sum"),
                                  yellow=("yellow_cards", "sum"),
                                  red=("red_cards", "sum")).reset_index()
    lg = eapps[eapps.is_league]
    lmin = lg.groupby(keys).agg(league_apps=("game_id", "size"),
                                league_minutes=("minutes", "sum")).reset_index()
    main = (lg.groupby(keys + ["club_id", "competition_id"])["minutes"].sum().reset_index()
              .sort_values("minutes", ascending=False).drop_duplicates(keys)
              .rename(columns={"competition_id": "league"})[keys + ["club_id", "league"]])
    lgames = games[games.competition_id.isin(_LEAGUES)]
    team_games = (pd.concat([lgames[["season", "home_club_id"]].rename(columns={"home_club_id": "club_id"}),
                             lgames[["season", "away_club_id"]].rename(columns={"away_club_id": "club_id"})])
                    .value_counts().rename("team_games").reset_index())
    out = (agg.merge(lmin, on=keys, how="left").merge(main, on=keys, how="left")
              .merge(team_games, on=["season", "club_id"], how="left"))
    out[["league_apps", "league_minutes"]] = out[["league_apps", "league_minutes"]].fillna(0)
    m90 = out["minutes"].clip(lower=1) / 90
    out["ga90"] = (out.goals + out.assists) / m90
    out["g90"] = out.goals / m90
    out["a90"] = out.assists / m90
    out["yellow90"] = out.yellow / m90
    out["minutes_share"] = out.league_minutes / (out.team_games * 90)
    return out


def add_prev_season(stats: pd.DataFrame) -> pd.DataFrame:
    prev = stats[["player_id", "season", "minutes", "ga90"]].copy()
    prev["season"] += 1
    prev = prev.rename(columns={"minutes": "prev_minutes", "ga90": "prev_ga90"})
    return stats.merge(prev, on=["player_id", "season"], how="left")


def build_player_rows(stats, players, valuations, history, min_league_minutes: int = 450,
                      with_target: bool = True) -> pd.DataFrame:
    rows = stats[stats.league_minutes >= min_league_minutes].copy()
    rows["club_id"] = rows["club_id"].astype("int64")
    rows["ref"] = rows["season"].map(season_ref_date).astype("datetime64[ns]")
    meta = players[["player_id", "dob", "position", "sub_position", "foot", "height"]]
    rows = rows.merge(meta, on="player_id", how="left")
    rows["age"] = (rows["ref"] - rows["dob"]).dt.days / 365.25

    h = history.rename(columns={"date": "ref", "rating": "club_elo"}).copy()
    h["ref"] = h["ref"].astype("datetime64[ns]")
    h["club_id"] = h["club_id"].astype("int64")
    rows = pd.merge_asof(rows.sort_values("ref"), h.sort_values("ref"), on="ref", by="club_id",
                         direction="backward")
    if with_target:
        v = valuations.rename(columns={"value": "target_value"}).copy()
        v["ref"] = v["date"].astype("datetime64[ns]")
        v["player_id"] = v["player_id"].astype(rows["player_id"].dtype)
        rows = pd.merge_asof(rows.sort_values("ref"), v[["player_id", "ref", "target_value"]]
                             .sort_values("ref"), on="ref", by="player_id", direction="nearest",
                             tolerance=pd.Timedelta(days=90))
        rows = rows[rows.target_value > 0]
    return rows.drop(columns=["ref"]).reset_index(drop=True)
```

- [ ] **Step 4: Run — expect PASS**

- [ ] **Step 5: Commit**

```bash
git add pipeline/touchline/features pipeline/tests/test_player_features.py
git commit -m "feat(pipeline): player season features and valuation rows"
```

---

### Task 9: M4 — Player valuator (LightGBM + SHAP contributions)

**Files:**
- Create: `pipeline/touchline/models/valuator.py`
- Test: `pipeline/tests/test_valuator.py`

**Interfaces:**
- Consumes: `build_player_rows` output (T8)
- Produces:
  - `NUM`, `CAT`, `FRIENDLY: dict[str, str]` (feature → plain-English label)
  - `Valuator(model, categories)` with `.predict(df) -> ndarray (EUR)`, `.explain(df, top=4) -> list[list[dict]]` each `{"f": friendly label, "effect_pct": float}`
  - `run_valuator(rows, test_season, seed=42) -> tuple[Valuator, dict]` — metrics: test_season, n_test, train_seasons_max, mae_eur, mdape, r2_log, baseline_mae_eur, baseline_mdape, best_iter. The returned model is trained on seasons < test_season (so test-season predictions are out-of-sample "fair value").
  - `baseline_predict(train, test) -> ndarray (EUR)`

- [ ] **Step 1: Write the failing tests**

`pipeline/tests/test_valuator.py`:
```python
import numpy as np
import pandas as pd

from touchline.models.valuator import CAT, NUM, baseline_predict, run_valuator


def _rows(n=3000, seed=0):
    rng = np.random.default_rng(seed)
    df = pd.DataFrame({
        "player_id": np.arange(n), "season": rng.integers(2018, 2026, n),
        "age": rng.uniform(18, 34, n), "minutes": rng.uniform(450, 4000, n),
        "apps": rng.integers(5, 50, n), "goals": rng.integers(0, 25, n),
        "assists": rng.integers(0, 15, n), "minutes_share": rng.uniform(0.1, 1, n),
        "yellow": rng.integers(0, 10, n), "prev_minutes": rng.uniform(0, 4000, n),
        "club_elo": rng.normal(1600, 120, n), "height": rng.normal(182, 6, n),
        "position": rng.choice(["Attack", "Midfield", "Defender", "Goalkeeper"], n),
        "sub_position": rng.choice(["Centre-Forward", "Central Midfield", "Centre-Back"], n),
        "league": rng.choice(["GB1", "ES1"], n), "foot": rng.choice(["left", "right"], n)})
    m90 = df.minutes / 90
    df["ga90"] = (df.goals + df.assists) / m90
    df["g90"], df["a90"] = df.goals / m90, df.assists / m90
    df["prev_ga90"] = df.ga90 * rng.uniform(0.7, 1.3, n)
    df.loc[::17, "prev_ga90"] = np.nan  # missing values must be tolerated
    log_v = (15 + 1.2 * df.ga90 + 0.004 * (df.club_elo - 1600) - 0.05 * (df.age - 25) ** 2
             + 0.4 * df.minutes_share + 0.3 * (df.league == "GB1") + rng.normal(0, 0.3, n))
    df["target_value"] = np.exp(log_v)
    return df


def test_run_valuator_beats_baseline_without_leakage():
    rows = _rows()
    model, m = run_valuator(rows, test_season=2025)
    assert m["train_seasons_max"] == 2024 and m["test_season"] == 2025
    assert m["mae_eur"] < m["baseline_mae_eur"]
    assert set(NUM + CAT) <= set(rows.columns)


def test_explain_returns_top_contributions():
    rows = _rows()
    model, _ = run_valuator(rows, test_season=2025)
    test = rows[rows.season == 2025].head(3)
    preds = model.predict(test)
    why = model.explain(test, top=3)
    assert preds.shape == (3,) and (preds > 0).all()
    assert len(why) == 3 and len(why[0]) == 3 and {"f", "effect_pct"} <= set(why[0][0])


def test_baseline_falls_back_to_global_median():
    train = _rows(200)
    test = train.head(2).assign(league="XX")
    assert (baseline_predict(train, test) > 0).all()
```

- [ ] **Step 2: Run — expect FAIL**

- [ ] **Step 3: Implement**

`pipeline/touchline/models/valuator.py`:
```python
"""M4 — fair market value from performance, with per-player TreeSHAP explanations."""
from dataclasses import dataclass

import lightgbm as lgb
import numpy as np
import pandas as pd

NUM = ["age", "minutes", "apps", "goals", "assists", "ga90", "g90", "a90", "minutes_share",
       "yellow", "prev_minutes", "prev_ga90", "club_elo", "height"]
CAT = ["position", "sub_position", "league", "foot"]
FRIENDLY = {
    "age": "Age", "minutes": "Minutes played", "apps": "Appearances", "goals": "Goals",
    "assists": "Assists", "ga90": "Goal involvements per 90", "g90": "Goals per 90",
    "a90": "Assists per 90", "minutes_share": "Share of league minutes", "yellow": "Yellow cards",
    "prev_minutes": "Minutes last season", "prev_ga90": "Output last season",
    "club_elo": "Club strength", "height": "Height", "position": "Position",
    "sub_position": "Role", "league": "League", "foot": "Preferred foot",
}
_PARAMS = dict(objective="regression", learning_rate=0.05, num_leaves=31, min_child_samples=40,
               colsample_bytree=0.8, subsample=0.8, subsample_freq=1, verbose=-1)


@dataclass
class Valuator:
    model: lgb.LGBMRegressor
    categories: dict

    def _x(self, df: pd.DataFrame) -> pd.DataFrame:
        x = df[NUM + CAT].copy()
        for c in NUM:
            x[c] = pd.to_numeric(x[c], errors="coerce").astype(float)
        for c in CAT:
            x[c] = pd.Categorical(x[c], categories=self.categories[c])
        return x

    def predict(self, df: pd.DataFrame) -> np.ndarray:
        return np.exp(self.model.predict(self._x(df)))

    def explain(self, df: pd.DataFrame, top: int = 4) -> list[list[dict]]:
        contrib = self.model.predict(self._x(df), pred_contrib=True)[:, :-1]  # drop bias column
        out = []
        for row in contrib:
            order = np.argsort(-np.abs(row))[:top]
            out.append([{"f": FRIENDLY[(NUM + CAT)[i]], "effect_pct": float(np.expm1(row[i]))}
                        for i in order])
        return out


def _band(age):
    return pd.cut(age, [0, 21, 24, 27, 30, 50], labels=False)


def baseline_predict(train: pd.DataFrame, test: pd.DataFrame) -> np.ndarray:
    keys = ["band", "position", "league"]
    tr = train.assign(band=_band(train.age), logv=np.log(train.target_value))
    med = tr.groupby(keys, dropna=False)["logv"].median().rename("m").reset_index()
    te = test.assign(band=_band(test.age)).merge(med, on=keys, how="left")
    return np.exp(te["m"].fillna(tr.logv.median()).to_numpy())


def _metrics(y, p) -> dict:
    ape = np.abs(p - y) / y
    return {"mae_eur": float(np.mean(np.abs(p - y))), "mdape": float(np.median(ape))}


def run_valuator(rows: pd.DataFrame, test_season: int, seed: int = 42) -> tuple[Valuator, dict]:
    categories = {c: sorted(rows[c].dropna().unique().tolist()) for c in CAT}
    train = rows[rows.season <= test_season - 2]
    val = rows[rows.season == test_season - 1]
    test = rows[rows.season == test_season]
    assert train.season.max() < test_season and val.season.max() < test_season

    probe = Valuator(lgb.LGBMRegressor(n_estimators=3000, random_state=seed, **_PARAMS), categories)
    probe.model.fit(probe._x(train), np.log(train.target_value),
                    eval_set=[(probe._x(val), np.log(val.target_value))],
                    callbacks=[lgb.early_stopping(100, verbose=False)])
    best = int(probe.model.best_iteration_ or 500)

    fit_rows = pd.concat([train, val])
    final = Valuator(lgb.LGBMRegressor(n_estimators=best, random_state=seed, **_PARAMS), categories)
    final.model.fit(final._x(fit_rows), np.log(fit_rows.target_value))

    y = test.target_value.to_numpy()
    p = final.predict(test)
    b = baseline_predict(fit_rows, test)
    m, mb = _metrics(y, p), _metrics(y, b)
    r2 = 1 - np.sum((np.log(y) - np.log(p)) ** 2) / np.sum((np.log(y) - np.log(y).mean()) ** 2)
    return final, {"test_season": test_season, "n_test": int(len(test)),
                   "train_seasons_max": int(fit_rows.season.max()), "best_iter": best,
                   **m, "r2_log": float(r2),
                   "baseline_mae_eur": mb["mae_eur"], "baseline_mdape": mb["mdape"]}
```

- [ ] **Step 4: Run — expect PASS**

- [ ] **Step 5: Commit**

```bash
git add pipeline/touchline/models/valuator.py pipeline/tests/test_valuator.py
git commit -m "feat(pipeline): M4 LightGBM player valuator with SHAP explanations"
```

---

### Task 10: M5 — Form forecast (GRU vs Poisson baselines)

**Files:**
- Create: `pipeline/touchline/models/form.py`
- Test: `pipeline/tests/test_form.py`

**Interfaces:**
- Consumes: `enrich_appearances` output (T8), Elo `pre` (T3), players table (T2), `POS_GROUPS` (T8)
- Produces:
  - `SEQ_FEATS`, `L = 10`, `H = 5`
  - `appearance_features(eapps, pre) -> DataFrame` (adds m90, rest, own_elo, opp_elo, ga, yellow, red)
  - `SeqData(seq, static, y, end_date, player_id)` with `.subset(mask) -> SeqData`
  - `build_sequences(feats, players, pool_ids, stride=5) -> SeqData`
  - `latest_windows(feats, players, ids) -> SeqData` (y = NaN; one window per player with ≥ L apps)
  - `FormForecaster` with `.predict(data: SeqData) -> ndarray` (expected G+A over next H apps); `.kind` in {"gru", "poisson_glm"}
  - `run_form(data: SeqData, val_start: pd.Timestamp, test_start: pd.Timestamp, epochs=15, seed=0) -> tuple[FormForecaster, dict]` — trains GRU and Poisson GLM, picks the better on validation deviance; metrics: n_train, n_test, gru_poisson_deviance, glm_poisson_deviance, naive_poisson_deviance, gru_mae, glm_mae, naive_mae, chosen, poisson_deviance (chosen), baseline_poisson_deviance (naive)

- [ ] **Step 1: Write the failing tests**

`pipeline/tests/test_form.py`:
```python
import numpy as np
import pandas as pd

from touchline.models.form import (L, SEQ_FEATS, SeqData, appearance_features, build_sequences,
                                   latest_windows, run_form)


def _feats(n_players=60, n_apps=60, seed=0):
    rng = np.random.default_rng(seed)
    rows = []
    for pid in range(n_players):
        skill = rng.uniform(0.0, 0.8)
        d = pd.Timestamp("2022-08-01")
        for i in range(n_apps):
            g = rng.poisson(skill * 0.6)
            a = rng.poisson(skill * 0.4)
            rows.append({"game_id": pid * 1000 + i, "player_id": pid, "club_id": 1, "date": d,
                         "competition_id": "GB1", "goals": g, "assists": a, "minutes": 90,
                         "yellow_cards": 0, "red_cards": 0, "season": 2022, "is_league": True,
                         "is_home": float(i % 2), "home_club_id": 1, "away_club_id": 2,
                         "opp_name": "X"})
            d += pd.Timedelta(days=21)
    eapps = pd.DataFrame(rows)
    pre = pd.DataFrame({"game_id": eapps.game_id, "elo_home": 1550.0, "elo_away": 1500.0})
    players = pd.DataFrame({"player_id": range(n_players), "position": "Attack",
                            "dob": pd.Timestamp("1998-01-01")})
    return appearance_features(eapps, pre), players


def test_build_sequences_shapes_and_targets():
    feats, players = _feats(n_players=2, n_apps=30)
    data = build_sequences(feats, players, pool_ids={0, 1}, stride=5)
    assert data.seq.shape[1:] == (L, len(SEQ_FEATS))
    first = feats[feats.player_id == data.player_id[0]]
    assert data.y[0] == first.ga.iloc[L:L + 5].sum()
    assert data.end_date[0] == first.date.iloc[L - 1]


def test_latest_windows_skips_short_histories():
    feats, players = _feats(n_players=2, n_apps=30)
    short = feats[(feats.player_id == 1)].head(4)
    feats2 = pd.concat([feats[feats.player_id == 0], short])
    w = latest_windows(feats2, players, ids=[0, 1])
    assert list(w.player_id) == [0]


def test_run_form_trains_and_reports_without_leakage():
    feats, players = _feats()
    data = build_sequences(feats, players, pool_ids=set(range(60)), stride=3)
    val_start, test_start = pd.Timestamp("2024-06-01"), pd.Timestamp("2025-01-01")
    model, m = run_form(data, val_start, test_start, epochs=3)
    train_end = data.end_date[data.end_date < val_start].max()
    assert pd.Timestamp(train_end) < val_start
    assert m["chosen"] in {"gru", "poisson_glm"} and m["n_test"] > 0
    assert m["poisson_deviance"] < m["baseline_poisson_deviance"] * 1.2
    preds = model.predict(data.subset(data.end_date >= test_start))
    assert (preds > 0).all()
```

- [ ] **Step 2: Run — expect FAIL**

- [ ] **Step 3: Implement**

`pipeline/touchline/models/form.py`:
```python
"""M5 — goal-involvement forecast over the next 5 appearances.

A GRU reads the last 10 appearances (minutes, goals, assists, cards, rest, venue, club and
opponent strength) plus static position/age, and outputs a Poisson rate. It is compared on
validation with a Poisson GLM on rolling averages; the better one is used for the app."""
from dataclasses import dataclass

import numpy as np
import pandas as pd
import torch
from sklearn.linear_model import PoissonRegressor
from sklearn.metrics import mean_absolute_error, mean_poisson_deviance
from torch import nn

from touchline.features.players import POS_GROUPS

SEQ_FEATS = ["m90", "goals", "assists", "yellow", "red", "rest", "is_home", "own_elo", "opp_elo"]
L, H = 10, 5
_GA = (SEQ_FEATS.index("goals"), SEQ_FEATS.index("assists"))


def appearance_features(eapps: pd.DataFrame, pre: pd.DataFrame) -> pd.DataFrame:
    df = eapps.merge(pre, on="game_id", how="left")
    home = df["is_home"] >= 1
    df["own_elo"] = np.where(home, df["elo_home"], df["elo_away"])
    df["opp_elo"] = np.where(home, df["elo_away"], df["elo_home"])
    df[["own_elo", "opp_elo"]] = (df[["own_elo", "opp_elo"]].fillna(1500.0) - 1500.0) / 200.0
    df["m90"] = df["minutes"] / 90.0
    df["rest"] = df.groupby("player_id")["date"].diff().dt.days.fillna(30).clip(0, 30) / 30.0
    df["ga"] = df["goals"] + df["assists"]
    df["yellow"] = df["yellow_cards"]
    df["red"] = df["red_cards"]
    return df.sort_values(["player_id", "date", "game_id"]).reset_index(drop=True)


@dataclass
class SeqData:
    seq: np.ndarray
    static: np.ndarray
    y: np.ndarray
    end_date: np.ndarray
    player_id: np.ndarray

    def subset(self, mask) -> "SeqData":
        mask = np.asarray(mask)
        return SeqData(self.seq[mask], self.static[mask], self.y[mask], self.end_date[mask],
                       self.player_id[mask])

    def __len__(self):
        return len(self.y)


def _static(position, dob, when) -> list[float]:
    age = (pd.Timestamp(when) - dob).days / 365.25 if pd.notna(dob) else 26.0
    return [float(position == p) for p in POS_GROUPS] + [(age - 26.0) / 5.0]


def _collect(feats, players, ids, windows_fn) -> SeqData:
    meta = players.set_index("player_id")[["position", "dob"]]
    seqs, stats, ys, ends, pids = [], [], [], [], []
    for pid, g in feats[feats.player_id.isin(ids)].groupby("player_id", sort=True):
        x = g[SEQ_FEATS].to_numpy(np.float32)
        ga = g["ga"].to_numpy(np.float32)
        dates = g["date"].to_numpy()
        pos = meta.position.get(pid) if pid in meta.index else None
        dob = meta.dob.get(pid) if pid in meta.index else pd.NaT
        for e, target in windows_fn(len(g), ga):
            seqs.append(x[e - L:e])
            stats.append(_static(pos, dob, dates[e - 1]))
            ys.append(target)
            ends.append(dates[e - 1])
            pids.append(pid)
    n_s = len(POS_GROUPS) + 1
    return SeqData(np.asarray(seqs, np.float32).reshape(-1, L, len(SEQ_FEATS)),
                   np.asarray(stats, np.float32).reshape(-1, n_s), np.asarray(ys, np.float32),
                   np.asarray(ends, dtype="datetime64[ns]"), np.asarray(pids))


def build_sequences(feats, players, pool_ids, stride: int = 5) -> SeqData:
    def windows(n, ga):
        return [(e, float(ga[e:e + H].sum())) for e in range(L, n - H + 1, stride)]
    return _collect(feats, players, pool_ids, windows)


def latest_windows(feats, players, ids) -> SeqData:
    def windows(n, ga):
        return [(n, np.nan)] if n >= L else []
    return _collect(feats, players, ids, windows)


class FormGRU(nn.Module):
    def __init__(self, n_feat: int, n_static: int, hidden: int = 32):
        super().__init__()
        self.gru = nn.GRU(n_feat, hidden, batch_first=True)
        self.head = nn.Sequential(nn.Linear(hidden + n_static, 32), nn.ReLU(), nn.Linear(32, 1))

    def forward(self, seq, static):
        _, h = self.gru(seq)
        return self.head(torch.cat([h[-1], static], dim=1)).squeeze(1)  # log-rate


def _glm_x(d: SeqData) -> np.ndarray:
    ga = d.seq[:, :, _GA[0]] + d.seq[:, :, _GA[1]]
    return np.column_stack([ga.mean(1), ga[:, -5:].mean(1), d.seq[:, :, 0].mean(1), d.static])


@dataclass
class FormForecaster:
    kind: str
    gru: FormGRU | None = None
    glm: PoissonRegressor | None = None

    def predict(self, d: SeqData) -> np.ndarray:
        if len(d) == 0:
            return np.zeros(0)
        if self.kind == "gru":
            self.gru.eval()
            with torch.no_grad():
                out = self.gru(torch.from_numpy(d.seq), torch.from_numpy(d.static))
            return np.exp(out.numpy()).astype(float)
        return self.glm.predict(_glm_x(d))


def _naive(d: SeqData) -> np.ndarray:
    ga = d.seq[:, :, _GA[0]] + d.seq[:, :, _GA[1]]
    return np.clip(ga.mean(1) * H, 1e-3, None)


def _train_gru(train: SeqData, val: SeqData, epochs, seed, batch=512, patience=2) -> FormGRU:
    torch.manual_seed(seed)
    model = FormGRU(train.seq.shape[2], train.static.shape[1])
    opt = torch.optim.Adam(model.parameters(), lr=1e-3)
    loss_fn = nn.PoissonNLLLoss(log_input=True)
    tx, ts, ty = map(torch.from_numpy, (train.seq, train.static, train.y))
    vx, vs, vy = map(torch.from_numpy, (val.seq, val.static, val.y))
    best, best_state, bad = np.inf, None, 0
    gen = torch.Generator().manual_seed(seed)
    for _ in range(epochs):
        model.train()
        perm = torch.randperm(len(ty), generator=gen)
        for i in range(0, len(ty), batch):
            idx = perm[i:i + batch]
            opt.zero_grad()
            loss = loss_fn(model(tx[idx], ts[idx]), ty[idx])
            loss.backward()
            opt.step()
        model.eval()
        with torch.no_grad():
            v = float(loss_fn(model(vx, vs), vy))
        if v < best - 1e-5:
            best, best_state, bad = v, {k: t.clone() for k, t in model.state_dict().items()}, 0
        else:
            bad += 1
            if bad >= patience:
                break
    model.load_state_dict(best_state)
    return model


def run_form(data: SeqData, val_start, test_start, epochs: int = 15,
             seed: int = 0) -> tuple[FormForecaster, dict]:
    vs, ts = np.datetime64(val_start, "ns"), np.datetime64(test_start, "ns")
    train = data.subset(data.end_date < vs)
    val = data.subset((data.end_date >= vs) & (data.end_date < ts))
    test = data.subset(data.end_date >= ts)
    assert train.end_date.max() < vs and val.end_date.max() < ts

    gru = FormForecaster("gru", gru=_train_gru(train, val, epochs, seed))
    glm = FormForecaster("poisson_glm",
                         glm=PoissonRegressor(alpha=1e-4, max_iter=500).fit(_glm_x(train), train.y))

    def dev(model_pred, d):
        return float(mean_poisson_deviance(d.y, np.clip(model_pred, 1e-6, None)))

    chosen = gru if dev(gru.predict(val), val) <= dev(glm.predict(val), val) else glm
    pg, pl, pn = gru.predict(test), glm.predict(test), _naive(test)
    metrics = {"n_train": len(train), "n_val": len(val), "n_test": len(test),
               "gru_poisson_deviance": dev(pg, test), "glm_poisson_deviance": dev(pl, test),
               "naive_poisson_deviance": dev(pn, test),
               "gru_mae": float(mean_absolute_error(test.y, pg)),
               "glm_mae": float(mean_absolute_error(test.y, pl)),
               "naive_mae": float(mean_absolute_error(test.y, pn)),
               "chosen": chosen.kind}
    metrics["poisson_deviance"] = metrics[f"{'gru' if chosen.kind == 'gru' else 'glm'}_poisson_deviance"]
    metrics["baseline_poisson_deviance"] = metrics["naive_poisson_deviance"]
    return chosen, metrics
```

- [ ] **Step 4: Run — expect PASS** (`.venv/Scripts/python -m pytest tests/test_form.py -v`; takes ~10 s)

- [ ] **Step 5: Commit**

```bash
git add pipeline/touchline/models/form.py pipeline/tests/test_form.py
git commit -m "feat(pipeline): M5 GRU form forecast with Poisson baselines"
```

---

### Task 11: M6 — Workload index

**Files:**
- Create: `pipeline/touchline/models/workload.py`
- Test: `pipeline/tests/test_workload.py`

**Interfaces:**
- Consumes: appearances with player_id, date, minutes (T2/T8); players with player_id, dob
- Produces: `workload_table(apps, players, season_start: pd.Timestamp, ids) -> DataFrame[player_id, ref_date, season_minutes, congested_apps, acute, chronic, acwr, age, index, band, flag]` — `index` 0–100, `band` in {"Heavy", "High", "Normal", "Light"}, `flag` bool (unusual + index ≥ 60)

- [ ] **Step 1: Write the failing tests**

`pipeline/tests/test_workload.py`:
```python
import numpy as np
import pandas as pd

from touchline.models.workload import workload_table


def _apps():
    rows = []
    start = pd.Timestamp("2025-08-10")
    for pid, gap, mins in [(1, 3, 90), (2, 7, 90), (3, 14, 30)]:
        d = start
        while d < pd.Timestamp("2026-05-20"):
            rows.append({"player_id": pid, "date": d, "minutes": mins})
            d += pd.Timedelta(days=gap)
    return pd.DataFrame(rows)


def test_heavier_schedule_scores_higher():
    players = pd.DataFrame({"player_id": [1, 2, 3], "dob": pd.to_datetime(["1995-01-01"] * 3)})
    w = workload_table(_apps(), players, pd.Timestamp("2025-07-01"), ids=[1, 2, 3]).set_index("player_id")
    assert w.loc[1, "index"] > w.loc[2, "index"] > w.loc[3, "index"]
    assert w.loc[1, "congested_apps"] > 0 and w.loc[2, "congested_apps"] == 0
    assert w.loc[1, "band"] == "Heavy"
    assert np.isclose(w.loc[2, "acwr"], w.loc[2, "acute"] / w.loc[2, "chronic"])


def test_player_without_appearances_is_absent_not_crashing():
    players = pd.DataFrame({"player_id": [1, 9], "dob": [pd.Timestamp("1995-01-01"), pd.NaT]})
    w = workload_table(_apps(), players, pd.Timestamp("2025-07-01"), ids=[1, 9])
    assert list(w.player_id) == [1]
```

- [ ] **Step 2: Run — expect FAIL**

- [ ] **Step 3: Implement**

`pipeline/touchline/models/workload.py`:
```python
"""M6 — workload risk index (not an injury probability: the dataset has no injury labels).

Combines season minutes, congested appearances (<4 days' rest) and the acute:chronic workload
ratio (7-day minutes vs 28-day weekly average). An Isolation Forest flags unusual loads."""
import numpy as np
import pandas as pd
from sklearn.ensemble import IsolationForest


def workload_table(apps: pd.DataFrame, players: pd.DataFrame, season_start: pd.Timestamp,
                   ids) -> pd.DataFrame:
    a = apps[apps.player_id.isin(ids)].sort_values(["player_id", "date"]).copy()
    a["rest"] = a.groupby("player_id")["date"].diff().dt.days
    rows = []
    for pid, g in a.groupby("player_id"):
        season = g[g.date >= season_start]
        if season.empty:
            continue
        ref = g.date.max()
        acute = g.loc[g.date > ref - pd.Timedelta(days=7), "minutes"].sum()
        chronic = g.loc[g.date > ref - pd.Timedelta(days=28), "minutes"].sum() / 4.0
        rows.append({"player_id": pid, "ref_date": ref,
                     "season_minutes": float(season.minutes.sum()),
                     "congested_apps": int((season.rest < 4).sum()),
                     "acute": float(acute), "chronic": float(chronic),
                     "acwr": float(acute / chronic) if chronic > 0 else 0.0})
    w = pd.DataFrame(rows, columns=["player_id", "ref_date", "season_minutes", "congested_apps",
                                    "acute", "chronic", "acwr"])
    if w.empty:
        return w.assign(age=[], index=[], band=[], flag=[])
    dob = players.set_index("player_id")["dob"]
    w["age"] = [(r - dob.get(p)).days / 365.25 if pd.notna(dob.get(p)) else np.nan
                for p, r in zip(w.player_id, w.ref_date)]
    pct = lambda s: s.rank(pct=True)  # noqa: E731
    w["index"] = (100 * (0.5 * pct(w.season_minutes) + 0.3 * pct(w.congested_apps)
                         + 0.2 * pct(w.acwr))).round(0)
    w["band"] = pd.cut(w["index"], [-1, 30, 60, 80, 101],
                       labels=["Light", "Normal", "High", "Heavy"]).astype(str)
    feats = w[["season_minutes", "congested_apps", "acwr", "age"]].fillna(
        w[["season_minutes", "congested_apps", "acwr", "age"]].median())
    if len(w) >= 20:
        unusual = IsolationForest(contamination=0.05, random_state=0).fit_predict(feats) == -1
    else:
        unusual = np.zeros(len(w), bool)
    w["flag"] = unusual & (w["index"] >= 60)
    return w.reset_index(drop=True)
```

- [ ] **Step 4: Run — expect PASS**

- [ ] **Step 5: Commit**

```bash
git add pipeline/touchline/models/workload.py pipeline/tests/test_workload.py
git commit -m "feat(pipeline): M6 workload risk index with anomaly flag"
```

---

### Task 12: M7 similarity + M8 budget planner

**Files:**
- Create: `pipeline/touchline/models/similarity.py`, `pipeline/touchline/models/budget.py`
- Test: `pipeline/tests/test_similarity.py`, `pipeline/tests/test_budget.py`

**Interfaces:**
- Produces:
  - `similar_players(df: DataFrame[player_id, position, sub_position, g90, a90, minutes_share, yellow90, age, club_elo], k=8) -> dict[int, list[int]]` (same position group, self excluded, nearest first)
  - `plan_signings(cands: DataFrame[player_id, pos, price, score], budget: float, needs: dict[str, int]) -> list[int]` (ILP; `[]` if infeasible)
  - `greedy_signings(cands, budget, needs) -> list[int]` (baseline)

- [ ] **Step 1: Write the failing tests**

`pipeline/tests/test_similarity.py`:
```python
import pandas as pd

from touchline.models.similarity import similar_players


def test_nearest_is_the_lookalike_and_same_position():
    df = pd.DataFrame({
        "player_id": [1, 2, 3, 4], "position": ["Attack", "Attack", "Attack", "Defender"],
        "sub_position": ["Centre-Forward", "Centre-Forward", "Left Winger", "Centre-Back"],
        "g90": [0.8, 0.78, 0.1, 0.8], "a90": [0.2, 0.21, 0.5, 0.2],
        "minutes_share": [0.9, 0.88, 0.5, 0.9], "yellow90": [0.1, 0.1, 0.2, 0.1],
        "age": [25, 25.5, 30, 25], "club_elo": [1700, 1690, 1500, 1700]})
    sim = similar_players(df, k=2)
    assert sim[1][0] == 2
    assert 4 not in sim[1] and 1 not in sim[1]
    assert sim[4] == []  # alone in its position group
```

`pipeline/tests/test_budget.py`:
```python
import pandas as pd

from touchline.models.budget import greedy_signings, plan_signings


def _cands():
    return pd.DataFrame({
        "player_id": [1, 2, 3, 4, 5],
        "pos": ["Attack", "Attack", "Midfield", "Midfield", "Defender"],
        "price": [60.0, 30.0, 40.0, 25.0, 20.0],
        "score": [80.0, 45.0, 50.0, 40.0, 30.0]})


def test_ilp_respects_budget_and_needs_and_beats_greedy():
    c = _cands()
    pick = plan_signings(c, budget=100, needs={"Attack": 1, "Midfield": 1})
    chosen = c[c.player_id.isin(pick)]
    assert chosen.price.sum() <= 100
    assert sorted(chosen.pos) == ["Attack", "Midfield"]
    greedy = c[c.player_id.isin(greedy_signings(c, 100, {"Attack": 1, "Midfield": 1}))]
    assert chosen.score.sum() >= greedy.score.sum()
    assert set(pick) == {1, 4}  # 60 + 25 = 85 <= 100, score 120 is optimal


def test_infeasible_returns_empty():
    assert plan_signings(_cands(), budget=10, needs={"Attack": 1}) == []
```

- [ ] **Step 2: Run — expect FAIL**

- [ ] **Step 3: Implement**

`pipeline/touchline/models/similarity.py`:
```python
"""M7 — "plays like X": k-NN over standardised per-90 profiles within a position group."""
import numpy as np
import pandas as pd
from sklearn.neighbors import NearestNeighbors

PROFILE = {"g90": 1.0, "a90": 1.0, "minutes_share": 0.7, "yellow90": 0.3, "age": 0.5,
           "club_elo": 0.5}
ROLE_WEIGHT = 1.5


def similar_players(df: pd.DataFrame, k: int = 8) -> dict[int, list[int]]:
    out: dict[int, list[int]] = {}
    for _, g in df.groupby("position"):
        ids = g.player_id.to_numpy()
        if len(g) == 1:
            out[int(ids[0])] = []
            continue
        x = g[list(PROFILE)].astype(float)
        x = (x - x.mean()) / x.std(ddof=0).replace(0, 1)
        x = x.fillna(0) * pd.Series(PROFILE)
        roles = pd.get_dummies(g.sub_position.fillna("?")).astype(float) * ROLE_WEIGHT
        mat = np.hstack([x.to_numpy(), roles.to_numpy()])
        nn = NearestNeighbors(n_neighbors=min(k + 1, len(g))).fit(mat)
        _, idx = nn.kneighbors(mat)
        for row, neigh in enumerate(idx):
            out[int(ids[row])] = [int(ids[j]) for j in neigh if j != row][:k]
    return out
```

`pipeline/touchline/models/budget.py`:
```python
"""M8 — transfer budget planner: choose signings maximising total quality within a budget.

Quality score = the valuator's performance-based fair value (EUR m), price = market value.
Solved exactly as a 0/1 integer programme; a greedy value-per-euro pick is the baseline."""
import numpy as np
import pandas as pd
from scipy.optimize import Bounds, LinearConstraint, milp


def plan_signings(cands: pd.DataFrame, budget: float, needs: dict[str, int]) -> list[int]:
    c = cands[cands.pos.isin(needs)].reset_index(drop=True)
    if c.empty:
        return []
    n = len(c)
    rows, lo, hi = [c.price.to_numpy(float)], [0.0], [float(budget)]
    for pos, count in needs.items():
        rows.append((c.pos == pos).to_numpy(float))
        lo.append(count)
        hi.append(count)
    res = milp(c=-c.score.to_numpy(float), integrality=np.ones(n),
               bounds=Bounds(0, 1), constraints=LinearConstraint(np.vstack(rows), lo, hi))
    if not res.success:
        return []
    return [int(p) for p, x in zip(c.player_id, res.x) if x > 0.5]


def greedy_signings(cands: pd.DataFrame, budget: float, needs: dict[str, int]) -> list[int]:
    left, spent, picked = dict(needs), 0.0, []
    c = cands[cands.pos.isin(needs)].assign(r=lambda d: d.score / d.price.clip(lower=0.1))
    for row in c.sort_values("r", ascending=False).itertuples(index=False):
        if left.get(row.pos, 0) > 0 and spent + row.price <= budget:
            picked.append(int(row.player_id))
            spent += row.price
            left[row.pos] -= 1
    return picked
```

- [ ] **Step 4: Run — expect PASS**

- [ ] **Step 5: Commit**

```bash
git add pipeline/touchline/models/similarity.py pipeline/touchline/models/budget.py pipeline/tests/test_similarity.py pipeline/tests/test_budget.py
git commit -m "feat(pipeline): M7 player similarity and M8 ILP budget planner"
```

---

### Task 13: Trending score + bundle export + schema doc

**Files:**
- Create: `pipeline/touchline/models/trending.py`, `pipeline/touchline/export/__init__.py` (empty), `pipeline/touchline/export/bundle.py`, `docs/bundle-schema.md`
- Test: `pipeline/tests/test_trending.py`, `pipeline/tests/test_bundle.py`

**Interfaces:**
- Produces:
  - `trending(df: DataFrame[player_id, minutes, ga90, last5_ga, last5_minutes, value_now, value_6m_ago, forecast_ga5], min_minutes=900) -> DataFrame[player_id, trend_score, reasons]` (score NaN below min_minutes; reasons ≤ 2 strings)
  - `sanitize(obj) -> obj` (NaN/inf → None, numpy → python)
  - `validate_bundle(b: dict) -> None` (raises `ValueError` naming the missing key)
  - `write_bundle(b: dict, path: Path) -> int` (bytes written; gzip; strict JSON)

- [ ] **Step 1: Write the failing tests**

`pipeline/tests/test_trending.py`:
```python
import numpy as np
import pandas as pd

from touchline.models.trending import trending


def test_hot_player_ranks_first_with_reasons():
    df = pd.DataFrame({
        "player_id": [1, 2, 3, 4], "minutes": [2500, 2500, 2500, 300],
        "ga90": [0.4, 0.4, 0.4, 0.4], "last5_ga": [5, 1, 0, 5], "last5_minutes": [450] * 4,
        "value_now": [60e6, 30e6, 20e6, 5e6], "value_6m_ago": [40e6, 30e6, 25e6, 5e6],
        "forecast_ga5": [3.0, 1.0, 0.5, 2.0]})
    t = trending(df).set_index("player_id")
    assert t.trend_score.idxmax() == 1
    assert np.isnan(t.loc[4, "trend_score"])
    assert "5 goal involvements in last 5" in t.loc[1, "reasons"]
    assert any("Value up" in r for r in t.loc[1, "reasons"])
```

`pipeline/tests/test_bundle.py`:
```python
import gzip
import json

import numpy as np
import pytest

from touchline.export.bundle import sanitize, validate_bundle, write_bundle

MIN = {"schema_version": 1, "generated_at": "2026-10-04T00:00:00Z",
       "data_through": {"players": "2026-06-28", "clubs": "2026-10-03"},
       "player_season": "2025/26", "leagues": [], "clubs": [], "fixtures": [], "players": [],
       "models": {}}


def test_sanitize_removes_nan_and_numpy():
    out = sanitize({"a": np.float64("nan"), "b": [np.int64(3), float("inf")], "c": np.bool_(True)})
    assert out == {"a": None, "b": [3, None], "c": True}
    json.dumps(out, allow_nan=False)


def test_write_bundle_roundtrip(tmp_path):
    b = dict(MIN, players=[{"id": 1, "fair_value": float("nan")}])
    n = write_bundle(b, tmp_path / "b.json.gz")
    data = json.loads(gzip.decompress((tmp_path / "b.json.gz").read_bytes()))
    assert n > 0 and data["players"][0]["fair_value"] is None


def test_validate_names_missing_key():
    bad = {k: v for k, v in MIN.items() if k != "clubs"}
    with pytest.raises(ValueError, match="clubs"):
        validate_bundle(bad)
```

- [ ] **Step 2: Run — expect FAIL**

- [ ] **Step 3: Implement**

`pipeline/touchline/models/trending.py`:
```python
"""Trending score: recent output vs own baseline, market-value momentum, and forecast."""
import numpy as np
import pandas as pd


def _z(s: pd.Series) -> pd.Series:
    sd = s.std(ddof=0)
    return (s - s.mean()) / sd if sd and sd > 0 else s * 0.0


def trending(df: pd.DataFrame, min_minutes: int = 900) -> pd.DataFrame:
    d = df.copy()
    last5_ga90 = np.where(d.last5_minutes >= 200, d.last5_ga / d.last5_minutes.clip(lower=1) * 90,
                          d.ga90)
    d["form_delta"] = last5_ga90 - d.ga90
    d["value_change"] = d.value_now - d.value_6m_ago
    d["value_change_pct"] = d.value_change / d.value_6m_ago.where(d.value_6m_ago > 0)
    ok = d.minutes >= min_minutes
    e = d[ok]
    score = (0.4 * _z(e.form_delta.fillna(0)) + 0.3 * _z(e.value_change_pct.fillna(0))
             + 0.3 * _z(e.forecast_ga5.fillna(0)))
    d["trend_score"] = np.nan
    d.loc[ok, "trend_score"] = score

    def reasons(r) -> list[str]:
        out = []
        if r.last5_ga >= 3:
            out.append(f"{int(r.last5_ga)} goal involvements in last 5")
        if pd.notna(r.value_change_pct) and r.value_change_pct >= 0.10:
            out.append(f"Value up €{r.value_change / 1e6:.0f}M")
        if pd.notna(r.forecast_ga5) and r.forecast_ga5 >= 2.0:
            out.append(f"Projected {r.forecast_ga5:.1f} G/A next 5")
        return out[:2]

    d["reasons"] = [reasons(r) for r in d.itertuples(index=False)]
    return d[["player_id", "trend_score", "reasons"]]
```

`pipeline/touchline/export/bundle.py`:
```python
"""Bundle export: the only contract between the pipeline and the app (see docs/bundle-schema.md)."""
import gzip
import json
import math
from pathlib import Path

import numpy as np
import pandas as pd

REQUIRED = ["schema_version", "generated_at", "data_through", "player_season", "leagues",
            "clubs", "fixtures", "players", "models"]


def sanitize(obj):
    if isinstance(obj, dict):
        return {str(k): sanitize(v) for k, v in obj.items()}
    if isinstance(obj, (list, tuple)):
        return [sanitize(v) for v in obj]
    if isinstance(obj, np.bool_):
        return bool(obj)
    if isinstance(obj, np.integer):
        return int(obj)
    if isinstance(obj, (float, np.floating)):
        f = float(obj)
        return None if math.isnan(f) or math.isinf(f) else f
    if isinstance(obj, pd.Timestamp):
        return None if pd.isna(obj) else obj.strftime("%Y-%m-%d")
    if obj is pd.NaT:
        return None
    return obj


def validate_bundle(b: dict) -> None:
    for k in REQUIRED:
        if k not in b:
            raise ValueError(f"bundle missing key: {k}")


def write_bundle(b: dict, path: Path) -> int:
    validate_bundle(b)
    raw = json.dumps(sanitize(b), allow_nan=False, separators=(",", ":"), ensure_ascii=False)
    data = gzip.compress(raw.encode("utf-8"), compresslevel=9)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    return len(data)
```

`docs/bundle-schema.md`:
````markdown
# Touchline bundle — schema v1

Gzipped strict JSON (`touchline-bundle.json.gz`). Produced weekly by `pipeline/`, consumed by
`app/`. Breaking changes bump `schema_version`; the app refuses unknown major versions and keeps
its cached bundle.

```jsonc
{
  "schema_version": 1,
  "generated_at": "2026-10-04T06:00:00Z",
  "data_through": {"players": "2026-06-28", "clubs": "2026-10-03"},
  "player_season": "2025/26",
  "leagues": [{"id": "GB1", "fd": "PL", "name": "Premier League"}],
  "clubs": [{
    "id": 11,                       // Transfermarkt club id; negative = football-data id (club new to dataset)
    "name": "Arsenal", "crest": "https://…png" /* or null */, "league": "GB1",
    "elo": 1912.4, "elo_change_30d": 14.2,
    "form": ["W", "D", "W"],        // oldest → newest, up to 5
    "table": {"pos": 1, "played": 7, "points": 19, "gd": 12, "gf": 15, "ga": 3},
    "proj": {"exp_points": 81.3, "exp_pos": 1.7, "p_title": 0.41, "p_top4": 0.93, "p_releg": 0.0}
            // null in offline mode
  }],
  "fixtures": [{
    "id": 537001, "league": "GB1", "kickoff": "2026-10-05T14:00:00Z",
    "home": 11, "away": 31, "status": "TIMED",       // FINISHED fixtures are from the last 7 days
    "score": null,                                    // [home, away] when finished
    "p": [0.46, 0.26, 0.28],                          // home / draw / away (pre-match)
    "xg": [1.62, 1.08]                                // expected goals from the match model
  }],
  "players": [{
    "id": 342229, "name": "…", "img": "https://…", "club": 11, "league": "GB1",
    "pos": "Attack", "sub_pos": "Centre-Forward", "age": 24.3, "nat": "England",
    "foot": "right", "height": 185,
    "market_value": 80000000,
    "fair_value": 95000000,          // null if < 900 minutes
    "value_gap_pct": 0.19,           // (fair - market) / market; null if fair_value null
    "value_why": [{"f": "Goal involvements per 90", "effect_pct": 0.35}],
    "season": {"apps": 40, "minutes": 3200, "goals": 20, "assists": 8, "ga90": 0.79},
    "form": {"last5": [{"date": "2026-05-24", "opp": "…", "ga": 1, "min": 90}],
             "forecast_ga5": 3.1},   // forecast null if < 10 appearances or < 900 minutes
    "workload": {"index": 82, "band": "Heavy", "acwr": 1.21, "season_minutes": 4100,
                 "congested_apps": 12, "flag": true, "as_of": "2026-05-24"},  // null if no apps
    "value_history": [["2021-07-01", 20000000]],      // one point per year, oldest first
    "transfers": [{"date": "2023-07-01", "from": "…", "to": "…", "fee": 50000000}],
    "similar": [123, 456],           // same position group, nearest first
    "trend": {"score": 1.8, "reasons": ["5 goal involvements in last 5"]}  // score null if < 900 min
  }],
  "models": { /* contents of metrics.json — shown on the in-app "How this works" sheet */ }
}
```

Money is EUR. Dates are ISO `YYYY-MM-DD`, timestamps ISO UTC with `Z`. `null` always means
"not enough data" — the app must render a friendly empty state, never `0`.
````

- [ ] **Step 4: Run — expect PASS**

- [ ] **Step 5: Commit**

```bash
git add pipeline/touchline/models/trending.py pipeline/touchline/export docs/bundle-schema.md pipeline/tests/test_trending.py pipeline/tests/test_bundle.py
git commit -m "feat(pipeline): trending score, bundle export and schema v1"
```

---

### Task 14: Orchestration, baseline gate, first real run

**Files:**
- Create: `pipeline/touchline/run.py`
- Test: `pipeline/tests/test_run.py`

**Interfaces:**
- Consumes: everything above
- Produces: CLI `python -m touchline.run [--skip-download] [--offline] [--fast] [--no-gate] [--out DIR]`; `check_gates(metrics: dict) -> list[str]` (failure messages); writes `OUT/touchline-bundle.json.gz`, `OUT/metrics.json`, `OUT/budget_cases.json` (golden cases for the app's on-device planner port).

- [ ] **Step 1: Write the failing test**

`pipeline/tests/test_run.py`:
```python
from touchline.run import check_gates


def test_gates_pass_and_fail():
    ok = {"club_elo": {"favourite_accuracy": 0.6, "baseline_home_pick_accuracy": 0.55},
          "match_model": {"rps": 0.20, "baseline_rps": 0.23},
          "valuator": {"mae_eur": 3e6, "baseline_mae_eur": 6e6},
          "form": {"poisson_deviance": 1.0, "baseline_poisson_deviance": 1.2}}
    assert check_gates(ok) == []
    bad = {**ok, "valuator": {"mae_eur": 7e6, "baseline_mae_eur": 6e6}}
    fails = check_gates(bad)
    assert len(fails) == 1 and "valuator" in fails[0]
```

- [ ] **Step 2: Run — expect FAIL**

- [ ] **Step 3: Implement**

`pipeline/touchline/run.py`:
```python
"""Touchline pipeline: python -m touchline.run --help"""
import argparse
import json
import logging
import os
import sys
from dataclasses import asdict
from datetime import datetime, timezone
from pathlib import Path

import pandas as pd
from dotenv import load_dotenv

from touchline import config
from touchline.export.bundle import sanitize, write_bundle
from touchline.features.players import (add_prev_season, build_player_rows, enrich_appearances,
                                        season_stats)
from touchline.ingest.club_map import load_overrides
from touchline.ingest.download import download_tables
from touchline.ingest.football_data import FootballData
from touchline.ingest.load import load_tm
from touchline.models import budget, elo, form, match_model, similarity, trending, valuator, workload
from touchline.season import build_current_season, offline_clubs

log = logging.getLogger("touchline")

GATES = [("club_elo", "favourite_accuracy", "baseline_home_pick_accuracy", "higher"),
         ("match_model", "rps", "baseline_rps", "lower"),
         ("valuator", "mae_eur", "baseline_mae_eur", "lower"),
         ("form", "poisson_deviance", "baseline_poisson_deviance", "lower")]


def check_gates(metrics: dict) -> list[str]:
    fails = []
    for model, key, base, better in GATES:
        m = metrics[model]
        ok = m[key] > m[base] if better == "higher" else m[key] < m[base]
        if not ok:
            fails.append(f"{model}: {key}={m[key]:.4f} does not beat {base}={m[base]:.4f}")
    return fails


def _season_label(s: int) -> str:
    return f"{s}/{str(s + 1)[-2:]}"


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="Build the Touchline data bundle.")
    ap.add_argument("--skip-download", action="store_true")
    ap.add_argument("--offline", action="store_true", help="skip football-data.org")
    ap.add_argument("--fast", action="store_true", help="fewer sims/epochs for smoke runs")
    ap.add_argument("--no-gate", action="store_true")
    ap.add_argument("--out", type=Path, default=config.OUT_DIR)
    args = ap.parse_args(argv)
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(message)s")
    load_dotenv(config.ROOT.parent / ".env")
    load_dotenv(config.ROOT / ".env")

    if not args.skip_download:
        log.info("downloading dataset")
        download_tables(force=True)
    tm = load_tm()
    games, players = tm["games"], tm["players"]
    lg_games = games[games.competition_id.isin(list(config.LEAGUES))]
    test_season = int(lg_games.season.max())
    log.info("test season %s", test_season)
    metrics: dict = {}

    # M1 Elo
    params, grid = elo.tune_elo(games, (games.season == test_season - 1)
                                & games.competition_id.isin(list(config.LEAGUES)))
    elo_res = elo.run_elo(games, params)
    metrics["club_elo"] = {"params": asdict(params),
                           **elo.evaluate_favourites(games, elo_res.pre, test_season, params.home_adv)}
    log.info("M1 %s", metrics["club_elo"])

    # M2 match model
    lg = lg_games.merge(elo_res.pre, on="game_id")
    lg["d"] = lg.elo_home - lg.elo_away
    train = lg[(lg.season >= config.MODEL_FROM_SEASON) & (lg.season < test_season)]
    test = lg[lg.season == test_season]
    m2 = match_model.fit_match_model(train.d, train.home_goals, train.away_goals)
    metrics["match_model"] = match_model.evaluate(m2, train, test)
    full = lg[lg.season >= config.MODEL_FROM_SEASON]
    m2_final = match_model.fit_match_model(full.d, full.home_goals, full.away_goals)
    log.info("M2 %s", metrics["match_model"])

    # Clubs (M3 inside)
    token = os.environ.get("FOOTBALL_API_KEY", "").strip()
    today = pd.Timestamp.now(tz="UTC")
    if args.offline or not token:
        clubs, fixtures = offline_clubs(games, tm["clubs"], elo_res, test_season), []
        clubs_through = str(lg_games.date.max().date())
    else:
        fd = FootballData(token)
        clubs, fixtures = build_current_season(fd, tm["clubs"], elo_res, params, m2_final,
                                               config.current_season(), load_overrides(), today,
                                               n_sims=2000 if args.fast else 10000)
        clubs_through = str(today.date())
    log.info("clubs %d fixtures %d", len(clubs), len(fixtures))

    # Player features
    eapps = enrich_appearances(tm["appearances"], games)
    stats = add_prev_season(season_stats(eapps, games))
    rows = build_player_rows(stats, players, tm["valuations"], elo_res.history)

    # M4 valuator
    val_model, metrics["valuator"] = valuator.run_valuator(rows, test_season)
    log.info("M4 %s", metrics["valuator"])

    # Display population: players currently at a top-5 club with test-season minutes
    cur = players[players.league.isin(list(config.LEAGUES))
                  & (players.last_season >= test_season)]
    disp = stats[(stats.season == test_season) & stats.player_id.isin(cur.player_id)]
    disp_rows = build_player_rows(stats[(stats.season == test_season)
                                        & stats.player_id.isin(disp.player_id)],
                                  players, tm["valuations"], elo_res.history,
                                  min_league_minutes=config.MIN_DISPLAY_MINUTES, with_target=False)
    fair = dict(zip(disp_rows.player_id, val_model.predict(disp_rows)))
    why = dict(zip(disp_rows.player_id, val_model.explain(disp_rows)))

    # M5 form
    feats = form.appearance_features(eapps, elo_res.pre)
    pool = set(stats[(stats.league_minutes > 0) & (stats.season >= config.MODEL_FROM_SEASON)].player_id)
    seqs = form.build_sequences(feats, players, pool, stride=10 if args.fast else 5)
    form_model, metrics["form"] = form.run_form(
        seqs, pd.Timestamp(test_season - 1, 7, 1), pd.Timestamp(test_season, 7, 1),
        epochs=3 if args.fast else 15)
    log.info("M5 %s", metrics["form"])
    latest = form.latest_windows(feats, players, set(disp.player_id))
    forecast = dict(zip(latest.player_id, form_model.predict(latest)))

    # M6 workload
    wl = workload.workload_table(tm["appearances"], players, pd.Timestamp(test_season, 7, 1),
                                 set(disp.player_id)).set_index("player_id")
    metrics["workload"] = {"n": int(len(wl)), "bands": wl.band.value_counts().to_dict(),
                           "flagged": int(wl.flag.sum())}

    # M7 similarity (qualified players only)
    sim = similarity.similar_players(disp_rows)

    # Trending inputs
    last5 = feats[feats.player_id.isin(disp.player_id)].groupby("player_id").tail(5)
    l5 = last5.groupby("player_id").agg(last5_ga=("ga", "sum"), last5_minutes=("minutes", "sum"))
    vals = tm["valuations"].sort_values("date")
    v_now = vals.groupby("player_id").value.last()
    six_months = vals[vals.date <= vals.date.max() - pd.Timedelta(days=182)]
    v_ago = six_months.groupby("player_id").value.last()
    tr_in = disp[["player_id", "minutes", "ga90"]].set_index("player_id").join(l5)
    tr_in["value_now"] = v_now
    tr_in["value_6m_ago"] = v_ago
    tr_in["forecast_ga5"] = pd.Series(forecast)
    trend = trending.trending(tr_in.reset_index()).set_index("player_id")

    # Assemble players
    pinfo = players.set_index("player_id")
    st = disp.set_index("player_id")
    transfers = tm["transfers"].sort_values("date")
    yearly = vals.assign(y=vals.date.dt.year).groupby(["player_id", "y"]).tail(1)
    yearly = yearly[yearly.date >= vals.date.max() - pd.Timedelta(days=6 * 365)]
    hist_by = {p: g for p, g in yearly.groupby("player_id")}
    tr_by = {p: g.tail(5) for p, g in transfers[transfers.player_id.isin(disp.player_id)].groupby("player_id")}
    l5_by = {p: g for p, g in last5.groupby("player_id")}
    out_players = []
    for pid in disp.player_id:
        p, s = pinfo.loc[pid], st.loc[pid]
        qualified = s.minutes >= config.MIN_DISPLAY_MINUTES
        fv = fair.get(pid) if qualified else None
        mv = p.market_value if pd.notna(p.market_value) else None
        w = wl.loc[pid] if pid in wl.index else None
        out_players.append({
            "id": int(pid), "name": p["name"], "img": p.image_url,
            "club": int(p.current_club_id) if pd.notna(p.current_club_id) else None,
            "league": p.league, "pos": p.position, "sub_pos": p.sub_position,
            "age": round((today.tz_localize(None) - p.dob).days / 365.25, 1) if pd.notna(p.dob) else None,
            "nat": p.nationality, "foot": p.foot, "height": p.height,
            "market_value": mv, "fair_value": round(fv, -5) if fv else None,
            "value_gap_pct": (fv - mv) / mv if (fv and mv) else None,
            "value_why": why.get(pid) if fv else None,
            "season": {"apps": int(s.apps), "minutes": int(s.minutes), "goals": int(s.goals),
                       "assists": int(s.assists), "ga90": round(float(s.ga90), 2)},
            "form": {"last5": [{"date": r.date.strftime("%Y-%m-%d"), "opp": r.opp_name,
                                "ga": int(r.ga), "min": int(r.minutes)}
                               for r in l5_by[pid].itertuples()] if pid in l5_by else [],
                     "forecast_ga5": round(float(forecast[pid]), 2)
                     if (pid in forecast and qualified) else None},
            "workload": None if w is None else {
                "index": int(w["index"]), "band": w.band, "acwr": round(float(w.acwr), 2),
                "season_minutes": int(w.season_minutes), "congested_apps": int(w.congested_apps),
                "flag": bool(w.flag), "as_of": w.ref_date.strftime("%Y-%m-%d")},
            "value_history": [[r.date.strftime("%Y-%m-%d"), int(r.value)]
                              for r in hist_by[pid].itertuples()] if pid in hist_by else [],
            "transfers": [{"date": r.date.strftime("%Y-%m-%d"), "from": r.from_club,
                           "to": r.to_club, "fee": r.fee} for r in tr_by[pid].itertuples()]
            if pid in tr_by else [],
            "similar": sim.get(int(pid), []),
            "trend": {"score": trend.loc[pid, "trend_score"],
                      "reasons": trend.loc[pid, "reasons"]},
        })

    # M8 golden cases for the app port + metrics
    cand = pd.DataFrame([{"player_id": p["id"], "pos": p["pos"], "price": p["market_value"] / 1e6,
                          "score": p["fair_value"] / 1e6} for p in out_players
                         if p["fair_value"] and p["market_value"]])
    cases = []
    for b, needs in [(50, {"Attack": 1}), (100, {"Attack": 1, "Midfield": 1, "Defender": 1}),
                     (200, {"Attack": 2, "Midfield": 2, "Defender": 2, "Goalkeeper": 1})]:
        ilp = budget.plan_signings(cand, b, needs)
        gr = budget.greedy_signings(cand, b, needs)
        sc = cand.set_index("player_id").score
        cases.append({"budget_m": b, "needs": needs, "ilp": ilp, "greedy": gr,
                      "ilp_score": float(sc.loc[ilp].sum()), "greedy_score": float(sc.loc[gr].sum())})
    metrics["budget"] = {"cases": [{k: c[k] for k in ("budget_m", "ilp_score", "greedy_score")}
                                   for c in cases]}

    bundle = {
        "schema_version": config.SCHEMA_VERSION,
        "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "data_through": {"players": str(tm["appearances"].date.max().date()),
                         "clubs": clubs_through},
        "player_season": _season_label(test_season),
        "leagues": [{"id": k, "fd": v[0], "name": v[1]} for k, v in config.LEAGUES.items()],
        "clubs": clubs, "fixtures": fixtures, "players": out_players, "models": metrics,
    }
    args.out.mkdir(parents=True, exist_ok=True)
    size = write_bundle(bundle, args.out / config.BUNDLE_NAME)
    (args.out / "metrics.json").write_text(json.dumps(sanitize(metrics), indent=2))
    (args.out / "budget_cases.json").write_text(json.dumps(sanitize(cases), indent=2))
    log.info("bundle %.2f MB, %d players", size / 1e6, len(out_players))

    fails = check_gates(metrics)
    for f in fails:
        log.error("GATE FAILED %s", f)
    return 1 if (fails and not args.no_gate) else 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: Run unit tests — expect PASS**

Run: `.venv/Scripts/python -m pytest -v`

- [ ] **Step 5: First real run (offline, fast)**

Run: `.venv/Scripts/python -m touchline.run --skip-download --offline --fast`
Expected: logs for M1–M5, `bundle X.XX MB, ~2500-3700 players`, exit code 0. If a stage crashes on real data, fix the module and add a regression test reproducing the shape that broke it.

- [ ] **Step 6: Full live run**

Copy the token: `cp /c/Users/91750/OneDrive/Desktop/fatigue_api/.env /c/Users/91750/touchline/pipeline/.env` (git-ignored via root `.gitignore` in Task 15 — verify `git status` does not show it).
Run: `.venv/Scripts/python -m touchline.run --skip-download`
Expected: ~100 clubs, fixtures for the next 14 days, all 4 gates pass. Inspect `data/out/metrics.json`; spot-check 3 well-known players and the PL projection for sanity. Record the numbers for the README.

- [ ] **Step 7: Commit**

```bash
git add pipeline/touchline/run.py pipeline/tests/test_run.py
git commit -m "feat(pipeline): orchestration CLI with baseline gate"
```

---

### Task 15: CI, weekly refresh, repo hygiene, pipeline README

**Files:**
- Create: `.gitignore` (repo root), `.github/workflows/ci.yml`, `.github/workflows/refresh.yml`, `pipeline/README.md`, `LICENSE` (MIT, "Copyright (c) 2026 Aryan")

**Interfaces:**
- Consumes: CLI from Task 14
- Produces: GitHub release tag `data-latest` holding `touchline-bundle.json.gz` + `metrics.json` (the app's download URL in Plan 2: `https://github.com/<owner>/touchline/releases/download/data-latest/touchline-bundle.json.gz`)

- [ ] **Step 1: Root `.gitignore`**

```
.env
*.jks
*.keystore
key.properties
.DS_Store
.idea/
.vscode/
```

- [ ] **Step 2: `.github/workflows/ci.yml`**

```yaml
name: ci
on:
  push:
    branches: [main]
  pull_request:
jobs:
  pipeline:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: pipeline
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"
          cache: pip
      - run: pip install torch --index-url https://download.pytorch.org/whl/cpu
      - run: pip install -e ".[dev]"
      - run: ruff check touchline tests
      - run: pytest -m "not slow" -q
```

- [ ] **Step 3: `.github/workflows/refresh.yml`**

```yaml
name: refresh-data
on:
  schedule:
    - cron: "0 5 * * 2"   # Tuesdays 05:00 UTC, after the weekend's matches
  workflow_dispatch:
permissions:
  contents: write
jobs:
  build:
    runs-on: ubuntu-latest
    timeout-minutes: 60
    defaults:
      run:
        working-directory: pipeline
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"
          cache: pip
      - run: pip install torch --index-url https://download.pytorch.org/whl/cpu
      - run: pip install -e .
      - name: Build bundle
        env:
          FOOTBALL_API_KEY: ${{ secrets.FOOTBALL_API_KEY }}
        run: python -m touchline.run
      - name: Publish to data-latest release
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          gh release view data-latest >/dev/null 2>&1 || \
            gh release create data-latest --title "Latest data" --notes "Auto-refreshed weekly." --prerelease
          gh release upload data-latest data/out/touchline-bundle.json.gz data/out/metrics.json --clobber
```

If the gate fails, `python -m touchline.run` exits 1 → the upload step never runs → the previous bundle stays live.

- [ ] **Step 4: `pipeline/README.md`** — sections: What it does (one paragraph), Quick start (venv, torch CPU install, `pip install -e ".[dev]"`, `.env` with `FOOTBALL_API_KEY`, `python -m touchline.run`), Models table (M1–M8: method, target, baseline, test metric — filled with the numbers from Task 14 Step 6), Data & licence (Transfermarkt CC0, football-data.org terms), Known limitations (no injury labels; player season lags the dataset; Transfermarkt values are crowd estimates).

- [ ] **Step 5: Verify**

Run: `.venv/Scripts/python -m ruff check touchline tests && .venv/Scripts/python -m pytest -q`
Expected: no lint errors, all tests pass. Fix lint findings in place.

- [ ] **Step 6: Commit**

```bash
git add .gitignore LICENSE .github pipeline/README.md
git commit -m "ci: tests on push, weekly data refresh to data-latest release"
```

---

## Plan 2 preview (written after Task 14 produces a real bundle)

Flutter app in `app/`: impeccable-led redesign, 4 tabs (Home dashboard, Clubs, Players, Scout), offline-first bundle loader with seed bundle, Dart port of the budget planner checked against `budget_cases.json`, release APK, root README with screenshots and the metrics table.
