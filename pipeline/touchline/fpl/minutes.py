"""Minutes model: P(no minutes), P(1-59), P(60+) per player-fixture.

Minutes drive most FPL points (appearance, clean sheets, and every per-90 rate), and rotation
is the hard part, so this is the one learned classifier in the component model."""
from dataclasses import dataclass

import lightgbm as lgb
import numpy as np
import pandas as pd

FEATURES = ["min_last1", "min_last3", "min_last6", "starts_last3", "starts_last6",
            "played_share", "gws_seen", "value", "position"]
POSITIONS = ["GK", "DEF", "MID", "FWD"]
_PARAMS = dict(objective="multiclass", num_class=3, learning_rate=0.05, num_leaves=31,
               min_child_samples=50, colsample_bytree=0.8, subsample=0.8, subsample_freq=1,
               verbose=-1)


def minutes_class(minutes) -> np.ndarray:
    m = np.asarray(minutes)
    return np.where(m <= 0, 0, np.where(m < 60, 1, 2))


def _x(d: pd.DataFrame) -> pd.DataFrame:
    x = d[FEATURES].copy()
    x["position"] = pd.Categorical(x["position"], categories=POSITIONS)
    return x


@dataclass
class MinutesModel:
    model: lgb.LGBMClassifier
    mins_sub: float   # mean minutes when 1-59
    mins_full: float  # mean minutes when 60+

    def predict(self, d: pd.DataFrame) -> np.ndarray:
        return self.model.predict_proba(_x(d))

    def expected_minutes(self, p: np.ndarray) -> np.ndarray:
        return p[:, 1] * self.mins_sub + p[:, 2] * self.mins_full


def fit_minutes(train: pd.DataFrame, val: pd.DataFrame, seed: int = 42) -> MinutesModel:
    yt, yv = minutes_class(train.minutes), minutes_class(val.minutes)
    probe = lgb.LGBMClassifier(n_estimators=2000, random_state=seed, **_PARAMS)
    probe.fit(_x(train), yt, eval_X=(_x(val),), eval_y=(yv,),
              callbacks=[lgb.early_stopping(50, verbose=False)])
    best = int(probe.best_iteration_ or 200)
    both = pd.concat([train, val])
    final = lgb.LGBMClassifier(n_estimators=best, random_state=seed, **_PARAMS)
    final.fit(_x(both), minutes_class(both.minutes))
    m = both.minutes
    return MinutesModel(final, float(m[(m > 0) & (m < 60)].mean()), float(m[m >= 60].mean()))


def brier_multi(p: np.ndarray, y: np.ndarray) -> float:
    onehot = np.eye(3)[np.asarray(y)]
    return float(np.mean(np.sum((p - onehot) ** 2, axis=1)))


def baseline_last_gw(d: pd.DataFrame) -> np.ndarray:
    """Whatever happened last gameweek happens again (softened)."""
    c = minutes_class(d.min_last1)
    p = np.full((len(d), 3), 0.1)
    p[np.arange(len(d)), c] = 0.8
    return p


def apply_availability(p: np.ndarray, chance: np.ndarray) -> np.ndarray:
    """FPL's chance_of_playing (0-100, NaN = no flag) caps the chance of any minutes."""
    p = np.array(p, dtype=float, copy=True)
    c = np.asarray(chance, dtype=float)
    flagged = ~np.isnan(c)
    cap = np.where(flagged, c / 100.0, 1.0)
    play = 1.0 - p[:, 0]
    scale = np.where(play > cap, cap / np.where(play > 0, play, 1.0), 1.0)
    p[:, 1:] *= scale[:, None]
    p[:, 0] = 1.0 - p[:, 1:].sum(axis=1)
    return p
