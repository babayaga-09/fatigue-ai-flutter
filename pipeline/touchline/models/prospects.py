"""F1 — Ready for the Big Five: P(a feeder-league player becomes a regular after moving up).

Trained only on players who did move (the question is conditional on the move). Value is the
last valuation *before* the move, so nothing from after the transfer leaks in."""
from dataclasses import dataclass

import lightgbm as lgb
import numpy as np
import pandas as pd
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import brier_score_loss, roc_auc_score

from touchline.features.players import season_ref_date

FEEDERS = {"NL1": "Eredivisie", "PO1": "Liga Portugal", "BE1": "Pro League",
           "TR1": "Süper Lig", "SC1": "Scottish Premiership", "RU1": "Russian Premier League",
           "UKR1": "Ukrainian Premier League", "GR1": "Greek Super League",
           "DK1": "Danish Superliga"}
REGULAR_SHARE = 0.4
NUM = ["age", "minutes", "minutes_share", "ga90", "g90", "a90", "club_elo", "log_value",
       "prev_ga90"]
CAT = ["position", "league"]
FRIENDLY = {"age": "Age", "minutes": "Minutes played", "minutes_share": "Share of minutes",
            "ga90": "Goal involvements per 90", "g90": "Goals per 90", "a90": "Assists per 90",
            "club_elo": "Club strength", "log_value": "Market value",
            "prev_ga90": "Output the season before", "position": "Position",
            "league": "League"}
_PARAMS = dict(objective="binary", learning_rate=0.03, num_leaves=15, min_child_samples=15,
               colsample_bytree=0.8, subsample=0.8, subsample_freq=1, verbose=-1)


def build_rows(feeder, top5, players, valuations, history) -> pd.DataFrame:
    f = feeder[feeder.minutes >= 900].copy()
    nxt = top5[["player_id", "season", "minutes_share", "ga90"]].rename(
        columns={"minutes_share": "next_share", "ga90": "next_ga90"})
    nxt["season"] = nxt["season"] - 1
    f = f.merge(nxt, on=["player_id", "season"], how="left")
    f["moved"] = f.next_share.notna()
    f["regular"] = (f.next_share >= REGULAR_SHARE).astype(int)
    prev = feeder[["player_id", "season", "ga90"]].rename(columns={"ga90": "prev_ga90"})
    prev["season"] = prev["season"] + 1
    f = f.merge(prev, on=["player_id", "season"], how="left")
    f["ref"] = f.season.map(season_ref_date).astype("datetime64[ns]")
    f = f.merge(players[["player_id", "dob", "position"]], on="player_id", how="left")
    f["age"] = (f.ref - f.dob).dt.days / 365.25
    h = history.rename(columns={"date": "ref", "rating": "club_elo"}).copy()
    h["ref"] = h["ref"].astype("datetime64[ns]")
    h["club_id"] = h["club_id"].astype("int64")
    f["club_id"] = f["club_id"].astype("int64")
    f = pd.merge_asof(f.sort_values("ref"), h.sort_values("ref"), on="ref", by="club_id",
                      direction="backward")
    v = valuations.rename(columns={"value": "mv"}).copy()
    v["ref"] = v["date"].astype("datetime64[ns]")
    v["player_id"] = v["player_id"].astype(f["player_id"].dtype)
    f = pd.merge_asof(f.sort_values("ref"), v[["player_id", "ref", "mv"]].sort_values("ref"),
                      on="ref", by="player_id", direction="backward",
                      tolerance=pd.Timedelta(days=400))
    f["log_value"] = np.log(f.mv.where(f.mv > 0))
    return f.drop(columns=["ref", "dob"]).reset_index(drop=True)


@dataclass
class ProspectModel:
    model: lgb.LGBMClassifier
    categories: dict

    def _x(self, df: pd.DataFrame) -> pd.DataFrame:
        x = df[NUM + CAT].copy()
        for c in NUM:
            x[c] = pd.to_numeric(x[c], errors="coerce").astype(float)
        for c in CAT:
            x[c] = pd.Categorical(x[c], categories=self.categories[c])
        return x

    def predict(self, df: pd.DataFrame) -> np.ndarray:
        return self.model.predict_proba(self._x(df))[:, 1]

    def explain(self, df: pd.DataFrame, top: int = 3) -> list[list[dict]]:
        contrib = self.model.predict(self._x(df), pred_contrib=True)[:, :-1]
        return [[{"f": FRIENDLY[(NUM + CAT)[i]], "effect": float(row[i])}
                 for i in np.argsort(-np.abs(row))[:top]] for row in contrib]


def run_prospects(rows: pd.DataFrame, test_season: int,
                  seed: int = 42) -> tuple[ProspectModel, dict]:
    movers = rows[rows.moved]
    test_s = test_season - 1  # moves whose outcome season is the latest complete season
    train = movers[movers.season <= test_s - 2]
    val = movers[movers.season == test_s - 1]
    test = movers[movers.season == test_s]
    if train.season.max() >= test_s or len(test) == 0 or len(val) == 0:
        raise ValueError("prospects split is empty or leaks")
    categories = {c: sorted(rows[c].dropna().unique().tolist()) for c in CAT}
    probe = ProspectModel(lgb.LGBMClassifier(n_estimators=2000, random_state=seed, **_PARAMS),
                          categories)
    probe.model.fit(probe._x(train), train.regular,
                    eval_X=(probe._x(val),), eval_y=(val.regular,),
                    callbacks=[lgb.early_stopping(100, verbose=False)])
    best = int(probe.model.best_iteration_ or 200)
    fit = pd.concat([train, val])
    final = ProspectModel(lgb.LGBMClassifier(n_estimators=best, random_state=seed, **_PARAMS),
                          categories)
    final.model.fit(final._x(fit), fit.regular)

    def lv(d):
        return d[["log_value"]].fillna(fit.log_value.median()).to_numpy()

    base = LogisticRegression().fit(lv(fit), fit.regular)
    p, pb = final.predict(test), base.predict_proba(lv(test))[:, 1]
    y = test.regular.to_numpy()
    return final, {"n_train": int(len(fit)), "n_test": int(len(test)),
                   "test_moves_season": int(test_s), "positive_rate": float(y.mean()),
                   "auc": float(roc_auc_score(y, p)), "brier": float(brier_score_loss(y, p)),
                   "baseline_auc": float(roc_auc_score(y, pb)),
                   "baseline_brier": float(brier_score_loss(y, pb)), "best_iter": best}


def conversion(rows: pd.DataFrame) -> dict[str, float]:
    """Median top-five G/A per 90 over median feeder G/A per 90 for movers who played."""
    m = rows[rows.moved & (rows.next_share >= 0.25) & (rows.ga90 > 0)]
    overall = float(m.next_ga90.median() / m.ga90.median()) if len(m) else 0.7
    out = {}
    for lg, g in m.groupby("league"):
        if len(g) >= 10 and g.ga90.median() > 0:
            out[lg] = float(g.next_ga90.median() / g.ga90.median())
    return {lg: out.get(lg, overall) for lg in FEEDERS}
