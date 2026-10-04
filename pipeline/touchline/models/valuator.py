"""M4 — fair market value from performance, with per-player TreeSHAP explanations."""
from dataclasses import dataclass

import lightgbm as lgb
import numpy as np
import pandas as pd

NUM = ["age", "minutes", "apps", "goals", "assists", "ga90", "g90", "a90", "minutes_share",
       "yellow", "prev_minutes", "prev_ga90", "club_elo", "height"]
CAT = ["position", "sub_position", "league", "foot"]
FRIENDLY = {
    "age": "Age", "minutes": "Minutes played", "apps": "Appearances", "goals": "Goals",
    "assists": "Assists", "ga90": "Goal involvements per 90", "g90": "Goals per 90",
    "a90": "Assists per 90", "minutes_share": "Share of league minutes", "yellow": "Yellow cards",
    "prev_minutes": "Minutes last season", "prev_ga90": "Output last season",
    "club_elo": "Club strength", "height": "Height", "position": "Position",
    "sub_position": "Role", "league": "League", "foot": "Preferred foot",
}
_PARAMS = dict(objective="regression", learning_rate=0.05, num_leaves=31, min_child_samples=40,
               colsample_bytree=0.8, subsample=0.8, subsample_freq=1, verbose=-1)


@dataclass
class Valuator:
    model: lgb.LGBMRegressor
    categories: dict

    def _x(self, df: pd.DataFrame) -> pd.DataFrame:
        x = df[NUM + CAT].copy()
        for c in NUM:
            x[c] = pd.to_numeric(x[c], errors="coerce").astype(float)
        for c in CAT:
            x[c] = pd.Categorical(x[c], categories=self.categories[c])
        return x

    def predict(self, df: pd.DataFrame) -> np.ndarray:
        return np.exp(self.model.predict(self._x(df)))

    def explain(self, df: pd.DataFrame, top: int = 4) -> list[list[dict]]:
        contrib = self.model.predict(self._x(df), pred_contrib=True)[:, :-1]  # drop bias column
        out = []
        for row in contrib:
            order = np.argsort(-np.abs(row))[:top]
            out.append([{"f": FRIENDLY[(NUM + CAT)[i]], "effect_pct": float(np.expm1(row[i]))}
                        for i in order])
        return out


def _band(age):
    return pd.cut(age, [0, 21, 24, 27, 30, 50], labels=False)


def baseline_predict(train: pd.DataFrame, test: pd.DataFrame) -> np.ndarray:
    keys = ["band", "position", "league"]
    tr = train.assign(band=_band(train.age), logv=np.log(train.target_value))
    med = tr.groupby(keys, dropna=False)["logv"].median().rename("m").reset_index()
    te = test.assign(band=_band(test.age)).merge(med, on=keys, how="left")
    return np.exp(te["m"].fillna(tr.logv.median()).to_numpy())


def _metrics(y, p) -> dict:
    ape = np.abs(p - y) / y
    return {"mae_eur": float(np.mean(np.abs(p - y))), "mdape": float(np.median(ape))}


def run_valuator(rows: pd.DataFrame, test_season: int, seed: int = 42) -> tuple[Valuator, dict]:
    categories = {c: sorted(rows[c].dropna().unique().tolist()) for c in CAT}
    train = rows[rows.season <= test_season - 2]
    val = rows[rows.season == test_season - 1]
    test = rows[rows.season == test_season]
    assert train.season.max() < test_season and val.season.max() < test_season

    probe = Valuator(lgb.LGBMRegressor(n_estimators=3000, random_state=seed, **_PARAMS),
                     categories)
    probe.model.fit(probe._x(train), np.log(train.target_value),
                    eval_X=(probe._x(val),), eval_y=(np.log(val.target_value),),
                    callbacks=[lgb.early_stopping(100, verbose=False)])
    best = int(probe.model.best_iteration_ or 500)

    fit_rows = pd.concat([train, val])
    final = Valuator(lgb.LGBMRegressor(n_estimators=best, random_state=seed, **_PARAMS),
                     categories)
    final.model.fit(final._x(fit_rows), np.log(fit_rows.target_value))

    y = test.target_value.to_numpy()
    p = final.predict(test)
    b = baseline_predict(fit_rows, test)
    m, mb = _metrics(y, p), _metrics(y, b)
    ly = np.log(y)
    r2 = 1 - np.sum((ly - np.log(p)) ** 2) / np.sum((ly - ly.mean()) ** 2)
    return final, {"test_season": test_season, "n_test": int(len(test)),
                   "train_seasons_max": int(fit_rows.season.max()), "best_iter": best,
                   **m, "r2_log": float(r2),
                   "baseline_mae_eur": mb["mae_eur"], "baseline_mdape": mb["mdape"]}
