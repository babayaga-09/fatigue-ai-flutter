from datetime import UTC, datetime

import pandas as pd

from touchline.fpl.points import PARTS
from touchline.fpl.run_fpl import build_bundle, next_gameweek


def _events():
    return [
        {"id": 6, "name": "Gameweek 6", "deadline_time": "2026-10-03T10:00:00Z",
         "finished": True},
        {"id": 7, "name": "Gameweek 7", "deadline_time": "2026-10-17T10:00:00Z",
         "finished": False},
        {"id": 8, "name": "Gameweek 8", "deadline_time": "2026-10-24T10:00:00Z",
         "finished": False},
    ]


def test_next_gameweek_skips_passed_deadlines():
    assert next_gameweek(_events(), datetime(2026, 10, 15, tzinfo=UTC))["id"] == 7
    # deadline passed but gameweek not finished yet -> plan for the following one
    assert next_gameweek(_events(), datetime(2026, 10, 18, tzinfo=UTC))["id"] == 8
    assert next_gameweek(_events(), datetime(2027, 1, 1, tzinfo=UTC)) is None


def _boot():
    players = []
    i = 0
    for t in range(1, 7):
        for pos, n in [(1, 2), (2, 5), (3, 5), (4, 3)]:
            for _ in range(n):
                i += 1
                players.append({"id": i, "web_name": f"P{i}", "first_name": "A",
                                "second_name": f"P{i}", "team": t, "element_type": pos,
                                "now_cost": 45 + i % 30, "status": "a", "news": "",
                                "chance_of_playing_next_round": None, "removed": False,
                                "selected_by_percent": "1.0", "ep_next": "3.5"})
    teams = [{"id": t, "name": n, "short_name": n[:3].upper()} for t, n in
             enumerate(["Arsenal", "Chelsea", "Spurs", "Fulham", "Everton", "Leeds"], 1)]
    return {"elements": players, "teams": teams, "events": _events()}


def _pred(boot, blank_team=None):
    rows = []
    for e in boot["elements"]:
        for g in (7, 8):
            if e["team"] == blank_team and g == 8:
                continue  # blank gameweek: no fixture, no row
            rows.append({"element": e["id"], "gw": g, "xpts": 2.0 + e["id"] % 5, "p_play": 0.9,
                         **dict.fromkeys(PARTS, 0.4)})
    return pd.DataFrame(rows)


def test_blank_gameweek_gives_zero_and_bundle_shape():
    boot = _boot()
    b = build_bundle(boot, _events()[1], [7, 8], _pred(boot, blank_team=1), {"mae": 1.8},
                     "ours", datetime(2026, 10, 15, tzinfo=UTC), "2026-27")
    p1 = next(p for p in b["players"] if p["team"] == 1)
    assert p1["xpts"][1] == 0.0 and p1["xpts"][0] > 0
    assert b["next_gw"] == 7 and b["source"] == "ours" and p1["why"]["attack"] == 0.4
    assert len(b["wildcard"]) == 16 and all(len(w["squad"]) == 15 for w in b["wildcard"])
    assert {f["gw"] for f in b["free_hit"]} == {7, 8}


def test_fpl_source_ships_ep_next_without_our_breakdown():
    boot = _boot()
    b = build_bundle(boot, _events()[1], [7, 8], _pred(boot), {}, "fpl",
                     datetime(2026, 10, 15, tzinfo=UTC), "2026-27")
    p = b["players"][0]
    assert p["xpts"] == [3.5, 3.5] and p["why"] is None


def test_fixture_labels_cover_blanks_and_doubles():
    from touchline.fpl.run_fpl import fixture_labels
    teams = {1: {"short_name": "ARS"}, 2: {"short_name": "CHE"}, 3: {"short_name": "LIV"}}
    fx = [{"event": 7, "team_h": 1, "team_a": 2, "kickoff_time": "a"},
          {"event": 8, "team_h": 3, "team_a": 1, "kickoff_time": "b"},
          {"event": 8, "team_h": 1, "team_a": 2, "kickoff_time": "c"}]
    f = fixture_labels(teams, fx, [7, 8])
    assert f[1] == ["CHE (H)", "LIV (A), CHE (H)"]
    assert f[3] == ["", "ARS (H)"]
