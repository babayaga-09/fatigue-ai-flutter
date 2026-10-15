import numpy as np
import pandas as pd
import pytest

from touchline.fpl.features import (
    fixture_strength,
    gw_table,
    player_gw_features,
    position_priors,
)
from touchline.models.match_model import MatchModel


def _arch(n_gw=8, season="2024-25"):
    rows = []
    for gw in range(1, n_gw + 1):
        for el, name, pos, team, mins, xg in [
            (1, "Striker", "FWD", "Arsenal", 90, 0.6),
            (2, "Bench", "FWD", "Arsenal", 0, 0.0),
            (3, "Fullback", "DEF", "Chelsea", 90, 0.05),
            (4, "Target man", "FWD", "Chelsea", 90, 0.2),
        ]:
            rows.append(dict(season=season, gw=gw, element=el, name=name, position=pos,
                             team=team, opponent_team=2, fixture=gw, was_home=True,
                             kickoff_time=pd.Timestamp("2024-08-10", tz="UTC")
                             + pd.Timedelta(days=7 * gw),
                             minutes=mins, starts=int(mins > 0), total_points=2, xP=2.0,
                             expected_goals=xg, expected_assists=0.1, goals_scored=0,
                             assists=0, clean_sheets=0, goals_conceded=1, saves=0, bonus=0,
                             yellow_cards=0, red_cards=0, defensive_contribution=0, value=60,
                             selected=100))
    return pd.DataFrame(rows)


def _feats(arch):
    g = gw_table(arch)
    return player_gw_features(g, position_priors(g))


def test_features_never_use_current_or_future_gameweeks():
    a = _arch()
    base = _feats(a).query("gw == 5").set_index("element")
    b = a.copy()
    b.loc[b.gw >= 5, ["minutes", "expected_goals"]] = [0, 9.0]
    changed = _feats(b).query("gw == 5").set_index("element")
    cols = ["min_last1", "min_last3", "starts_last3", "expected_goals_90", "played_share"]
    pd.testing.assert_frame_equal(base[cols], changed[cols])


def test_shrinkage_pulls_small_samples_to_position_prior():
    a = _arch()
    f = _feats(a)
    pri = position_priors(gw_table(a))
    early = f.query("gw == 2 and element == 1").expected_goals_90.item()
    late = f.query("gw == 8 and element == 1").expected_goals_90.item()
    # one game in, the striker sits between the prior and his true 0.6/90; later, closer to 0.6
    assert pri["FWD"]["expected_goals"] < early < late < 0.6 + 1e-9


def test_new_player_gets_prior_rates_and_zero_history():
    f = _feats(_arch())
    first = f.query("gw == 1 and element == 3").iloc[0]
    assert first.min_last1 == 0 and first.played_share == 0
    assert first.expected_goals_90 == pytest.approx(
        position_priors(gw_table(_arch()))["DEF"]["expected_goals"])


def test_transfer_mid_season_rates_follow_player():
    a = _arch()
    a.loc[(a.element == 1) & (a.gw >= 5), "team"] = "Chelsea"
    f = _feats(a).query("element == 1").set_index("gw")
    assert f.loc[6, "team"] == "Chelsea"
    assert f.loc[6, "expected_goals_90"] > f.loc[3, "expected_goals_90"]  # history carried


def test_fixture_strength_prefers_stronger_side():
    model = MatchModel(home_coef=(0.3, 0.25), away_coef=(0.1, -0.25), rho=-0.05)
    fixtures = pd.DataFrame({"id": [1], "event": [1], "team_h": [1], "team_a": [2],
                             "kickoff_time": [pd.Timestamp("2024-09-01", tz="UTC")]})
    hist = pd.DataFrame({"date": pd.to_datetime(["2024-08-01", "2024-08-01"]),
                         "club_id": [11, 1123], "rating": [1900.0, 1500.0]})
    s = fixture_strength(fixtures, {1: "Arsenal", 2: "Norwich"}, hist, model).set_index("team")
    assert s.loc[1, "lam_for"] > s.loc[2, "lam_for"]
    assert s.loc[1, "p_cs"] > s.loc[2, "p_cs"]
    assert np.isclose(s.loc[1, "lam_against"], s.loc[2, "lam_for"])
