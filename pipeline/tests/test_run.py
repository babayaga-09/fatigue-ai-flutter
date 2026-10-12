from touchline.run import check_gates


def test_gates_pass_and_fail():
    ok = {"club_elo": {"favourite_accuracy": 0.6, "baseline_home_pick_accuracy": 0.55},
          "match_model": {"rps": 0.20, "baseline_rps": 0.23},
          "valuator": {"mae_eur": 3e6, "baseline_mae_eur": 6e6},
          "form": {"poisson_deviance": 1.0, "baseline_poisson_deviance": 1.2},
          "career": {"mae_h1": 0.3, "baseline_mae_h1": 0.4}}
    assert check_gates(ok) == []
    bad = {**ok, "valuator": {"mae_eur": 7e6, "baseline_mae_eur": 6e6}}
    fails = check_gates(bad)
    assert len(fails) == 1 and "valuator" in fails[0]


def test_missing_token_without_offline_flag_fails_loudly():
    import pytest

    from touchline.run import use_live_clubs
    assert use_live_clubs(offline=False, token="abc") is True
    assert use_live_clubs(offline=True, token="") is False
    with pytest.raises(SystemExit):
        use_live_clubs(offline=False, token="")


def test_latest_complete_season_skips_partial_season():
    import pandas as pd

    from touchline.run import latest_complete_season
    games = pd.DataFrame({"competition_id": ["GB1"] * 3, "season": [2024, 2024, 2025],
                          "date": pd.to_datetime(["2024-08-10", "2025-05-25", "2025-09-01"])})
    assert latest_complete_season(games) == 2024


def test_v2_gates_included():
    from touchline.run import GATES
    # prospects has no hard gate: it falls back to the price-only ranking when the model
    # doesn't beat it on the rolling evaluation (see models/prospects.py)
    assert "career" in {g[0] for g in GATES}
