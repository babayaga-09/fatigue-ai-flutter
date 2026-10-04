import numpy as np
import pandas as pd

from touchline.models.valuator import CAT, NUM, baseline_predict, run_valuator


def _rows(n=3000, seed=0):
    rng = np.random.default_rng(seed)
    df = pd.DataFrame({
        "player_id": np.arange(n), "season": rng.integers(2018, 2026, n),
        "age": rng.uniform(18, 34, n), "minutes": rng.uniform(450, 4000, n),
        "apps": rng.integers(5, 50, n), "goals": rng.integers(0, 25, n),
        "assists": rng.integers(0, 15, n), "minutes_share": rng.uniform(0.1, 1, n),
        "yellow": rng.integers(0, 10, n), "prev_minutes": rng.uniform(0, 4000, n),
        "club_elo": rng.normal(1600, 120, n), "height": rng.normal(182, 6, n),
        "position": rng.choice(["Attack", "Midfield", "Defender", "Goalkeeper"], n),
        "sub_position": rng.choice(["Centre-Forward", "Central Midfield", "Centre-Back"], n),
        "league": rng.choice(["GB1", "ES1"], n), "foot": rng.choice(["left", "right"], n)})
    m90 = df.minutes / 90
    df["ga90"] = (df.goals + df.assists) / m90
    df["g90"], df["a90"] = df.goals / m90, df.assists / m90
    df["prev_ga90"] = df.ga90 * rng.uniform(0.7, 1.3, n)
    df.loc[::17, "prev_ga90"] = np.nan  # missing values must be tolerated
    log_v = (15 + 1.2 * df.ga90 + 0.004 * (df.club_elo - 1600) - 0.05 * (df.age - 25) ** 2
             + 0.4 * df.minutes_share + 0.3 * (df.league == "GB1") + rng.normal(0, 0.3, n))
    df["target_value"] = np.exp(log_v)
    return df


def test_run_valuator_beats_baseline_without_leakage():
    rows = _rows()
    model, m = run_valuator(rows, test_season=2025)
    assert m["train_seasons_max"] == 2024 and m["test_season"] == 2025
    assert m["mae_eur"] < m["baseline_mae_eur"]
    assert set(NUM + CAT) <= set(rows.columns)


def test_explain_returns_top_contributions():
    rows = _rows()
    model, _ = run_valuator(rows, test_season=2025)
    test = rows[rows.season == 2025].head(3)
    preds = model.predict(test)
    why = model.explain(test, top=3)
    assert preds.shape == (3,) and (preds > 0).all()
    assert len(why) == 3 and len(why[0]) == 3 and {"f", "effect_pct"} <= set(why[0][0])


def test_baseline_falls_back_to_global_median():
    train = _rows(200)
    test = train.head(2).assign(league="XX")
    assert (baseline_predict(train, test) > 0).all()
