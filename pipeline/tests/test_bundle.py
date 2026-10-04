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
