from touchline.run import check_gates


def test_gates_pass_and_fail():
    ok = {"club_elo": {"favourite_accuracy": 0.6, "baseline_home_pick_accuracy": 0.55},
          "match_model": {"rps": 0.20, "baseline_rps": 0.23},
          "valuator": {"mae_eur": 3e6, "baseline_mae_eur": 6e6},
          "form": {"poisson_deviance": 1.0, "baseline_poisson_deviance": 1.2}}
    assert check_gates(ok) == []
    bad = {**ok, "valuator": {"mae_eur": 7e6, "baseline_mae_eur": 6e6}}
    fails = check_gates(bad)
    assert len(fails) == 1 and "valuator" in fails[0]
