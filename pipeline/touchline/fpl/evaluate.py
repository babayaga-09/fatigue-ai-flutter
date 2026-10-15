"""Hold-out evaluation against FPL's own expected points (xP) and the shipping gate."""
import numpy as np
import pandas as pd
from scipy.stats import spearmanr


def eval_rows(actual: pd.DataFrame) -> pd.Series:
    """Player-gameweeks that count: the player had minutes in any of his previous 3 gameweeks
    (squad-relevant players, not the 400 who never play)."""
    return actual.min_last3 > 0


def evaluate(pred_gw: pd.DataFrame, actual: pd.DataFrame, top_k: int = 15) -> dict:
    """pred_gw: per (season, gw, element) xpts; actual: per (season, gw, element) with
    total_points, xP, selected, min_last3."""
    d = actual.merge(pred_gw[["season", "gw", "element", "xpts"]],
                     on=["season", "gw", "element"], how="inner")
    d = d[eval_rows(d)]
    err, err_fpl = (d.xpts - d.total_points).abs(), (d.xP - d.total_points).abs()
    cap, cap_fpl = 0.0, 0.0
    for _, g in d.groupby(["season", "gw"]):
        pool = g.nlargest(top_k, "selected")
        cap += 2 * pool.loc[pool.xpts.idxmax(), "total_points"]
        cap_fpl += 2 * pool.loc[pool.xP.idxmax(), "total_points"]
    return {
        "n": int(len(d)), "mae": float(err.mean()), "mae_fpl": float(err_fpl.mean()),
        "spearman": float(spearmanr(d.xpts, d.total_points).statistic),
        "spearman_fpl": float(spearmanr(d.xP, d.total_points).statistic),
        "captain_points": float(cap), "captain_points_fpl": float(cap_fpl),
        "gameweeks": int(d.groupby(["season", "gw"]).ngroups),
    }


def gate(m: dict) -> str:
    """Ship our numbers only if they beat FPL's on accuracy and on the captain decision."""
    return "ours" if m["mae"] < m["mae_fpl"] and m["captain_points"] > m["captain_points_fpl"] \
        else "fpl"


def bootstrap_mae_gain(pred_gw, actual, n=1000, seed=0) -> list[float]:
    """95% interval for FPL's MAE minus ours, resampling gameweeks."""
    d = actual.merge(pred_gw[["season", "gw", "element", "xpts"]],
                     on=["season", "gw", "element"])
    d = d[eval_rows(d)]
    d["gain"] = (d.xP - d.total_points).abs() - (d.xpts - d.total_points).abs()
    by_gw = d.groupby(["season", "gw"]).gain.agg(["sum", "count"]).to_numpy()
    rng = np.random.default_rng(seed)
    boots = []
    for _ in range(n):
        s = by_gw[rng.integers(0, len(by_gw), len(by_gw))]
        boots.append(s[:, 0].sum() / s[:, 1].sum())
    return [float(np.percentile(boots, 2.5)), float(np.percentile(boots, 97.5))]
