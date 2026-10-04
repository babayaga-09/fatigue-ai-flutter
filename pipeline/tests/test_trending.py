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
    assert "5 goal involvements in last 5" in t.loc[1, "reasons"]
    assert any("Value up" in r for r in t.loc[1, "reasons"])
