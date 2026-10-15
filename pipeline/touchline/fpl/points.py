"""Expected FPL points per player-fixture: minutes × shrunk per-90 rates × fixture strength,
priced by that season's scoring rules."""
import numpy as np
import pandas as pd

from touchline.fpl.minutes import MinutesModel, apply_availability
from touchline.fpl.scoring import RULES, Components, breakdown

PARTS = ["minutes", "attack", "defence", "bonus", "other"]


def predict_points(rows: pd.DataFrame, minutes_model: MinutesModel) -> pd.DataFrame:
    """rows: one per player-fixture with the walk-forward features (player_gw_features) and the
    fixture strength columns (att_mult, p_cs, lam_against) already joined, plus `season` and
    optionally `chance` (FPL chance_of_playing, NaN when unflagged)."""
    p = minutes_model.predict(rows)
    if "chance" in rows:
        p = apply_availability(p, rows["chance"].to_numpy())
    emin90 = minutes_model.expected_minutes(p) / 90.0
    p_play, p60 = 1.0 - p[:, 0], p[:, 2]
    att = rows["att_mult"].to_numpy()
    comps = pd.DataFrame({
        "p_play": p_play, "p60": p60,
        "e_goals": rows["expected_goals_90"].to_numpy() * att * emin90,
        "e_assists": rows["expected_assists_90"].to_numpy() * att * emin90,
        "p_cs": rows["p_cs"].to_numpy(), "e_conceded": rows["lam_against"].to_numpy(),
        "e_saves": rows["saves_90"].to_numpy() * emin90,
        "e_bonus": rows["bonus_90"].to_numpy() * emin90,
        "p_dc": rows["dc_rate"].to_numpy() * p60,
        "e_yellow": rows["yellow_cards_90"].to_numpy() * emin90,
        "e_red": rows["red_cards_90"].to_numpy() * emin90,
    }, index=rows.index)
    parts = np.array([list(breakdown(Components(**c), pos, RULES[s]).values())
                      for c, pos, s in zip(comps.to_dict("records"), rows["position"],
                                           rows["season"], strict=True)])
    out = rows[["season", "gw", "element"]].copy()
    if "fixture" in rows:
        out["fixture"] = rows["fixture"]
    out[PARTS] = parts
    out["xpts"] = parts.sum(axis=1)
    out["p_play"] = p_play
    return out


def per_gameweek(pred: pd.DataFrame) -> pd.DataFrame:
    """Sum fixtures within a gameweek (double gameweeks); P(play) is the chance of playing in
    at least one."""
    g = pred.groupby(["season", "gw", "element"])
    out = g[["xpts", *PARTS]].sum()
    out["p_play"] = 1.0 - g["p_play"].apply(lambda s: float(np.prod(1.0 - s)))
    return out.reset_index()
