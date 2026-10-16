# Touchline pipeline

Turns open football data into the single file the Touchline app reads. Every week it downloads
the [Transfermarkt open dataset](https://github.com/dcaribou/transfermarkt-datasets) (CC0) and the
current season's results and fixtures from [football-data.org](https://www.football-data.org).
It trains and evaluates eight models, then writes `data/out/touchline-bundle.json.gz`
(schema: [`docs/bundle-schema.md`](../docs/bundle-schema.md)).

**Honesty gate:** each predictive model is scored on a season it never saw during training, and
compared with a simple baseline. If any model stops beating its baseline, the run exits with an
error and nothing is published.

## Quick start

```bash
cd pipeline
python -m venv .venv
.venv/Scripts/activate            # Windows  (source .venv/bin/activate on macOS/Linux)
pip install torch --index-url https://download.pytorch.org/whl/cpu
pip install -e ".[dev]"
echo FOOTBALL_API_KEY=your_token > .env   # free token: football-data.org/client/register
python -m touchline.run           # ~3 min; --offline skips football-data, --fast for smoke runs
pytest -q
```

## Models

All results below are on the **2025/26 season, held out from training** (time-based split; seasons
up to 2024/25 used for fitting). The evaluation season is always the latest *complete* season.

| # | Model | What it predicts | Method | Result | Baseline |
|---|---|---|---|---|---|
| M1 | Club power rating | Team strength | Elo with home advantage and margin-of-victory scaling; K and home edge tuned on 2024/25 | Picks the winner of **68.9%** of decisive league games | Home team always wins: 59.0% |
| M2 | Match predictor | Home / draw / away probabilities and expected goals | Poisson goal model driven by the Elo gap, with Dixon–Coles low-score correction | RPS **0.203**, log-loss **0.996** (1,752 games) | Historical base rates: RPS 0.229, log-loss 1.072 |
| M3 | Season projector | Title / top-4 / relegation odds | 10,000 Monte Carlo simulations of the remaining fixtures using M2 | — | — |
| M4 | Player valuator | Fair market value | LightGBM on performance, age, role, league and club strength; per-player TreeSHAP explanations | Typical error **€4.7M**, median error **29%**, R² (log) **0.85** | Median by age × position × league: €10.9M, 60% |
| M5 | Form forecast (deep learning) | Goal involvements in the next 5 games | GRU over the last 10 appearances plus position and age, Poisson loss; compared on validation with a Poisson GLM, and the better one ships | MAE **0.779**, Poisson deviance **1.165** | Poisson GLM: MAE 0.795, deviance 1.196 · Shrunk recent average: MAE 0.828, deviance 1.421 |
| M6 | Workload index | Load risk band (not injury probability) | Season minutes, congested appearances and the acute:chronic workload ratio; an Isolation Forest flags unusual loads | — | — |
| M7 | Similar players | "Plays like X" | k-NN on standardised per-90 profiles within a position group | — | — |
| M8 | Transfer budget planner | Best signings for a budget | 0/1 integer programme (SciPy MILP) maximising fair value within budget and positional needs | Always ≥ greedy | Greedy by value-per-euro |

How to read M5: the GRU beats the naive recent-average baseline by 18% on deviance (6% on MAE),
but its lead over a well-specified Poisson GLM is small (about 3% on deviance, 2% on MAE). Football
scoring is noisy, and the honest takeaway is that sequence modelling helps a bit, not a lot. The
naive baseline is shrunk toward the population scoring rate, so players without recent output are
not predicted ~0 (that would make it a strawman). Windows are split by the dates of their *target*
games, so no outcome is shared between train, validation and test.

## v2 analytics — and what didn't work

Four things no mainstream fan app shows. Each was tested honestly, and a fresh code review found
five method problems in the first version (listed below); the numbers here are after the fixes.
The app presents each result the way its evidence allows.

| # | Question | Method | Result | Baseline | Verdict |
|---|---|---|---|---|---|
| F1 | Will a feeder-league player become a regular after moving to the top five? (≥ 40% of league minutes; a move with no minutes counts as no) | LightGBM on output, minutes share, age, club Elo and value *before the transfer*; moves taken from the transfers table; rolling-origin evaluation over 713 moves (2020–24), each season predicted by a model that saw only earlier seasons | AUC **0.626** | Pre-move market value alone: AUC **0.651** (gain 95% CI −0.067 to +0.014) | **Model not shipped.** Price beats it; the list ranks by the price-only model and says so. League conversion factors (translated G/A per 90) ship as measured facts |
| F2 | Is a manager getting more than his squad should? | Points above expected per game; the club's own Elo is frozen at the start of each spell (season or new manager) so the manager isn't judged against his own results; empirical-Bayes shrinkage (*k* = 55 games) | Split-half r **0.14** (odd vs even games, 334 tenures of 40+ games) | — | **Weak but real.** Shown as "mostly luck with some skill underneath" |
| F2b | Does sacking the manager work? | Mean PAE around all 271 mid-season changes with 10+ games either side, against clubs on an equally bad 10-game run that kept their manager (matched within ±0.05) | Last 10 before **−0.36**/game · new manager's first 10 **+0.06** · kept-manager control **0.00** | Control: clubs that kept the manager | **Finding:** most of the bounce is a team drifting back to its level; new managers add a small real edge on top (**+0.06** a game, 95% CI +0.01 to +0.11) |
| F3 | Who does each team depend on? | Results residual with vs without the player (only games since he joined; cameos under 45 minutes excluded), shrunk | Split-half stability **−0.01** (660 players) | — | **Not stable.** Shown as a descriptive with/without line, never a ranking |
| F4 | Where is a player's value heading? (deep learning) | GRU over up to six seasons with 10/50/90% quantile heads (pinball loss), forecasting 1–3 seasons ahead; evaluated on sequences ending 2022 (2023–25 outcomes), then **refit one window later** before shipping | Median error (log value) **0.401 / 0.567 / 0.681** at 1/2/3 seasons; 80% band covers **79% / 81% / 81%** | Ageing curve by position × age: **0.405 / 0.583 / 0.711** (1-season gain 95% CI +0.002 to +0.006) | **Shipped.** Small but real edge at one season, larger at three; the real value is the calibrated range |

What the review changed: (1) Elo learned from the manager's own results, which pushed the
odd/even check negative by construction (r was −0.10, now +0.14); (2) the bounce only counted
managers who lasted 30 games, inflating it (+0.22, now +0.06), and had no control group; (3) F1
dropped players who moved and never played; (4) F1's "pre-move" value could come from after a
winter move; (5) the shipped career model had only seen careers up to 2016. All fixed, with
tests. Career forecasts are capped at the highest valuation on record and not made below
€200k (outside the training range). F4 has a hard publishing gate; F1 falls back to the price
model automatically.

## Fantasy Premier League suggester

`python -m touchline.fpl.run_fpl [--train]` builds `fpl-bundle.json.gz`: expected FPL points for
every player over the next six gameweeks, pre-solved Wildcard and Free Hit squads, and the model's
evaluation. Retrained weekly; re-scored daily from live FPL data (prices, injury news, fixtures).

**Model (component expected points).** A LightGBM classifier predicts minutes (none / 1-59 / 60+)
from recent minutes and starts. Goals and assists come from each player's xG and xA per 90, shrunk
toward his position's average and scaled by fixture strength from Touchline's Elo and match model.
Clean sheets and goals conceded come from the match model; saves, bonus, defensive contributions
and cards from shrunk per-90 rates. FPL's scoring rules for the season turn these into points.
Every feature for a gameweek uses only earlier gameweeks.

**Data.** Training: 2022/23-2024/25 from the open
[vaastav/Fantasy-Premier-League](https://github.com/vaastav/Fantasy-Premier-League) archive (MIT).
Test: 2025/26, held out. Live: the public FPL API.

**Result on 2025/26** (13,533 player-gameweeks of players with recent minutes, 37 gameweeks), against
FPL's own expected points (`xP`) from the same archive:

| | Touchline | FPL's own |
|---|---|---|
| Average miss (points per player-gameweek) | **1.84** | 2.15 |
| Rank correlation with actual points | **0.51** | 0.14 |
| Captain backtest (15 most-owned players each week, points × 2) | **518** | 506 |
| Minutes model (Brier, lower is better) | **0.251** | 0.328 ("same as last week") |

The accuracy gain holds up: the 95% interval for the improvement in average miss is +0.16 to +0.44
points. The captaincy edge is small (12 points over a season), so it is reported as "slightly
better", not as a reliable advantage. If a future retrain stops beating FPL on both measures, the
bundle ships FPL's own numbers and says so.

**Limits.** The archive has no injury flags, so live availability (`chance_of_playing`) caps the
minutes prediction at forecast time. Defensive-contribution points only exist from 2025/26, so they
start from stated priors and learn from each player's games. Transfermarkt data stops at July 2026,
so fixture strength uses end-of-2025/26 Elo ratings until it updates.

## Layout

```
touchline/
  ingest/     download, DuckDB loading, football-data client, club-name matching
  features/   per-appearance and per-season player features
  models/     one module per model (elo, match_model, season_sim, valuator, form,
              workload, similarity, budget, trending)
  season.py   live-season club snapshot (Elo continued into 2026/27, table, projections)
  export/     bundle sanitising and writing
  run.py      orchestration + baseline gate
tests/        48 unit tests on small synthetic data (no network)
```

## Data and limitations

- **Transfermarkt open dataset**, CC0. Market values are crowd-sourced estimates, so the
  valuator learns the *consensus* value, not a transfer fee.
- **football-data.org** free tier (10 requests/minute) supplies the live season's results and
  fixtures for the club side.
- The player dataset currently ends at 2025/26, so player cards show that season (labelled in the
  app). When the dataset adds a new season, the pipeline advances automatically.
- There are no injury records, so workload is a risk *index*, never an injury probability.
- Four 2026/27 clubs are new to the dataset (Coventry, Racing Santander, Elversberg, Le Mans).
  They start from a bottom-of-league Elo rating.
