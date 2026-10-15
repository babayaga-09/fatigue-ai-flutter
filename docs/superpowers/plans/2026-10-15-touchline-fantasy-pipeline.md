# Touchline Fantasy: Pipeline Implementation Plan (Plan 5)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce a tested FPL expected-points model and a daily `fpl-bundle.json.gz` (per-player expected points for the next 6 gameweeks, pre-solved Wildcard/Free Hit squads, evaluation vs FPL's own `xP`).

**Architecture:** New package `pipeline/touchline/fpl/`. Component model: a LightGBM minutes classifier × shrunk per-90 event rates × fixture strengths from the existing Elo + match model × FPL scoring rules. Walk-forward features (each gameweek sees only earlier gameweeks). An evaluation gate decides whether our numbers or FPL's ship.

**Tech Stack:** Python 3.12, pandas, LightGBM, SciPy `milp`, requests (stdlib urllib is fine), pytest. Existing: `touchline.models.elo`, `touchline.models.match_model`.

**Spec:** `docs/superpowers/specs/2026-10-15-touchline-fantasy-design.md`

**Task-level plan:** every task is test-first. Test names and the behaviour they pin are listed; implementation code lives in the commits.

## Global Constraints

- Archive seasons used: 2022-23, 2023-24, 2024-25 (train) and 2025-26 (test). Earlier seasons lack xP/xG/position and are not used.
- Features for gameweek g use only gameweeks < g of the same season, plus the previous season's totals.
- Squad rules: 15 players (2 GK, 5 DEF, 5 MID, 3 FWD), max 3 per club, budget in tenths of £m (1000 = £100.0m).
- Valid XI: 1 GK, 3–5 DEF, 2–5 MID, 1–3 FWD, 11 players. Captain doubled (tripled with Triple Captain).
- Hit rule: suggest a −4 transfer only if horizon gain > 4 + 1 points.
- Chip thresholds: Wildcard ≥ 12 over the horizon; Free Hit ≥ 15 in its gameweek; Triple Captain = highest captain expectation in horizon; Bench Boost = highest bench sum.
- Horizon: 6 gameweeks of predictions; transfer planning uses the next 5.
- Gate: ship ours only if MAE < FPL xP MAE **and** captaincy backtest points > FPL's; otherwise ship FPL `ep_next` and record `source: "fpl"`.
- An FPL team name with no Touchline club mapping fails the run.

## Review Focus

1. A player who changes club mid-season (January) — rates follow the player, fixture strength follows his current team; test in Task 3.
2. Double and blank gameweeks — expected points sum over fixtures / are 0; test in Tasks 5 and 7.
3. New players with no minutes this season — position priors, low minutes probability, no crash; test in Task 3.
4. Budget below every squad in the Wildcard grid — return the cheapest grid squad flagged `over_budget`; test in Task 6.
5. A gameweek whose deadline has passed at run time — the bundle's "next gameweek" is the first event with `finished == false and deadline > now`; test in Task 7.

---

### Task 1: Data access and team mapping

**Files:** Create `pipeline/touchline/fpl/__init__.py`, `pipeline/touchline/fpl/fetch.py`, `pipeline/touchline/fpl/teams.py`; Test `pipeline/tests/test_fpl_fetch.py`.

**Interfaces — Produces:**
- `load_archive(seasons: list[str], raw_dir: Path) -> pd.DataFrame` — rows of merged_gw with columns `season, gw, element, name, position (GK/DEF/MID/FWD), team, opponent_team (FPL id), fixture, was_home, kickoff_time (UTC), minutes, starts, total_points, xP, expected_goals, expected_assists, goals_scored, assists, clean_sheets, goals_conceded, saves, bonus, yellow_cards, red_cards, defensive_contribution (0 when absent), value`; downloads missing files to `raw_dir`.
- `load_fixtures(season: str, raw_dir) -> pd.DataFrame` — `id, event, kickoff_time, team_h, team_a` (FPL team ids) and `teams(season) -> dict[int, str]` (FPL id → name).
- `fetch_live(cache_dir: Path, max_age_s=3600) -> dict` — `{"bootstrap": ..., "fixtures": [...]}` from the FPL API with a browser User-Agent, cached on disk; raises `FplUnavailable` when the API fails and no cache exists.
- `teams.FPL_TO_TM: dict[str, str]` and `club_id(fpl_name: str, tm_clubs: pd.DataFrame) -> int` — normalised name match to Transfermarkt club ids, raising `UnmappedTeam` on miss.

- [ ] Tests: `test_load_archive_normalises_columns` (a tiny CSV fixture with the 2022 and 2025 column sets → same output columns, `defensive_contribution` filled 0 for 2022); `test_fetch_live_uses_cache_and_fails_cleanly` (monkeypatched opener: second call within max_age does not hit the network; network error with no cache raises `FplUnavailable`); `test_every_archive_team_maps` (all team names in the four teams CSVs map to a club id from the real `clubs` table — skipped if data absent); `test_unmapped_team_raises`.
- [ ] Run tests (fail), implement, run tests (pass), ruff, commit.

### Task 2: Scoring rules

**Files:** Create `pipeline/touchline/fpl/scoring.py`; Test `pipeline/tests/test_fpl_scoring.py`.

**Interfaces — Produces:**
- `RULES: dict[str, Rules]` keyed by season (`"2022-23"` … `"2026-27"`), dataclass `Rules(goal: dict[pos,int], assist=3, clean_sheet: dict[pos,int], appear=1, appear60=1, saves_per_point=3, conceded_per_minus=2, dc_points=2, dc_threshold: dict[pos,int|None], yellow=-1, red=-3)`; goals GK 10 from 2025-26 (6 before), DEF 6, MID 5, FWD 4; clean sheets GK/DEF 4, MID 1, FWD 0; DC threshold DEF 10, MID 12, FWD 12, GK None, only from 2025-26.
- `expected_points(c: Components, pos: str, rules: Rules) -> float`, where `Components(p_play, p60, e_goals, e_assists, p_cs, e_conceded, e_saves, e_bonus, p_dc, e_yellow, e_red)`. Appearance = p_play·1 + p60·1; goals/assists; clean sheet = p_cs·p60·cs[pos]; conceded (GK/DEF) = −(e_conceded·p60)/2; saves = e_saves/3; + e_bonus + p_dc·2 + cards.
- `breakdown(c, pos, rules) -> dict[str, float]` with keys `minutes, attack, defence, bonus, other` summing to `expected_points`.

- [ ] Tests: `test_forward_goal_and_assist` (certain 90 min, 1 goal → 2 + 4 = 6; with an assist → 9); `test_gk_goal_value_changes_in_2025` (6 vs 10); `test_clean_sheet_needs_sixty_minutes` (p60 = 0 → no CS points); `test_breakdown_sums_to_total`; `test_dc_only_from_2025_26`.

### Task 3: Walk-forward features and rates

**Files:** Create `pipeline/touchline/fpl/features.py`; Test `pipeline/tests/test_fpl_features.py`.

**Interfaces:**
- Consumes `load_archive` output; Elo history `elo_res.history` (`date, club_id, rating`) and a fitted `MatchModel` (`outcome_probs`, `score_matrices`, `rates` on Elo difference).
- Produces `player_gw_features(arch: pd.DataFrame, prior: pd.DataFrame | None) -> pd.DataFrame` one row per (season, gw, element, fixture) with: `min_last1, min_last3, min_last6, starts_last3, starts_last6, played_share, gw, position, value, days_since_play`, and shrunk per-90 rates `xg90, xa90, bonus90, saves90, yellow90, red90, dc_rate` (each = (sum_events + k·prior_rate) / (sum_minutes/90 + k), `k` by component, prior = position mean from earlier data); computed from gameweeks < gw only.
- `fixture_strength(fixtures: pd.DataFrame, club_of: dict[int,int], elo_history, model) -> pd.DataFrame` per (fixture, team): `lam_for, lam_against, p_cs` (P(opponent scores 0) from the score matrix with home advantage), using the Elo rating as of the fixture's kickoff (backward as-of).
- `team_attack_avg(strength) -> dict` the team's mean `lam_for`, used for the fixture multiplier `lam_for / avg`.

- [ ] Tests: `test_features_never_use_current_or_future_gameweeks` (rows for gw 5 unchanged when gw ≥ 5 data is altered); `test_shrinkage_pulls_small_samples_to_position_prior`; `test_new_player_gets_prior_rates_and_zero_history`; `test_transfer_mid_season_rates_follow_player` (player with team change keeps his rates; fixture strength uses the new team); `test_fixture_strength_prefers_stronger_side` (higher Elo → higher lam_for, higher p_cs).

### Task 4: Minutes model

**Files:** Create `pipeline/touchline/fpl/minutes.py`; Test `pipeline/tests/test_fpl_minutes.py`.

**Interfaces — Produces:**
- `MinutesModel` with `predict(feats) -> np.ndarray (n,3)` = P(0 min), P(1–59), P(60+); `p_play = 1 − P0`, `p60 = P(60+)`, `e_minutes = 25·P(1–59) + 88·P(60+)` (constants measured from the archive in `fit`).
- `fit_minutes(train, val) -> MinutesModel` LightGBM multiclass with early stopping on val.
- `brier_multi(p, y)` and `baseline_last_gw(feats) -> probs` (class of last gameweek's minutes, smoothed 0.8/0.1/0.1).

- [ ] Tests: `test_minutes_probs_sum_to_one_and_beat_last_gw_baseline` (synthetic regulars/rotators/bench players with persistent patterns); `test_chance_of_playing_scales_play_probability` (`apply_availability(probs, chance=25)` moves mass to P0 so p_play ≤ 0.25).

### Task 5: Expected points model and evaluation gate

**Files:** Create `pipeline/touchline/fpl/points.py`, `pipeline/touchline/fpl/evaluate.py`; Test `pipeline/tests/test_fpl_points.py`.

**Interfaces — Produces:**
- `predict_points(feats, strength, minutes_model, season) -> pd.DataFrame` with `element, gw, fixture, xpts, breakdown cols` (one row per fixture; callers sum per gw for doubles).
- `evaluate(pred, arch, season) -> dict`: over eval rows = player-gameweeks where the player had minutes > 0 in any of his previous 3 gameweeks: `mae, mae_fpl, spearman, spearman_fpl, captain_points, captain_points_fpl` (per gw, among the 15 most-selected players that gw, captain = argmax prediction, points = actual × 2), `minutes_brier, minutes_brier_baseline`, `n`.
- `gate(metrics) -> "ours" | "fpl"`.

- [ ] Tests: `test_double_gameweek_sums_fixtures`; `test_evaluate_on_synthetic_where_truth_is_known` (a constructed season where our components equal the truth → mae < mae_fpl of a noisy xP); `test_gate_requires_both_mae_and_captaincy`.

### Task 6: Optimiser

**Files:** Create `pipeline/touchline/fpl/optimise.py`; Test `pipeline/tests/test_fpl_optimise.py`.

**Interfaces — Produces:**
- `best_xi(squad: list[Player], gw_points: dict[int,float]) -> (xi_ids, bench_ids_ordered, captain, vice, points)` — enumerates the 7 legal formations, exact.
- `sell_price(buy: int, now: int) -> int` — `buy + (now − buy)//2` when now > buy, else now.
- `suggest_transfers(squad, bank, free_transfers, pool, horizon_points, max_transfers=2) -> list[Move]` — exhaustive over outs × ins (ins pre-filtered to the top 25 per position by horizon points, legal by budget and club limit); value = sum over horizon of best_xi points (+0.1·bench); hits = max(0, n − free_transfers)·4; returns the best plan per count (0, 1, 2) with `gain`, `hits`, `worth_it` (gain_vs_0 − hits > 1).
- `solve_squad(pool, budget, points_by_player) -> list[int]` — SciPy MILP for the best 15 under squad rules, maximising XI-weighted points (approximated as the sum of the top 15 weights: GK2 weight 0.1, others 1.0 with bench penalty via best_xi re-check).
- `chip_advice(squad, plan_points, wildcard_squads, free_hit_squads, chips_available) -> dict` per chip: `gw`, `gain`, `recommend` using the thresholds.
- `write_golden(path)` → `fpl_cases.json`: 3 squads with pools and points; expected `best_xi` and `suggest_transfers` outputs.

- [ ] Tests: `test_best_xi_respects_formation` (6 strong DEF never all start); `test_club_limit_and_budget_respected`; `test_sell_price_half_profit_rounded_down` (buy 50, now 53 → 51); `test_hit_suggested_only_when_gain_beats_hit_plus_margin`; `test_solve_squad_is_legal_and_beats_greedy`; `test_budget_below_grid_returns_cheapest_flagged`.

### Task 7: Live scoring, bundle, workflows, docs

**Files:** Create `pipeline/touchline/fpl/run_fpl.py`, `docs/fpl-bundle-schema.md`, `.github/workflows/refresh-fpl.yml`; Modify `.github/workflows/refresh.yml`, `.github/workflows/pages.yml`, `pipeline/README.md`, `README.md`; Test `pipeline/tests/test_fpl_run.py`.

**Interfaces — Produces:** `python -m touchline.fpl.run_fpl [--train] [--offline]` writes `out/fpl-bundle.json.gz`, `out/fpl_metrics.json`, `out/fpl_cases.json`. `--train` refits models from the archive and saves them to `out/fpl_models/`; without it, the saved models are loaded (daily run). Bundle (schema `fpl_schema_version: 1`): `generated_at, source ("ours"|"fpl"), next_gw, gameweeks[{id, deadline, fixtures_per_team_flag}], teams[{id, name, short, club_id}], players[{id, name, team, pos, price, status, news, chance, p_play, xpts[6], why{minutes, attack, defence, bonus, other}}], wildcard[{budget, squad[15]}] (budgets 950–1100 step 5), free_hit[{gw, budget, squad}], models{...metrics}`.

- [ ] Tests: `test_next_gameweek_skips_passed_deadlines`; `test_blank_gameweek_gives_zero`; `test_bundle_roundtrip_and_shipping_source` (gate "fpl" → xpts equal ep_next for gw1 and scaled by FPL fixtures thereafter… simply ep_next repeated, flagged).
- [ ] Workflows: `refresh-fpl.yml` daily at 06:00 UTC (and `workflow_dispatch`): run `run_fpl` (no `--train`), upload `fpl-bundle.json.gz` to `data-latest`. `refresh.yml`: add `run_fpl --train` after the main run and upload both FPL files. `pages.yml`: download `fpl-bundle.json.gz` beside the web build.
- [ ] Real run on the archive; write the metrics honestly into `pipeline/README.md` and `README.md`; commit.
