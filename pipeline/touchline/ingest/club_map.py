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
_COLOURS = Path(__file__).with_name("club_colours.json")


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


def load_club_colours() -> dict[int, list[str]]:
    return {int(k): v for k, v in json.loads(_COLOURS.read_text()).items()}
