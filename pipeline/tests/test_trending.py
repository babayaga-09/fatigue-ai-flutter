import numpy as np
import pandas as pd

from touchline.models.trending import trending


def test_hot_player_ranks_first_with_reasons():
    df = pd.DataFrame({
        "player_id": [1, 2, 3, 4], "minutes": [2500, 2500, 2500, 300],
        "ga90": [0.4, 0.4, 0.4, 0.4], "last5_ga": [5, 1, 0, 5], "last5_minutes": [450] * 4,
        "value_now": [60e6, 30e6, 20e6, 5e6], "value_6m_ago": [40e6, 30e6, 25e6, 5e6],
        "forecast_ga5": [3.0, 1.0, 0.5, 2.0]})
    t = trending(df).set_index("player_id")
    assert t.trend_score.idxmax() == 1
    assert np.isnan(t.loc[4, "trend_score"])
    assert "5 G/A last 5" in t.loc[1, "reasons"]
    assert any("Value up" in r for r in t.loc[1, "reasons"])


def test_unqualified_players_get_no_reasons():
    df = pd.DataFrame({
        "player_id": [1, 2, 3], "minutes": [2500, 2500, 300], "ga90": [0.4, 0.4, 0.4],
        "last5_ga": [5, 1, 5], "last5_minutes": [450] * 3,
        "value_now": [60e6, 30e6, 5e6], "value_6m_ago": [40e6, 30e6, 1e6],
        "forecast_ga5": [3.0, 1.0, 2.5]})
    t = trending(df).set_index("player_id")
    assert t.loc[3, "reasons"] == []


def test_small_value_rises_get_one_decimal_and_tiny_ones_none():
    df = pd.DataFrame({
        "player_id": [1, 2], "minutes": [2500, 2500], "ga90": [0.2, 0.2],
        "last5_ga": [0, 0], "last5_minutes": [450, 450],
        "value_now": [1.4e6, 330e3], "value_6m_ago": [1.0e6, 300e3],
        "forecast_ga5": [0.5, 0.5]})
    t = trending(df).set_index("player_id")
    assert "Value up €0.4M" in t.loc[1, "reasons"]
    assert t.loc[2, "reasons"] == []  # +€30k is not news


def test_every_reason_fits_a_tile_line():
    df = pd.DataFrame({
        "player_id": [1], "minutes": [2500], "ga90": [0.4], "last5_ga": [12],
        "last5_minutes": [450], "value_now": [180e6], "value_6m_ago": [100e6],
        "forecast_ga5": [4.25]})
    reasons = trending(df).loc[0, "reasons"]
    assert reasons and all(len(r) <= 14 for r in reasons), reasons
