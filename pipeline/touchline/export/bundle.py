"""Bundle export: the only contract between the pipeline and the app (docs/bundle-schema.md)."""
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
    if obj is pd.NaT or obj is pd.NA:
        return None
    if isinstance(obj, pd.Timestamp):
        return obj.strftime("%Y-%m-%d")
    return obj


def eur(x) -> int | None:
    """Money is whole euros in the bundle; missing stays null."""
    if x is None or x is pd.NA or (isinstance(x, float) and math.isnan(x)):
        return None
    return int(round(float(x)))


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
