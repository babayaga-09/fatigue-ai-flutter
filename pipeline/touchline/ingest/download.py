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
                        f.writelines(r.iter_bytes(1 << 20))
                tmp.replace(path)
            paths.append(path)
    finally:
        if own:
            client.close()
    return paths
