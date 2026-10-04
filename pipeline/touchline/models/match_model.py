"""M2 — match outcome model: Poisson goals driven by Elo gap + Dixon-Coles low-score fix."""
from dataclasses import asdict, dataclass

import numpy as np
from scipy.optimize import minimize_scalar
from scipy.stats import poisson
from sklearn.linear_model import PoissonRegressor


@dataclass
class MatchModel:
    home_coef: tuple[float, float]
    away_coef: tuple[float, float]
    rho: float

    def rates(self, elo_diff):
        d = np.asarray(elo_diff, dtype=float) / 100.0
        lh = np.exp(self.home_coef[0] + self.home_coef[1] * d)
        la = np.exp(self.away_coef[0] + self.away_coef[1] * d)
        return lh, la

    def score_matrices(self, elo_diff, max_goals: int = 10) -> np.ndarray:
        lh, la = self.rates(elo_diff)
        g = np.arange(max_goals + 1)
        ph = poisson.pmf(g[None, :], lh[:, None])
        pa = poisson.pmf(g[None, :], la[:, None])
        m = ph[:, :, None] * pa[:, None, :]
        r = self.rho
        m[:, 0, 0] *= 1 - lh * la * r
        m[:, 0, 1] *= 1 + lh * r
        m[:, 1, 0] *= 1 + la * r
        m[:, 1, 1] *= 1 - r
        m = np.clip(m, 0, None)
        return m / m.sum(axis=(1, 2), keepdims=True)

    def outcome_probs(self, elo_diff) -> np.ndarray:
        m = self.score_matrices(elo_diff)
        home = np.tril(m, -1).sum(axis=(1, 2))
        draw = np.trace(m, axis1=1, axis2=2)
        away = np.triu(m, 1).sum(axis=(1, 2))
        return np.stack([home, draw, away], axis=1)

    def to_dict(self) -> dict:
        return asdict(self)


def _tau(x, y, lh, la, rho):
    t = np.ones_like(lh)
    t = np.where((x == 0) & (y == 0), 1 - lh * la * rho, t)
    t = np.where((x == 0) & (y == 1), 1 + lh * rho, t)
    t = np.where((x == 1) & (y == 0), 1 + la * rho, t)
    t = np.where((x == 1) & (y == 1), 1 - rho, t)
    return t


def fit_match_model(elo_diff, home_goals, away_goals) -> MatchModel:
    d = (np.asarray(elo_diff, dtype=float) / 100.0).reshape(-1, 1)
    hg, ag = np.asarray(home_goals), np.asarray(away_goals)
    rh = PoissonRegressor(alpha=0.0, max_iter=300).fit(d, hg)
    ra = PoissonRegressor(alpha=0.0, max_iter=300).fit(d, ag)
    model = MatchModel((float(rh.intercept_), float(rh.coef_[0])),
                       (float(ra.intercept_), float(ra.coef_[0])), 0.0)
    lh, la = model.rates(d[:, 0] * 100)

    def nll(rho):
        t = _tau(hg, ag, lh, la, rho)
        return np.inf if np.any(t <= 0) else -np.sum(np.log(t))

    model.rho = float(minimize_scalar(nll, bounds=(-0.2, 0.2), method="bounded").x)
    return model


def outcome_index(hg, ag) -> np.ndarray:
    hg, ag = np.asarray(hg), np.asarray(ag)
    return np.where(hg > ag, 0, np.where(hg == ag, 1, 2))


def rps(p, y) -> float:
    o = np.eye(3)[np.asarray(y)]
    cp, co = np.cumsum(p, 1)[:, :2], np.cumsum(o, 1)[:, :2]
    return float(np.mean(np.sum((cp - co) ** 2, axis=1) / 2))


def log_loss(p, y) -> float:
    return float(-np.mean(np.log(np.clip(p[np.arange(len(y)), np.asarray(y)], 1e-12, 1))))


def brier(p, y) -> float:
    o = np.eye(3)[np.asarray(y)]
    return float(np.mean(np.sum((p - o) ** 2, axis=1)))


def evaluate(model: MatchModel, train, test) -> dict:
    y = outcome_index(test.home_goals, test.away_goals)
    p = model.outcome_probs(test.d.to_numpy())
    base = np.bincount(outcome_index(train.home_goals, train.away_goals),
                       minlength=3) / len(train)
    pb = np.tile(base, (len(test), 1))
    return {"n_test": int(len(test)), "rps": rps(p, y), "log_loss": log_loss(p, y),
            "brier": brier(p, y), "baseline_rps": rps(pb, y),
            "baseline_log_loss": log_loss(pb, y), "baseline_brier": brier(pb, y),
            "rho": model.rho}
