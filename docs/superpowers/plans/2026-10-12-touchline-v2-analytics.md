# Touchline v2 Analytics (Plan 3 of 4) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add four evaluated analytics to the pipeline — Ready for the Big Five (F1), Manager effect (F2), Can't-live-without index (F3), Career curve (F4) — and publish them as additive bundle keys.

**Architecture:** Each feature is one pure module in `pipeline/touchline/models/` taking DataFrames, unit-tested on synthetic data, wired into `run.py`, gated where a baseline exists (F1 AUC, F4 horizon-1 error) and reported honestly where not (F2/F3 reliability).

**Tech Stack:** Python 3.12, pandas, numpy, scikit-learn, LightGBM, PyTorch (CPU). Same venv as Plan 1.

**Spec:** `docs/superpowers/specs/2026-10-12-touchline-v2-design.md` (v2) on top of `2026-10-04-touchline-design.md`.

## Global Constraints

- Feeder leagues: `NL1, PO1, BE1, TR1, SC1, RU1, UKR1, GR1, DK1`. Top five: `GB1, ES1, L1, IT1, FR1`.
- "Regular" = ≥ 40% of the new club's league minutes in the first top-five season.
- Time splits only; no target season ever appears in training. `test_season` = latest complete season (2025 now).
- No model output for players under 900 minutes (v1 rule).
- Bundle schema stays `1`; new keys are additive: `prospects[]`, `managers[]`, `players[].dependency`, `players[].career`, `models.{prospects, manager_effect, dependency, career}`.
- Gates added: `prospects.auc > prospects.baseline_auc`; `career.mae_h1 < career.baseline_mae_h1`.
- All commands from `C:\Users\91750\touchline\pipeline` with `.venv/Scripts/python`. Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Branch `feat/v2-analytics`.

## Review Focus

1. **Tiny samples:** a manager with 3 games, a player who missed 1 game, a feeder league with few movers — shrinkage/thresholds must keep these from topping lists (tests in Tasks 3, 4).
2. **Missing values:** feeder players without valuations or DOB; players without any valuation history — features NaN, outputs null, no crash (Tasks 2, 5).
3. **Leakage:** F1 uses the valuation *before* the move; F4 purges overlapping target windows (assertions + tests in Tasks 2, 5).
4. **Quantile crossing:** F4's 10th/50th/90th must stay ordered (Task 5 test).
5. **Bundle validity:** new keys contain no NaN and stay strict JSON (Task 6 uses `sanitize`).

---

### Task 1: Manager names and multi-league season stats

**Files:**
- Modify: `pipeline/touchline/ingest/load.py` (games: `home_manager`, `away_manager`), `pipeline/tests/test_load.py`
- Modify: `pipeline/touchline/features/players.py` (+ `league_season_stats`)
- Test: `pipeline/tests/test_player_features.py`

**Interfaces:**
- Produces: games columns `home_manager`, `away_manager`; `league_season_stats(eapps, games, leagues) -> DataFrame[player_id, season, league, club_id, minutes, apps, goals, assists, team_games, ga90, g90, a90, minutes_share]` (one row per player-season: the league+club with most minutes among `leagues`).

- [ ] **Step 1: Failing tests**

In `pipeline/tests/test_load.py`, add to the games DataFrame: `"home_club_manager_name": ["M1"] * 4, "away_club_manager_name": ["M2"] * 4,` and at the end assert:
```python
    assert list(tm["games"].home_manager) == ["M1"]
```
Append to `pipeline/tests/test_player_features.py`:
```python
def test_league_season_stats_picks_main_league_and_share():
    from touchline.features.players import league_season_stats
    games = pd.DataFrame({
        "game_id": [1, 2, 3], "competition_id": ["NL1", "NL1", "GB1"], "season": [2024] * 3,
        "home_club_id": [10, 11, 20], "away_club_id": [11, 10, 21],
        "home_club_name": ["a"] * 3, "away_club_name": ["b"] * 3})
    apps = pd.DataFrame({
        "game_id": [1, 2, 3], "player_id": [7, 7, 7], "club_id": [10, 10, 20],
        "date": pd.to_datetime(["2024-08-10", "2024-08-17", "2025-02-01"]),
        "competition_id": ["NL1", "NL1", "GB1"], "goals": [1, 0, 0], "assists": [0, 1, 0],
        "minutes": [90, 90, 30], "yellow_cards": [0] * 3, "red_cards": [0] * 3})
    from touchline.features.players import enrich_appearances
    s = league_season_stats(enrich_appearances(apps, games), games, ["NL1", "GB1"]).iloc[0]
    assert s.league == "NL1" and s.club_id == 10 and s.minutes == 180
    assert s.team_games == 2 and abs(s.minutes_share - 1.0) < 1e-9 and abs(s.ga90 - 1.0) < 1e-9
```

- [ ] **Step 2: Run, expect FAIL** — `.venv/Scripts/python -m pytest tests/test_load.py tests/test_player_features.py -q -p no:cacheprovider`

- [ ] **Step 3: Implement**

In `load.py` games select, after `home_club_name, away_club_name` add `, home_club_manager_name as home_manager, away_club_manager_name as away_manager`.

Append to `features/players.py`:
```python
def league_season_stats(eapps: pd.DataFrame, games: pd.DataFrame, leagues) -> pd.DataFrame:
    """Per (player, season): the league and club with most minutes among `leagues`."""
    leagues = list(leagues)
    keys = ["player_id", "season"]
    e = eapps[eapps.competition_id.isin(leagues)]
    per = (e.groupby(keys + ["competition_id", "club_id"])
             .agg(minutes=("minutes", "sum"), apps=("game_id", "size"),
                  goals=("goals", "sum"), assists=("assists", "sum"))
             .reset_index().sort_values("minutes", ascending=False).drop_duplicates(keys)
             .rename(columns={"competition_id": "league"}))
    lg = games[games.competition_id.isin(leagues)]
    team_games = (pd.concat([
        lg[["season", "home_club_id"]].rename(columns={"home_club_id": "club_id"}),
        lg[["season", "away_club_id"]].rename(columns={"away_club_id": "club_id"})])
        .value_counts().rename("team_games").reset_index())
    out = per.merge(team_games, on=["season", "club_id"], how="left")
    m90 = out.minutes.clip(lower=1) / 90
    out["ga90"] = (out.goals + out.assists) / m90
    out["g90"] = out.goals / m90
    out["a90"] = out.assists / m90
    out["minutes_share"] = out.minutes / (out.team_games * 90)
    return out.reset_index(drop=True)
```

- [ ] **Step 4: Run, expect PASS** (whole suite) — `.venv/Scripts/python -m pytest -q -p no:cacheprovider && .venv/Scripts/python -m ruff check touchline tests`

- [ ] **Step 5: Commit** — `git add pipeline && git commit -m "feat(pipeline): manager names on games; multi-league season stats"`

---

### Task 2: F1 — Ready for the Big Five

**Files:**
- Create: `pipeline/touchline/models/prospects.py`
- Test: `pipeline/tests/test_prospects.py`

**Interfaces:**
- Consumes: `league_season_stats`, `season_ref_date` (Task 1 / Plan 1)
- Produces: `FEEDERS: dict[str, str]`; `REGULAR_SHARE = 0.4`; `build_rows(feeder, top5, players, valuations, history) -> DataFrame` (adds `moved`, `regular`, `next_share`, `next_ga90`, `prev_ga90`, `age`, `position`, `club_elo`, `mv`, `log_value`); `ProspectModel{predict(df) -> ndarray, explain(df, top=3) -> list[list[dict]]}`; `run_prospects(rows, test_season, seed=42) -> (ProspectModel, metrics)` with metrics `n_train, n_test, test_moves_season, positive_rate, auc, brier, baseline_auc, baseline_brier, best_iter`; `conversion(rows) -> dict[str, float]`.

- [ ] **Step 1: Failing tests** — `pipeline/tests/test_prospects.py`:
```python
import numpy as np
import pandas as pd

from touchline.models.prospects import FEEDERS, build_rows, conversion, run_prospects


def _stats(rng, n_players=1500):
    seasons = np.arange(2014, 2026)
    rows, top = [], []
    for pid in range(n_players):
        lg = rng.choice(list(FEEDERS))
        skill = rng.normal()
        for s in seasons:
            share = float(np.clip(0.5 + 0.2 * skill + rng.normal(0, 0.1), 0.15, 1))
            ga90 = max(0.0, 0.3 + 0.15 * skill + rng.normal(0, 0.05))
            rows.append({"player_id": pid, "season": s, "league": lg, "club_id": 100 + pid % 50,
                         "minutes": share * 34 * 90, "apps": 30, "goals": 5, "assists": 3,
                         "team_games": 34, "ga90": ga90, "g90": ga90 / 2, "a90": ga90 / 2,
                         "minutes_share": share})
            if rng.random() < 0.08:  # moves up next season
                top.append({"player_id": pid, "season": s + 1, "league": "GB1", "club_id": 1,
                            "minutes": 1000, "apps": 20, "goals": 2, "assists": 2,
                            "team_games": 38, "ga90": ga90 * 0.6, "g90": 0.1, "a90": 0.1,
                            "minutes_share": float(np.clip(0.3 + 0.25 * skill
                                                           + rng.normal(0, 0.1), 0, 1))})
    return pd.DataFrame(rows), pd.DataFrame(top)


def _rows(seed=0):
    rng = np.random.default_rng(seed)
    feeder, top5 = _stats(rng)
    players = pd.DataFrame({"player_id": feeder.player_id.unique(),
                            "dob": pd.Timestamp("1998-01-01"), "position": "Attack"})
    vals = feeder[["player_id", "season"]].assign(
        date=lambda d: pd.to_datetime((d.season + 1).astype(str) + "-05-01"),
        value=lambda d: 1e6 * (1 + d.player_id % 7))[["player_id", "date", "value"]]
    hist = pd.DataFrame({"date": pd.to_datetime(["2010-01-01"]), "club_id": [100],
                         "rating": [1500.0]})
    return build_rows(feeder, top5, players, vals, hist)


def test_build_rows_labels_movers_and_uses_pre_move_value():
    rows = _rows()
    assert rows.moved.any() and not rows.moved.all()
    assert set(rows.loc[rows.moved, "regular"].unique()) <= {0, 1}
    assert rows.mv.notna().any()


def test_run_prospects_beats_value_only_baseline_without_leakage():
    rows = _rows()
    model, m = run_prospects(rows, test_season=2025)
    assert m["test_moves_season"] == 2024
    assert m["auc"] > m["baseline_auc"]
    cur = rows[rows.season == 2025].head(5)
    p = model.predict(cur)
    assert ((p >= 0) & (p <= 1)).all()
    assert len(model.explain(cur)[0]) == 3


def test_conversion_factor_per_feeder_league():
    f = conversion(_rows())
    assert set(f) == set(FEEDERS) and all(0 < v < 2 for v in f.values())
```

- [ ] **Step 2: Run, expect FAIL.**

- [ ] **Step 3: Implement** `pipeline/touchline/models/prospects.py`:
```python
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
```

- [ ] **Step 4: Run, expect PASS.**

- [ ] **Step 5: Commit** — `git add pipeline && git commit -m "feat(pipeline): F1 Ready for the Big Five prospect model"`

---

### Task 3: F2 — Manager effect

**Files:**
- Create: `pipeline/touchline/models/managers.py`
- Test: `pipeline/tests/test_managers.py`

**Interfaces:**
- Consumes: `MatchModel.outcome_probs` (Plan 1); games with `home_manager`, `away_manager`, `d` (Elo gap)
- Produces: `club_game_results(lg, model) -> DataFrame[game_id, date, season, league, club_id, opp_id, manager, points, xpts, pae, stint]`; `shrink_k(res, min_games=10) -> float`; `manager_table(res, season, k) -> DataFrame[name, club, league, games, since, pae_raw, pae, per38, first10]`; `reliability(res, min_games=40) -> dict{n_stints, split_half_r, reliability}`; `bounce(res) -> dict{n_changes, last10_before, first10, next20}`.

- [ ] **Step 1: Failing tests** — `pipeline/tests/test_managers.py`:
```python
import numpy as np
import pandas as pd

from touchline.models.managers import (bounce, club_game_results, manager_table, reliability,
                                       shrink_k)


class _Flat:
    def outcome_probs(self, d):
        return np.tile([0.45, 0.27, 0.28], (len(d), 1))


def test_club_game_results_two_rows_per_game_and_stints():
    lg = pd.DataFrame({
        "game_id": [1, 2, 3], "date": pd.to_datetime(["2024-08-01", "2024-08-08", "2024-08-15"]),
        "season": [2024] * 3, "competition_id": ["GB1"] * 3,
        "home_club_id": [1, 2, 1], "away_club_id": [2, 1, 2],
        "home_goals": [2, 0, 1], "away_goals": [0, 0, 3],
        "home_manager": ["A", "B", "C"], "away_manager": ["B", "A", "B"], "d": [0.0] * 3})
    r = club_game_results(lg, _Flat())
    assert len(r) == 6
    c1 = r[r.club_id == 1].sort_values("date")
    assert list(c1.points) == [3, 1, 0]
    assert abs(c1.iloc[0].pae - (3 - (3 * 0.45 + 0.27))) < 1e-9
    assert c1.stint.nunique() == 2  # A, A, then C


def _res(seed=0):
    rng = np.random.default_rng(seed)
    rows, gid = [], 0
    day = pd.Timestamp("2014-08-01")
    for club in range(1, 21):
        managers = [(f"M{club}a", 0.4 if club <= 5 else 0.0, 80), (f"M{club}b", 0.0, 60)]
        for name, skill, n in managers:
            for i in range(n):
                gid += 1
                rows.append({"game_id": gid, "date": day + pd.Timedelta(days=gid),
                             "season": 2014 + i // 38 + (0 if name.endswith("a") else 2),
                             "league": "GB1", "club_id": club, "opp_id": 0, "manager": name,
                             "points": 0, "xpts": 0.0, "pae": skill + rng.normal(0, 1.2)})
    res = pd.DataFrame(rows).sort_values(["club_id", "date"]).reset_index(drop=True)
    res["stint"] = (res.manager != res.groupby("club_id").manager.shift()).cumsum()
    return res


def test_shrinkage_tames_tiny_samples_and_table_ranks_current_managers():
    res = _res()
    tiny = pd.DataFrame([{**res.iloc[-1].to_dict(), "game_id": 10 ** 6 + i,
                          "date": res.date.max() + pd.Timedelta(days=i + 1), "season": 2016,
                          "manager": "Lucky", "pae": 3.0, "club_id": 99} for i in range(3)])
    tiny["stint"] = res.stint.max() + 1
    res = pd.concat([res, tiny], ignore_index=True)
    k = shrink_k(res)
    assert k > 3
    t = manager_table(res, 2016, k).set_index("name")
    assert t.loc["Lucky", "pae"] < 3.0 * 3 / (3 + 3)  # heavily shrunk
    assert "M1b" in t.index or "M1a" in t.index


def test_reliability_detects_persistent_effects_and_bounce_reports():
    res = _res()
    r = reliability(res, min_games=40)
    assert r["n_stints"] >= 5 and r["split_half_r"] is not None
    b = bounce(res)
    assert set(b) == {"n_changes", "last10_before", "first10", "next20"}
```

- [ ] **Step 2: Run, expect FAIL.**

- [ ] **Step 3: Implement** `pipeline/touchline/models/managers.py`:
```python
"""F2 — manager effect: points above what the squad's strength predicted, shrunk for luck."""
import numpy as np
import pandas as pd


def club_game_results(lg: pd.DataFrame, model) -> pd.DataFrame:
    p = model.outcome_probs(lg.d.to_numpy())
    hg, ag = lg.home_goals.to_numpy(), lg.away_goals.to_numpy()
    hp = np.where(hg > ag, 3, np.where(hg == ag, 1, 0))
    ap = np.where(ag > hg, 3, np.where(hg == ag, 1, 0))
    base = {"game_id": lg.game_id.to_numpy(), "date": lg.date.to_numpy(),
            "season": lg.season.to_numpy(), "league": lg.competition_id.to_numpy()}
    home = pd.DataFrame({**base, "club_id": lg.home_club_id.to_numpy(),
                         "opp_id": lg.away_club_id.to_numpy(),
                         "manager": lg.home_manager.to_numpy(), "points": hp,
                         "xpts": 3 * p[:, 0] + p[:, 1]})
    away = pd.DataFrame({**base, "club_id": lg.away_club_id.to_numpy(),
                         "opp_id": lg.home_club_id.to_numpy(),
                         "manager": lg.away_manager.to_numpy(), "points": ap,
                         "xpts": 3 * p[:, 2] + p[:, 1]})
    out = pd.concat([home, away], ignore_index=True)
    out["pae"] = out.points - out.xpts
    out = out.sort_values(["club_id", "date", "game_id"]).reset_index(drop=True)
    # A new stint starts at each club's first game and whenever the manager changes.
    out["stint"] = (out.manager != out.groupby("club_id").manager.shift()).cumsum()
    return out


def shrink_k(res: pd.DataFrame, min_games: int = 10) -> float:
    """Empirical-Bayes prior strength: within-game noise over between-manager variance."""
    g = res.groupby("stint").pae.agg(["mean", "var", "count"])
    g = g[g["count"] >= min_games]
    within = float(g["var"].mean())
    between = float(g["mean"].var() - (g["var"] / g["count"]).mean())
    return within / between if between > 1e-9 else 1e6


def manager_table(res: pd.DataFrame, season: int, k: float) -> pd.DataFrame:
    cur = res[res.season == season].sort_values("date").groupby("club_id").tail(1)
    rows = []
    for club, stint, name, league in cur[["club_id", "stint", "manager", "league"]].itertuples(
            index=False):
        g = res[res.stint == stint].sort_values("date")
        n, mean = len(g), float(g.pae.mean())
        shrunk = mean * n / (n + k)
        rows.append({"name": name, "club": int(club), "league": league, "games": n,
                     "since": g.date.iloc[0], "pae_raw": mean, "pae": shrunk,
                     "per38": shrunk * 38,
                     "first10": float(g.pae.head(10).mean()) if n >= 10 else None})
    return pd.DataFrame(rows)


def reliability(res: pd.DataFrame, min_games: int = 40) -> dict:
    """Split-half check: do a manager's odd and even games agree? Near zero means noise."""
    halves = []
    for _, g in res.groupby("stint"):
        if len(g) < min_games:
            continue
        v = g.sort_values("date").pae.to_numpy()
        halves.append((v[0::2].mean(), v[1::2].mean()))
    if len(halves) < 5:
        return {"n_stints": len(halves), "split_half_r": None, "reliability": None}
    a = np.array(halves)
    r = float(np.corrcoef(a[:, 0], a[:, 1])[0, 1])
    return {"n_stints": len(halves), "split_half_r": r,
            "reliability": 2 * r / (1 + r) if r > -1 else None}


def bounce(res: pd.DataFrame) -> dict:
    """Mid-season changes: the old manager's last 10, the new one's first 10 and next 20."""
    out = []
    for _, g in res.sort_values("date").groupby("club_id"):
        stints = [s for _, s in g.groupby("stint", sort=False)]
        for prev, cur in zip(stints, stints[1:], strict=False):
            if len(prev) < 10 or len(cur) < 30:
                continue
            if cur.season.iloc[0] != prev.season.iloc[-1]:
                continue
            out.append((prev.pae.tail(10).mean(), cur.pae.head(10).mean(),
                        cur.pae.iloc[10:30].mean()))
    if not out:
        return {"n_changes": 0, "last10_before": None, "first10": None, "next20": None}
    a = np.array(out)
    return {"n_changes": len(out), "last10_before": float(a[:, 0].mean()),
            "first10": float(a[:, 1].mean()), "next20": float(a[:, 2].mean())}
```

- [ ] **Step 4: Run, expect PASS.** (If `test_reliability...` finds no mid-season changes in the synthetic data, `bounce` returns `n_changes: 0` — still passes the key check.)

- [ ] **Step 5: Commit** — `git add pipeline && git commit -m "feat(pipeline): F2 luck-adjusted manager effect with reliability and bounce"`

---

### Task 4: F3 — Can't-live-without index

**Files:**
- Create: `pipeline/touchline/models/dependency.py`
- Test: `pipeline/tests/test_dependency.py`

**Interfaces:**
- Consumes: `club_game_results` output `res` (Task 3); enriched appearances (Plan 1)
- Produces: `dependency(eapps, res, club_of: dict[int, int], season, min_played=5, min_missed=3, k=5.0) -> DataFrame[player_id, index, played, missed]`; `split_half_stability(eapps, res, club_of, season) -> dict{n, r}`.

- [ ] **Step 1: Failing tests** — `pipeline/tests/test_dependency.py`:
```python
import numpy as np
import pandas as pd

from touchline.models.dependency import dependency, split_half_stability


def _data():
    days = pd.date_range("2024-08-01", periods=20, freq="7D")
    res = pd.DataFrame({"game_id": range(1, 21), "club_id": 1, "season": 2024, "date": days,
                        "pae": [0.5] * 15 + [-0.5] * 5})
    apps = []
    for gid in range(1, 16):
        apps.append({"player_id": 10, "game_id": gid, "club_id": 1, "season": 2024,
                     "minutes": 90})
    for gid in range(1, 20):
        apps.append({"player_id": 11, "game_id": gid, "club_id": 1, "season": 2024,
                     "minutes": 90})
    return pd.DataFrame(apps), res


def test_key_player_scores_high_and_rarely_missing_player_is_excluded():
    apps, res = _data()
    d = dependency(apps, res, {10: 1, 11: 1}, 2024).set_index("player_id")
    assert 10 in d.index and 11 not in d.index  # 11 missed only one game
    assert d.loc[10, "played"] == 15 and d.loc[10, "missed"] == 5
    assert np.isclose(d.loc[10, "index"], 1.0 * 5 / (5 + 5.0))


def test_split_half_stability_returns_shape():
    apps, res = _data()
    out = split_half_stability(apps, res, {10: 1, 11: 1}, 2024)
    assert set(out) == {"n", "r"}
```

- [ ] **Step 2: Run, expect FAIL.**

- [ ] **Step 3: Implement** `pipeline/touchline/models/dependency.py`:
```python
"""F3 — can't-live-without index: results with vs without a player, opponent-adjusted.

Residual = actual - expected points from the match model, so a player missing only easy games
is not mistaken for a key man. Correlation, not causation."""
import numpy as np
import pandas as pd


def dependency(eapps: pd.DataFrame, res: pd.DataFrame, club_of: dict, season: int,
               min_played: int = 5, min_missed: int = 3, k: float = 5.0) -> pd.DataFrame:
    s_res = res[res.season == season]
    by_club = {c: (g.game_id.to_numpy(), g.pae.to_numpy()) for c, g in s_res.groupby("club_id")}
    played = eapps[(eapps.season == season) & (eapps.minutes >= 45)]
    played_by = played.groupby("player_id").game_id.apply(set).to_dict()
    rows = []
    for pid, club in club_of.items():
        if club not in by_club:
            continue
        gids, pae = by_club[club]
        mask = np.isin(gids, list(played_by.get(pid, set())))
        n_p, n_m = int(mask.sum()), int((~mask).sum())
        if n_p < min_played or n_m < min_missed:
            continue
        diff = float(pae[mask].mean() - pae[~mask].mean())
        rows.append({"player_id": pid, "index": diff * n_m / (n_m + k), "played": n_p,
                     "missed": n_m})
    return pd.DataFrame(rows, columns=["player_id", "index", "played", "missed"])


def split_half_stability(eapps, res, club_of, season) -> dict:
    """Index from the first half of the season vs the second half, across players."""
    s = res[res.season == season]
    cut = s.date.median()
    a = dependency(eapps, s[s.date <= cut], club_of, season, min_played=3, min_missed=2)
    b = dependency(eapps, s[s.date > cut], club_of, season, min_played=3, min_missed=2)
    m = a.merge(b, on="player_id", suffixes=("_a", "_b"))
    r = float(np.corrcoef(m.index_a, m.index_b)[0, 1]) if len(m) >= 10 else None
    return {"n": int(len(m)), "r": r}
```

- [ ] **Step 4: Run, expect PASS.**

- [ ] **Step 5: Commit** — `git add pipeline && git commit -m "feat(pipeline): F3 can't-live-without index"`

---

### Task 5: F4 — Career curve (quantile GRU)

**Files:**
- Create: `pipeline/touchline/models/career.py`
- Test: `pipeline/tests/test_career.py`

**Interfaces:**
- Consumes: valuations, players, `season_stats` output (Plan 1); `POS_GROUPS`
- Produces: `H = 3`, `QS = (0.1, 0.5, 0.9)`; `yearly_panel(valuations, players, stats) -> DataFrame[player_id, season, log_value, age, position, minutes, ga90, has_stats]`; `CareerData{x, y, last, meta}` with `.subset(mask)`; `build(panel, ends, need_targets=True, ids=None, min_log_value=None) -> CareerData`; `CareerModel{predict(d) -> ndarray (N, H, 3) ordered quantiles of log-value change, curve_delta(meta) -> ndarray (N, H)}`; `run_career(panel, test_end, epochs=30, seed=0) -> (CareerModel, metrics)` with `n_train, n_test, test_end, mae_h1..3, baseline_mae_h1..3, coverage_h1..3`.

- [ ] **Step 1: Failing tests** — `pipeline/tests/test_career.py`:
```python
import numpy as np
import pandas as pd

from touchline.models.career import H, build, run_career, yearly_panel


def _panel(n=900, seed=0):
    rng = np.random.default_rng(seed)
    vals, players = [], []
    for pid in range(n):
        born = 1985 + int(rng.integers(0, 15))
        players.append({"player_id": pid, "dob": pd.Timestamp(born, 1, 1),
                        "position": rng.choice(["Attack", "Midfield", "Defender"])})
        lv = 14 + rng.normal(0, 1)
        for season in range(2010, 2026):
            age = season + 1 - born
            lv += (0.35 if age < 24 else 0.05 if age < 28 else -0.25) + rng.normal(0, 0.15)
            vals.append({"player_id": pid, "date": pd.Timestamp(season + 1, 5, 1),
                         "value": float(np.exp(lv))})
    stats = pd.DataFrame(columns=["player_id", "season", "minutes", "ga90"])
    return yearly_panel(pd.DataFrame(vals), pd.DataFrame(players), stats)


def test_panel_one_value_per_season_and_build_targets():
    panel = _panel(50)
    assert not panel.duplicated(["player_id", "season"]).any()
    d = build(panel, [2018])
    assert d.x.shape[1:] == (6, d.x.shape[2]) and d.y.shape == (len(d.meta), H)
    assert np.isfinite(d.y).all()


def test_run_career_beats_ageing_curve_with_ordered_quantiles():
    panel = _panel()
    model, m = run_career(panel, test_end=2022, epochs=8)
    assert m["mae_h1"] < m["baseline_mae_h1"]
    q = model.predict(build(panel, [2022]))
    assert (np.diff(q, axis=2) >= 0).all()  # p10 <= p50 <= p90
    assert 0.3 < m["coverage_h1"] <= 1.0
```

- [ ] **Step 2: Run, expect FAIL.**

- [ ] **Step 3: Implement** `pipeline/touchline/models/career.py`:
```python
"""F4 — career curve: a GRU reads a player's last six seasons and forecasts his market value
one, two and three seasons ahead as 10th/50th/90th percentiles (pinball loss). The baseline is
the empirical ageing curve: median value change by position and age."""
from dataclasses import dataclass

import numpy as np
import pandas as pd
import torch
from torch import nn

from touchline.features.players import POS_GROUPS

H, LMAX = 3, 6
QS = (0.1, 0.5, 0.9)
_BASE = 7  # rel log value, abs log value, age, minutes, ga90, has stats, present
F = _BASE + len(POS_GROUPS)
_POS = {p: i for i, p in enumerate(POS_GROUPS)}


def yearly_panel(valuations, players, stats) -> pd.DataFrame:
    v = valuations[valuations.value > 0].copy()
    d = pd.to_datetime(v.date)
    v["season"] = np.where(d.dt.month >= 7, d.dt.year, d.dt.year - 1)
    v = v.assign(date=d).sort_values("date").groupby(["player_id", "season"]).tail(1)
    v["log_value"] = np.log(v.value.astype(float))
    v = v.merge(players[["player_id", "dob", "position"]], on="player_id", how="left")
    ref = pd.to_datetime((v.season + 1).astype(str) + "-07-01")
    v["age"] = (ref - pd.to_datetime(v.dob)).dt.days / 365.25
    st = stats[["player_id", "season", "minutes", "ga90"]]
    v = v.merge(st, on=["player_id", "season"], how="left")
    v["has_stats"] = v.minutes.notna().astype(float)
    return v[["player_id", "season", "log_value", "age", "position", "minutes", "ga90",
              "has_stats"]].reset_index(drop=True)


@dataclass
class CareerData:
    x: np.ndarray
    y: np.ndarray
    last: np.ndarray
    meta: pd.DataFrame

    def subset(self, mask) -> "CareerData":
        mask = np.asarray(mask)
        return CareerData(self.x[mask], self.y[mask], self.last[mask],
                          self.meta[mask].reset_index(drop=True))


def build(panel, ends, need_targets=True, ids=None, min_log_value=None) -> CareerData:
    ends = sorted(set(int(e) for e in ends))
    xs, ys, lasts, metas = [], [], [], []
    cols = ["season", "log_value", "age", "position", "minutes", "ga90", "has_stats"]
    for pid, g in panel.groupby("player_id", sort=True):
        if ids is not None and pid not in ids:
            continue
        rec = {int(r[0]): r[1:] for r in g[cols].itertuples(index=False)}
        for e in ends:
            if e not in rec:
                continue
            lv0, age0, pos0 = rec[e][0], rec[e][1], rec[e][2]
            if min_log_value is not None and lv0 < min_log_value:
                continue
            fut = [rec[e + h][0] if (e + h) in rec else np.nan for h in range(1, H + 1)]
            if need_targets and np.isnan(fut).any():
                continue
            x = np.zeros((LMAX, F), np.float32)
            for i, s in enumerate(range(e - LMAX + 1, e + 1)):
                if s not in rec:
                    continue
                lv, age, pos, mins, ga90, has = rec[s]
                x[i, :_BASE] = [lv - lv0, (lv - 14.0) / 2.0,
                                ((age if age == age else 26.0) - 26.0) / 5.0,
                                (mins if mins == mins else 0.0) / 3000.0,
                                ga90 if ga90 == ga90 else 0.0, has, 1.0]
                if pos in _POS:
                    x[i, _BASE + _POS[pos]] = 1.0
            xs.append(x)
            ys.append(np.array(fut, np.float32) - lv0)
            lasts.append(lv0)
            metas.append({"player_id": pid, "end": e, "age": age0, "position": pos0})
    meta = pd.DataFrame(metas, columns=["player_id", "end", "age", "position"])
    return CareerData(np.asarray(xs, np.float32).reshape(-1, LMAX, F),
                      np.asarray(ys, np.float32).reshape(-1, H),
                      np.asarray(lasts, np.float32), meta)


class CareerGRU(nn.Module):
    def __init__(self, f: int = F, hidden: int = 32):
        super().__init__()
        self.gru = nn.GRU(f, hidden, batch_first=True)
        self.head = nn.Sequential(nn.Linear(hidden, 32), nn.ReLU(), nn.Linear(32, H * len(QS)))

    def forward(self, x):
        _, h = self.gru(x)
        return self.head(h[-1]).view(-1, H, len(QS))


def _pinball(pred, y):
    q = torch.tensor(QS).view(1, 1, -1)
    e = y.unsqueeze(-1) - pred
    return torch.maximum(q * e, (q - 1) * e).mean()


def _age_bucket(age):
    return np.clip(np.round(np.nan_to_num(np.asarray(age, float), nan=26.0)), 17, 38)


@dataclass
class CareerModel:
    gru: CareerGRU
    curve: dict
    global_med: np.ndarray

    def predict(self, d: CareerData) -> np.ndarray:
        if len(d.y) == 0:
            return np.zeros((0, H, len(QS)))
        self.gru.eval()
        with torch.no_grad():
            out = self.gru(torch.from_numpy(d.x)).numpy()
        return np.sort(out, axis=2)

    def curve_delta(self, meta: pd.DataFrame) -> np.ndarray:
        ages = _age_bucket(meta.age)
        return np.array([self.curve.get((p, a), self.global_med)
                         for p, a in zip(meta.position, ages, strict=True)]).reshape(-1, H)


def _curve(d: CareerData) -> tuple[dict, np.ndarray]:
    df = d.meta.assign(bucket=_age_bucket(d.meta.age))
    out = {}
    for (pos, b), idx in df.groupby(["position", "bucket"]).groups.items():
        if len(idx) >= 20:
            out[(pos, b)] = np.median(d.y[np.asarray(idx)], axis=0)
    return out, np.median(d.y, axis=0)


def run_career(panel, test_end: int, epochs: int = 30, seed: int = 0,
               batch: int = 512, patience: int = 3) -> tuple[CareerModel, dict]:
    floor = np.log(200_000)
    train = build(panel, range(2012, test_end - 5), min_log_value=floor)
    val = build(panel, [test_end - 3], min_log_value=floor)
    test = build(panel, [test_end], min_log_value=floor)
    # Target windows never overlap: train targets <= test_end-3 < val targets <= test_end
    # < test targets.
    if len(train.y) == 0 or len(val.y) == 0 or len(test.y) == 0:
        raise ValueError("career split produced an empty set")
    torch.manual_seed(seed)
    gru = CareerGRU()
    opt = torch.optim.Adam(gru.parameters(), lr=1e-3)
    tx, ty = torch.from_numpy(train.x), torch.from_numpy(train.y)
    vx, vy = torch.from_numpy(val.x), torch.from_numpy(val.y)
    best, state, bad = np.inf, None, 0
    gen = torch.Generator().manual_seed(seed)
    for _ in range(epochs):
        gru.train()
        perm = torch.randperm(len(ty), generator=gen)
        for i in range(0, len(ty), batch):
            idx = perm[i:i + batch]
            opt.zero_grad()
            loss = _pinball(gru(tx[idx]), ty[idx])
            loss.backward()
            opt.step()
        gru.eval()
        with torch.no_grad():
            v = float(_pinball(gru(vx), vy))
        if v < best - 1e-5:
            best, state, bad = v, {k: t.clone() for k, t in gru.state_dict().items()}, 0
        else:
            bad += 1
            if bad >= patience:
                break
    gru.load_state_dict(state)
    curve, med = _curve(train)
    model = CareerModel(gru, curve, med)
    q = model.predict(test)
    base = model.curve_delta(test.meta)
    m = {"n_train": int(len(train.y)), "n_test": int(len(test.y)), "test_end": int(test_end)}
    for h in range(H):
        m[f"mae_h{h + 1}"] = float(np.mean(np.abs(q[:, h, 1] - test.y[:, h])))
        m[f"baseline_mae_h{h + 1}"] = float(np.mean(np.abs(base[:, h] - test.y[:, h])))
        m[f"coverage_h{h + 1}"] = float(np.mean((test.y[:, h] >= q[:, h, 0])
                                                & (test.y[:, h] <= q[:, h, 2])))
    return model, m
```

- [ ] **Step 4: Run, expect PASS** (≈ 30 s).

- [ ] **Step 5: Commit** — `git add pipeline && git commit -m "feat(pipeline): F4 quantile GRU career curve vs ageing-curve baseline"`

---

### Task 6: Wire into the run, bundle and docs

**Files:**
- Modify: `pipeline/touchline/run.py`, `pipeline/tests/test_run.py`, `docs/bundle-schema.md`, `pipeline/README.md`

**Interfaces:**
- Consumes: Tasks 1–5
- Produces: bundle keys `prospects[]`, `managers[]`, `players[].dependency`, `players[].career`, `models.prospects`, `models.manager_effect`, `models.dependency`, `models.career`; gates for F1 and F4.

- [ ] **Step 1: Failing test** — extend `pipeline/tests/test_run.py`:
```python
def test_v2_gates_included():
    from touchline.run import GATES
    names = {g[0] for g in GATES}
    assert {"prospects", "career"} <= names
```
and add to the `ok` dict in `test_gates_pass_and_fail`:
`"prospects": {"auc": 0.7, "baseline_auc": 0.6}, "career": {"mae_h1": 0.3, "baseline_mae_h1": 0.4},`

- [ ] **Step 2: Run, expect FAIL.**

- [ ] **Step 3: Implement** in `run.py`:
- Imports: `from touchline.models import career, dependency, managers, prospects` and `from touchline.features.players import league_season_stats`.
- `GATES` gains `("prospects", "auc", "baseline_auc", "higher")` and `("career", "mae_h1", "baseline_mae_h1", "lower")`.
- After `m2_final` is fitted, build `lg_all = lg[lg.season >= config.MODEL_FROM_SEASON]` (it already has `d`, `home_manager`, `away_manager`) and:
```python
    res = managers.club_game_results(lg_all, m2_final)
    k_mgr = managers.shrink_k(res)
    mgr_table = managers.manager_table(res, test_season, k_mgr)
    metrics["manager_effect"] = {"k": k_mgr, **managers.reliability(res),
                                 "bounce": managers.bounce(res)}
```
- After `disp` exists:
```python
    club_of = dict(zip(disp.player_id, disp.club_id.astype("Int64"), strict=True))
    club_of = {int(p): int(c) for p, c in club_of.items() if pd.notna(c)}
    dep = dependency.dependency(eapps, res, club_of, test_season).set_index("player_id")
    prev_club = stats[stats.season == test_season - 1].dropna(subset=["club_id"])
    metrics["dependency"] = {"n": int(len(dep)), **{f"stability_{k}": v for k, v in
        dependency.split_half_stability(eapps, res, {int(p): int(c) for p, c in
            zip(prev_club.player_id, prev_club.club_id, strict=True)}, test_season - 1).items()}}

    feeder = league_season_stats(eapps, games, prospects.FEEDERS)
    top5 = league_season_stats(eapps, games, config.LEAGUES)
    prow = prospects.build_rows(feeder, top5, players, vals, elo_res.history)
    pmodel, metrics["prospects"] = prospects.run_prospects(prow, test_season)
    conv = prospects.conversion(prow)
    metrics["prospects"]["conversion"] = conv
    cur_feeder = players[players.league.isin(list(prospects.FEEDERS))
                         & (players.last_season >= test_season)].player_id
    pc = prow[(prow.season == test_season) & prow.player_id.isin(cur_feeder)].copy()
    pc["p"] = pmodel.predict(pc)
    pc["why"] = pmodel.explain(pc)
    pc = pc.sort_values("p", ascending=False).head(150)

    panel = career.yearly_panel(vals, players, stats)
    cmodel, metrics["career"] = career.run_career(panel, test_end=test_season - 3,
                                                  epochs=8 if args.fast else 30)
    cur = career.build(panel, [test_season], need_targets=False,
                       ids=set(disp[disp.minutes >= config.MIN_DISPLAY_MINUTES].player_id))
    cq = cmodel.predict(cur)
    ccurve = cmodel.curve_delta(cur.meta)
    career_by = {}
    for i, row in cur.meta.iterrows():
        lv0 = float(cur.last[i])
        p10, p50, p90 = (np.exp(lv0 + cq[i, :, j]) for j in range(3))
        path = [np.exp(lv0)] + list(p50)
        peak = int(np.argmax(path))
        diff = float(cq[i, 0, 1] - ccurve[i, 0])
        career_by[int(row.player_id)] = {
            "seasons": [_season_label(test_season + h) for h in range(1, 4)],
            "p10": [eur(x) for x in p10], "p50": [eur(x) for x in p50],
            "p90": [eur(x) for x in p90], "peak_value": eur(path[peak]),
            "peak_age": round(float(row.age) + peak, 1) if pd.notna(row.age) else None,
            "vs_curve": "ahead" if diff > 0.1 else "behind" if diff < -0.1 else "on"}
```
  (`import numpy as np` returns to the imports.)
- In each player record add:
```python
            "dependency": None if pid not in dep.index else {
                "index": round(float(dep.loc[pid, "index"]), 3),
                "played": int(dep.loc[pid, "played"]), "missed": int(dep.loc[pid, "missed"])},
            "career": career_by.get(int(pid)) if qualified else None,
```
- Bundle gains:
```python
        "prospects": [{
            "id": int(r.player_id), "name": pinfo.loc[r.player_id, "name"],
            "img": pinfo.loc[r.player_id, "image_url"],
            "club_name": club_names.get(r.club_id), "league": r.league,
            "league_name": prospects.FEEDERS[r.league], "pos": r.position,
            "age": round(float(r.age), 1) if pd.notna(r.age) else None,
            "market_value": eur(r.mv), "ga90": round(float(r.ga90), 2),
            "translated_ga90": round(float(r.ga90) * conv[r.league], 2),
            "p_regular": round(float(r.p), 3), "why": r.why} for r in pc.itertuples()],
        "managers": [{"name": m.name, "club": m.club, "league": m.league, "games": m.games,
                      "since": _fmt(m.since), "pae": round(m.pae, 3), "pae_raw": round(m.pae_raw, 3),
                      "per38": round(m.per38, 1),
                      "first10": None if m.first10 is None else round(m.first10, 3)}
                     for m in mgr_table.itertuples()],
```
- `docs/bundle-schema.md`: document the four new keys with one example each.
- `pipeline/README.md`: add rows F1–F4 to the models table after the real run (Step 5).

- [ ] **Step 4: Run** — `.venv/Scripts/python -m pytest -q -p no:cacheprovider && .venv/Scripts/python -m ruff check touchline tests` → green.

- [ ] **Step 5: Real run** — `.venv/Scripts/python -m touchline.run --skip-download` → exit 0 with all gates passing. Inspect `data/out/metrics.json` for prospects AUC vs baseline, manager reliability and bounce, dependency stability, career MAE/coverage, and spot-check: top five prospects, top/bottom managers, a club's top dependency, one star's career curve. Write the honest results into `pipeline/README.md` and the root README results table. If a gate fails, report it rather than tuning to the test set.

- [ ] **Step 6: Commit** — `git add pipeline docs README.md && git commit -m "feat(pipeline): publish v2 analytics in the bundle with gates"`
