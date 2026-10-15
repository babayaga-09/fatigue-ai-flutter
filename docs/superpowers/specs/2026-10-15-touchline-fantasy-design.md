# Touchline Fantasy: FPL suggester design

*Date: 2026-10-15. Decisions confirmed by Aryan in chat. Builds on Touchline v2 (`2026-10-12-touchline-v2-design.md`).*

## 1. Goal

A **Fantasy** tab in Touchline that tells a Fantasy Premier League manager what to do this week:
expected points for every player over the next gameweeks, the best transfers (with honest hit
maths), captain and vice-captain, and when to play each chip. It serves two equal purposes: Aryan
plays FPL with it every week, and it is a CV showcase whose model is tested against FPL's own
expected points.

Out of scope here: UEFA Champions League fantasy (a later project), mini-league rivals, price-change
prediction, push notifications.

## 2. Decisions taken

| Question | Decision |
|---|---|
| Purpose | Both: weekly use before deadlines and a CV showcase |
| Placement | A fifth tab inside Touchline |
| Team input | Android imports by FPL team ID (direct call); web uses a squad picker saved on the device (the FPL API sends no CORS headers, so browsers cannot call it) |
| Model | Component model (minutes × per-event rates × FPL scoring) |

## 3. Data

- **Training/evaluation archive:** `vaastav/Fantasy-Premier-League` (MIT licence), gameweek-level
  rows for 2016/17–2025/26 (`data/<season>/gws/merged_gw.csv`), including FPL's own expected points
  (`xP`) per player-gameweek. Downloaded once, cached in `pipeline/data/raw/fpl/`, credited in the
  README.
- **Live:** the public FPL API: `bootstrap-static` (players, prices, status, news,
  `chance_of_playing_next_round`, teams, events, game settings), `fixtures`, and, from the Android
  app only, `entry/{id}/` and `entry/{id}/event/{gw}/picks/` for team import.
- **Team strength:** our existing Elo + Poisson/Dixon-Coles match model, mapped from FPL team ids to
  Touchline club ids by name (a checked mapping table; unmatched teams fail loudly).
- **Splits (time-based):** train 2016/17–2024/25, test 2025/26 (latest complete season). Features for
  a gameweek use only data from earlier gameweeks.

## 4. Model (component expected points)

For player *p* in gameweek *g* (each fixture separately, summed for double gameweeks):

1. **Minutes.** LightGBM classifier → P(start), and P(60+ | start). Features: minutes and starts
   over the last 1/3/6 gameweeks, season starts share, position, price, FPL status and
   `chance_of_playing`, days since last appearance, team rotation level. Blank gameweek → 0.
2. **Attack.** Expected goals and assists = player's xG/90 and xA/90 (recent-weighted, shrunk toward
   the position average by minutes played, empirical-Bayes) × fixture multiplier (our match model's
   expected goals for the player's team ÷ that team's average) × expected minutes / 90.
3. **Defence.** P(clean sheet) and expected goals conceded from our match model for that fixture;
   applied only to the 60+ minutes share as FPL scores it.
4. **Other.** Saves (GK), bonus, defensive-contribution points, cards: player rates shrunk to
   position averages, scaled by expected minutes.
5. **Scoring.** FPL's current scoring rules from `game_settings`/a versioned rules table per season
   (appearance 1/2, goals 4/5/6/10 by position, assist 3, clean sheet 4/4/1/0, saves 1 per 3, goals
   conceded −1 per 2 for GK/DEF, defensive contributions 2, cards −1/−3). Output: expected points,
   plus a breakdown ("why") per component.

Horizon: next 6 gameweeks, so the optimiser can plan transfers and chips.

## 5. Evaluation and gate

On 2025/26 (held out), over player-gameweeks where the player was available:

- **Point accuracy:** MAE and rank correlation (Spearman) of expected vs actual points, ours vs FPL
  `xP`.
- **Decision backtest:** each gameweek, take the top-ranked player of a fixed realistic squad (the
  top-15 by our pre-season value) as captain under ours vs FPL's `xP`; compare points scored.
  Same for "best XI from a fixed 15".
- **Minutes model:** Brier score vs a baseline of "started last gameweek".
- **Gate:** if ours does not beat FPL `xP` on MAE *and* the captaincy backtest, the shipped bundle
  uses FPL's `ep_next` for the expected points (our breakdown hidden) and the app says so. The
  optimiser still runs on whichever numbers ship.

## 6. Optimiser

Extends the existing exact 0/1 integer programme (SciPy MILP in Python; the Dart port mirrors it).

- **Constraints:** 15 players (2 GK, 5 DEF, 5 MID, 3 FWD), max 3 per club, budget = bank + selling
  prices (FPL sell price rule: half of any profit, rounded down), valid XI each week (1 GK, ≥3 DEF,
  ≥2 MID, ≥1 FWD, 11 players), captain doubled.
- **Transfers:** maximise expected points over the next 5 gameweeks (XI + 0.1 × bench), given free
  transfers (bank up to 5); propose the best 0, 1 or 2 moves. A −4 hit is suggested only when its
  horizon gain beats 4 points plus a 1-point safety margin.
- **Captain/vice:** highest and second-highest expected points in the chosen XI, with P(start) shown.
- **Chips (advice with numbers):** Wildcard (unconstrained 15 over the horizon beats current squad's
  best plan by ≥ 12 points), Free Hit (one-gameweek unconstrained XI beats ours by ≥ 15, usually
  blank/double gameweeks), Triple Captain (the gameweek in the horizon with the highest captain
  expectation, flag if a double gameweek), Bench Boost (the gameweek with the highest bench sum).
  Chips already used are excluded.
- **Golden cases:** Python writes `fpl_cases.json`; the Dart optimiser must reproduce them exactly.

## 7. Pipeline and refresh

- New package `pipeline/touchline/fpl/`: `fetch.py` (archive + live API, cached), `features.py`,
  `minutes.py`, `points.py` (component model + scoring), `evaluate.py`, `optimise.py`, `run_fpl.py`.
- Output: a separate `fpl-bundle.json.gz` (schema `fpl_schema_version: 1`) with: gameweeks (id,
  deadline, blank/double flags), teams, players (id, name, team, position, price, status, news,
  P(start), expected points per gameweek for 6 gameweeks, breakdown for the next gameweek), the
  model's evaluation results, and which numbers shipped (ours or FPL's).
- **Refresh:** a daily GitHub Action during the season re-fetches live FPL data and re-scores with the
  latest trained models (a few minutes); the weekly Tuesday job retrains. Both publish to the
  `data-latest` release; Pages serves the FPL bundle beside the app as with the main bundle.

## 8. App

- **Fantasy tab** (fifth destination; the label stays short).
  - Header: team name or "Pick your squad", deadline countdown, data freshness.
  - **Team sheet:** XI and bench in the programme style with next-gameweek expected points, captain
    and vice marked, injury flags.
  - **This week's moves:** suggested transfers (out → in), the horizon gain, whether a hit is worth
    it, and the free-transfer count.
  - **Chip planner:** next 6 gameweeks, the recommended gameweek per chip with its number.
  - **Player rows** open the FPL forecast (per-gameweek expected points, start probability, the why).
  - "How this works" gains the FPL evaluation in plain words.
- **Team input:** Android: "Import by team ID" (calls the FPL API; remembers the ID). Web: squad
  picker with search, position and budget checks, saved in shared preferences. Both: edit the squad
  manually.
- The design follows DESIGN.md (The Matchday Programme); no new visual world.

## 9. Errors and edge cases

- FPL API down or slow: use the cached bundle, show its age; import shows "FPL is not responding".
- Unknown team ID: clear message; private/new entries likewise.
- Deadline passed: suggestions move to the next gameweek automatically.
- Blank/double gameweeks: handled in scoring and chips.
- New players with no history: position-average rates, low P(start) until they play.
- Mid-season scoring-rule changes: the rules table is versioned per season.
- An unmatched FPL team name fails the pipeline run rather than mispricing fixtures.

## 10. Testing

- Python: scoring rules (each event per position), minutes features use only past gameweeks,
  shrinkage, fixture multiplier, optimiser constraints (formation, club limit, budget, sell price,
  hits), chip rules, evaluation gate on synthetic data, the team-name mapping.
- Dart: bundle parsing, squad validation, optimiser vs golden cases, team-import parsing with a
  recorded API response, widget tests for the tab.
- Real-data check: the evaluation on 2025/26 is run and its numbers written into the README.
