import numpy as np
import pandas as pd

from touchline.models.workload import workload_table


def _apps():
    rows = []
    start = pd.Timestamp("2025-08-10")
    for pid, gap, mins in [(1, 3, 90), (2, 7, 90), (3, 14, 30)]:
        d = start
        while d < pd.Timestamp("2026-05-20"):
            rows.append({"player_id": pid, "date": d, "minutes": mins})
            d += pd.Timedelta(days=gap)
    return pd.DataFrame(rows)


def test_heavier_schedule_scores_higher():
    players = pd.DataFrame({"player_id": [1, 2, 3], "dob": pd.to_datetime(["1995-01-01"] * 3)})
    w = workload_table(_apps(), players, pd.Timestamp("2025-07-01"), ids=[1, 2, 3])
    w = w.set_index("player_id")
    assert w.loc[1, "index"] > w.loc[2, "index"] > w.loc[3, "index"]
    assert w.loc[1, "congested_apps"] > 0 and w.loc[2, "congested_apps"] == 0
    assert w.loc[1, "band"] == "Heavy"
    assert np.isclose(w.loc[2, "acwr"], w.loc[2, "acute"] / w.loc[2, "chronic"])


def test_player_without_appearances_is_absent_not_crashing():
    players = pd.DataFrame({"player_id": [1, 9], "dob": [pd.Timestamp("1995-01-01"), pd.NaT]})
    w = workload_table(_apps(), players, pd.Timestamp("2025-07-01"), ids=[1, 9])
    assert list(w.player_id) == [1]
