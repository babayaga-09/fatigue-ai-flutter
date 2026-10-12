"""F1 — Ready for the Big Five: P(a feeder-league player becomes a regular after moving up).

Trained only on players who did move (the question is conditional on the move), including
those who moved and never got a game. Value is the last valuation before the transfer (or
before the season ends, for players who haven't moved), so nothing after the move leaks in."""
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


def _transfer_moves(transfers, top5_clubs) -> pd.DataFrame:
    """Transfers to a club playing top-five league football next season. A move dated from
    January to September of year Y feeds season Y (labelled Y); the feeder season is Y-1."""
    t = transfers.dropna(subset=["to_club_id"]).copy()
    d = pd.to_datetime(t.date)
    t = t[d.dt.month <= 9]
    t["season"] = pd.to_datetime(t.date).dt.year
    t["club_id"] = t.to_club_id.astype("int64")
    t = t.merge(top5_clubs.astype({"club_id": "int64"}), on=["season", "club_id"])
    t["season"] = t.season - 1
    return (t.groupby(["player_id", "season"]).date.min().rename("move_date").reset_index())


def build_rows(feeder, top5, players, valuations, history, transfers=None,
               top5_clubs=None) -> pd.DataFrame:
    """One row per feeder-league season with 900+ minutes. A player 'moved' if a transfer took
    him to a top-five club or he played top-five league football the next season; he became a
    'regular' with 40%+ of his club's league minutes (zero minutes counts as not)."""
    f = feeder[feeder.minutes >= 900].copy()
    nxt = top5[["player_id", "season", "minutes_share", "ga90"]].rename(
        columns={"minutes_share": "next_share", "ga90": "next_ga90"})
    nxt["season"] = nxt["season"] - 1
    f = f.merge(nxt, on=["player_id", "season"], how="left")
    if transfers is not None and top5_clubs is not None:
        mv = _transfer_moves(transfers, top5_clubs)
        f = f.merge(mv.astype({"player_id": f.player_id.dtype}), on=["player_id", "season"],
                    how="left")
    else:
        f["move_date"] = pd.NaT
    f["moved"] = f.next_share.notna() | f.move_date.notna()
    f["regular"] = (f.next_share.fillna(0) >= REGULAR_SHARE).astype(int)
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
    v["vref"] = v["date"].astype("datetime64[ns]")
    v["player_id"] = v["player_id"].astype(f["player_id"].dtype)
    # value as known before the move: the day before the transfer when it came first
    move = pd.to_datetime(f.move_date).astype("datetime64[ns]") - pd.Timedelta(days=1)
    f["vref"] = move.where(move < f.ref, f.ref)
    f = pd.merge_asof(f.sort_values("vref"), v[["player_id", "vref", "mv"]].sort_values("vref"),
                      on="vref", by="player_id", direction="backward",
                      tolerance=pd.Timedelta(days=400))
    f["log_value"] = np.log(f.mv.where(f.mv > 0))
    return f.drop(columns=["ref", "vref", "dob", "move_date"]).reset_index(drop=True)


@dataclass
class ProspectModel:
    model: lgb.LGBMClassifier | None
    categories: dict
    base: LogisticRegression | None = None  # set when price alone ranks better
    value_fill: float = 0.0

    def _x(self, df: pd.DataFrame) -> pd.DataFrame:
        x = df[NUM + CAT].copy()
        for c in NUM:
            x[c] = pd.to_numeric(x[c], errors="coerce").astype(float)
        for c in CAT:
            x[c] = pd.Categorical(x[c], categories=self.categories[c])
        return x

    def predict(self, df: pd.DataFrame) -> np.ndarray:
        if self.base is not None:
            return self.base.predict_proba(_lv(df, self.value_fill))[:, 1]
        return self.model.predict_proba(self._x(df))[:, 1]

    def explain(self, df: pd.DataFrame, top: int = 3) -> list[list[dict]]:
        if self.base is not None:
            return [[] for _ in range(len(df))]
        contrib = self.model.predict(self._x(df), pred_contrib=True)[:, :-1]
        return [[{"f": FRIENDLY[(NUM + CAT)[i]], "effect": float(row[i])}
                 for i in np.argsort(-np.abs(row))[:top]] for row in contrib]


def _lv(d: pd.DataFrame, fill: float) -> np.ndarray:
    return d[["log_value"]].fillna(fill).to_numpy()


def _fit(movers: pd.DataFrame, s: int, categories: dict, seed: int):
    """Train on moves up to s-2, early-stop on s-1, refit on both. Nothing from s or later."""
    train, val = movers[movers.season <= s - 2], movers[movers.season == s - 1]
    if len(train) == 0 or len(val) == 0:
        raise ValueError("prospects split is empty")
    probe = ProspectModel(lgb.LGBMClassifier(n_estimators=2000, random_state=seed, **_PARAMS),
                          categories)
    probe.model.fit(probe._x(train), train.regular,
                    eval_X=(probe._x(val),), eval_y=(val.regular,),
                    callbacks=[lgb.early_stopping(100, verbose=False)])
    best = int(probe.model.best_iteration_ or 200)
    fit = pd.concat([train, val])
    model = ProspectModel(lgb.LGBMClassifier(n_estimators=best, random_state=seed, **_PARAMS),
                          categories, value_fill=float(fit.log_value.median()))
    model.model.fit(model._x(fit), fit.regular)
    base = LogisticRegression().fit(_lv(fit, model.value_fill), fit.regular)
    return model, base, best, len(fit)


def run_prospects(rows: pd.DataFrame, test_season: int, n_folds: int = 5,
                  seed: int = 42) -> tuple[ProspectModel, dict]:
    """Rolling-origin evaluation: each of the last n_folds move seasons is predicted by a
    model that only saw earlier seasons. One season holds ~100 moves — too few for a stable
    AUC — so the folds are pooled. The tree model ships only if it beats price alone;
    otherwise the ranking falls back to the price-only model (said so in the app)."""
    movers = rows[rows.moved]
    last = test_season - 1  # moves whose outcome season is the latest complete season
    seasons = list(range(last - n_folds + 1, last + 1))
    categories = {c: sorted(rows[c].dropna().unique().tolist()) for c in CAT}
    ys, ps, pbs, n_by, iters = [], [], [], {}, []
    for s in seasons:
        test = movers[movers.season == s]
        if len(test) == 0:
            raise ValueError(f"no prospect moves in {s}")
        model, base, best, _ = _fit(movers, s, categories, seed)
        ys.append(test.regular.to_numpy())
        ps.append(model.predict(test))
        pbs.append(base.predict_proba(_lv(test, model.value_fill))[:, 1])
        n_by[int(s)] = int(len(test))
        iters.append(best)
    y, p, pb = np.concatenate(ys), np.concatenate(ps), np.concatenate(pbs)
    auc, b_auc = roc_auc_score(y, p), roc_auc_score(y, pb)
    rng = np.random.default_rng(seed)
    gains = []
    for _ in range(1000):  # paired bootstrap over test moves
        i = rng.integers(0, len(y), len(y))
        if 0 < y[i].sum() < len(i):
            gains.append(roc_auc_score(y[i], p[i]) - roc_auc_score(y[i], pb[i]))
    chosen = "model" if auc > b_auc else "value_only"
    final, final_base, best, n_fit = _fit(movers, last + 1, categories, seed)
    if chosen == "value_only":
        final = ProspectModel(None, categories, final_base, final.value_fill)
    return final, {"n_train": int(n_fit), "n_test": int(len(y)),
                   "test_moves_seasons": [int(s) for s in seasons],
                   "n_test_by_season": n_by, "positive_rate": float(y.mean()),
                   "auc": float(auc), "brier": float(brier_score_loss(y, p)),
                   "baseline_auc": float(b_auc),
                   "baseline_brier": float(brier_score_loss(y, pb)),
                   "auc_gain_ci": [float(np.percentile(gains, 2.5)),
                                   float(np.percentile(gains, 97.5))],
                   "best_iter_by_fold": iters, "best_iter": best, "chosen": chosen}


def conversion(rows: pd.DataFrame) -> dict[str, float]:
    """Median top-five G/A per 90 over median feeder G/A per 90 for movers who played."""
    m = rows[rows.moved & (rows.next_share >= 0.25) & (rows.ga90 > 0)]
    overall = float(m.next_ga90.median() / m.ga90.median()) if len(m) else 0.7
    out = {}
    for lg, g in m.groupby("league"):
        if len(g) >= 10 and g.ga90.median() > 0:
            out[lg] = float(g.next_ga90.median() / g.ga90.median())
    return {lg: out.get(lg, overall) for lg in FEEDERS}
