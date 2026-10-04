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
up to 2024/25 used for fitting).

| # | Model | What it predicts | Method | Result | Baseline |
|---|---|---|---|---|---|
| M1 | Club power rating | Team strength | Elo with home advantage and margin-of-victory scaling; K and home edge tuned on 2024/25 | Picks the winner of **68.9%** of decisive league games | Home team always wins: 59.0% |
| M2 | Match predictor | Home / draw / away probabilities and expected goals | Poisson goal model driven by the Elo gap, with Dixon–Coles low-score correction | RPS **0.203**, log-loss **0.996** (1,752 games) | Historical base rates: RPS 0.229, log-loss 1.072 |
| M3 | Season projector | Title / top-4 / relegation odds | 10,000 Monte Carlo simulations of the remaining fixtures using M2 | — | — |
| M4 | Player valuator | Fair market value | LightGBM on performance, age, role, league and club strength; per-player TreeSHAP explanations | Typical error **€4.7M**, median error **29%**, R² (log) **0.85** | Median by age × position × league: €10.9M, 60% |
| M5 | Form forecast (deep learning) | Goal involvements in the next 5 games | GRU over the last 10 appearances plus position and age, Poisson loss; compared on validation with a Poisson GLM, and the better one ships | Poisson deviance **1.164**, MAE 0.78 | Recent average × 5: 2.716 · Poisson GLM: 1.196 |
| M6 | Workload index | Load risk band (not injury probability) | Season minutes, congested appearances and the acute:chronic workload ratio; an Isolation Forest flags unusual loads | — | — |
| M7 | Similar players | "Plays like X" | k-NN on standardised per-90 profiles within a position group | — | — |
| M8 | Transfer budget planner | Best signings for a budget | 0/1 integer programme (SciPy MILP) maximising fair value within budget and positional needs | Always ≥ greedy | Greedy by value-per-euro |

The GRU's lead over the classical GLM is small (1.164 vs 1.196 deviance), and it's reported here
as it is. The big gain is over naive averaging.

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
