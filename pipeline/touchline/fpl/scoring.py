"""FPL scoring rules by season, and expected points from per-event expectations.

Expected points are linear in the components: the expectation of a sum is the sum of the
expectations, so each event is priced at its rule value times its expected count."""
from dataclasses import dataclass, field

POSITIONS = ("GK", "DEF", "MID", "FWD")


@dataclass(frozen=True)
class Rules:
    goal: dict
    clean_sheet: dict
    dc_threshold: dict = field(default_factory=dict)  # empty = no defensive-contribution points
    assist: int = 3
    appear: int = 1
    appear60: int = 1
    saves_per_point: int = 3
    conceded_per_minus: int = 2
    dc_points: int = 2
    yellow: int = -1
    red: int = -3


_GOAL_OLD = {"GK": 6, "DEF": 6, "MID": 5, "FWD": 4}
_GOAL_NEW = {"GK": 10, "DEF": 6, "MID": 5, "FWD": 4}
_CS = {"GK": 4, "DEF": 4, "MID": 1, "FWD": 0}
_DC = {"DEF": 10, "MID": 12, "FWD": 12}

RULES: dict[str, Rules] = {
    **{s: Rules(_GOAL_OLD, _CS) for s in ("2022-23", "2023-24", "2024-25")},
    **{s: Rules(_GOAL_NEW, _CS, _DC) for s in ("2025-26", "2026-27")},
}


@dataclass(frozen=True)
class Components:
    p_play: float      # P(any minutes)
    p60: float         # P(60+ minutes)
    e_goals: float
    e_assists: float
    p_cs: float        # P(clean sheet) for his team in this fixture
    e_conceded: float  # expected goals conceded by his team
    e_saves: float
    e_bonus: float
    p_dc: float        # P(reaching the defensive-contribution threshold)
    e_yellow: float
    e_red: float


def breakdown(c: Components, pos: str, r: Rules) -> dict[str, float]:
    gk_def = pos in ("GK", "DEF")
    defence = c.p_cs * c.p60 * r.clean_sheet[pos]
    if gk_def:
        defence -= c.e_conceded * c.p60 / r.conceded_per_minus
    other = c.e_yellow * r.yellow + c.e_red * r.red
    if pos == "GK":
        other += c.e_saves / r.saves_per_point
    if pos in r.dc_threshold:
        other += c.p_dc * r.dc_points
    return {
        "minutes": c.p_play * r.appear + c.p60 * r.appear60,
        "attack": c.e_goals * r.goal[pos] + c.e_assists * r.assist,
        "defence": defence,
        "bonus": c.e_bonus,
        "other": other,
    }


def expected_points(c: Components, pos: str, r: Rules) -> float:
    return sum(breakdown(c, pos, r).values())
