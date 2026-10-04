"""M6 — workload risk index (not an injury probability: the dataset has no injury labels).

Combines season minutes, congested appearances (<4 days' rest) and the acute:chronic workload
ratio (7-day minutes vs 28-day weekly average). An Isolation Forest flags unusual loads."""
import numpy as np
import pandas as pd
from sklearn.ensemble import IsolationForest

_COLS = ["player_id", "ref_date", "season_minutes", "congested_apps", "acute", "chronic", "acwr"]
_FEATS = ["season_minutes", "congested_apps", "acwr", "age"]


def workload_table(apps: pd.DataFrame, players: pd.DataFrame, season_start: pd.Timestamp,
                   ids) -> pd.DataFrame:
    a = apps[apps.player_id.isin(ids)].sort_values(["player_id", "date"]).copy()
    a["rest"] = a.groupby("player_id")["date"].diff().dt.days
    rows = []
    for pid, g in a.groupby("player_id"):
        season = g[g.date >= season_start]
        if season.empty:
            continue
        ref = g.date.max()
        acute = g.loc[g.date > ref - pd.Timedelta(days=7), "minutes"].sum()
        chronic = g.loc[g.date > ref - pd.Timedelta(days=28), "minutes"].sum() / 4.0
        rows.append({"player_id": pid, "ref_date": ref,
                     "season_minutes": float(season.minutes.sum()),
                     "congested_apps": int((season.rest < 4).sum()),
                     "acute": float(acute), "chronic": float(chronic),
                     "acwr": float(acute / chronic) if chronic > 0 else 0.0})
    w = pd.DataFrame(rows, columns=_COLS)
    if w.empty:
        return w.assign(age=[], index=[], band=[], flag=[])
    dob = players.set_index("player_id")["dob"]
    w["age"] = [(r - dob.get(p)).days / 365.25 if pd.notna(dob.get(p)) else np.nan
                for p, r in zip(w.player_id, w.ref_date, strict=True)]

    def pct(s):
        return s.rank(pct=True)

    w["index"] = (100 * (0.5 * pct(w.season_minutes) + 0.3 * pct(w.congested_apps)
                         + 0.2 * pct(w.acwr))).round(0)
    w["band"] = pd.cut(w["index"], [-1, 30, 60, 80, 101],
                       labels=["Light", "Normal", "High", "Heavy"]).astype(str)
    feats = w[_FEATS].fillna(w[_FEATS].median())
    if len(w) >= 20:
        unusual = IsolationForest(contamination=0.05, random_state=0).fit_predict(feats) == -1
    else:
        unusual = np.zeros(len(w), bool)
    w["flag"] = unusual & (w["index"] >= 60)
    return w.reset_index(drop=True)
