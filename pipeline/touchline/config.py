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
