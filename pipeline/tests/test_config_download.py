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
