import pytest

from touchline.fpl.scoring import RULES, Components, breakdown, expected_points


def _c(**kw):
    base = dict(p_play=1.0, p60=1.0, e_goals=0.0, e_assists=0.0, p_cs=0.0, e_conceded=0.0,
                e_saves=0.0, e_bonus=0.0, p_dc=0.0, e_yellow=0.0, e_red=0.0)
    return Components(**{**base, **kw})


def test_forward_goal_and_assist():
    r = RULES["2024-25"]
    assert expected_points(_c(e_goals=1), "FWD", r) == pytest.approx(6)
    assert expected_points(_c(e_goals=1, e_assists=1), "FWD", r) == pytest.approx(9)


def test_gk_goal_value_changes_in_2025():
    assert RULES["2024-25"].goal["GK"] == 6 and RULES["2025-26"].goal["GK"] == 10


def test_clean_sheet_needs_sixty_minutes():
    r = RULES["2024-25"]
    assert expected_points(_c(p60=0.0, p_cs=1.0), "DEF", r) == pytest.approx(1)  # appearance
    assert expected_points(_c(p_cs=1.0), "DEF", r) == pytest.approx(6)


def test_goals_conceded_and_saves_for_keeper():
    r = RULES["2024-25"]
    assert expected_points(_c(e_conceded=2, e_saves=6), "GK", r) == pytest.approx(2 - 1 + 2)
    assert expected_points(_c(e_conceded=2), "MID", r) == pytest.approx(2)  # no penalty for MID


def test_breakdown_sums_to_total():
    r = RULES["2025-26"]
    c = _c(p_play=0.9, p60=0.7, e_goals=0.3, e_assists=0.2, p_cs=0.4, e_conceded=1.1,
           e_bonus=0.4, p_dc=0.3, e_yellow=0.1)
    b = breakdown(c, "DEF", r)
    assert set(b) == {"minutes", "attack", "defence", "bonus", "other"}
    assert sum(b.values()) == pytest.approx(expected_points(c, "DEF", r))


def test_dc_only_from_2025_26():
    c = _c(p_dc=1.0)
    assert expected_points(c, "DEF", RULES["2024-25"]) == pytest.approx(2)
    assert expected_points(c, "DEF", RULES["2025-26"]) == pytest.approx(4)
    assert expected_points(c, "GK", RULES["2025-26"]) == pytest.approx(2)  # keepers can't earn DC
