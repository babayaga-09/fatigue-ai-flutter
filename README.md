# Touchline

Football, read in seconds: match odds, fair values and form, from models tested on a season they never saw.

<p>
  <img src="docs/screenshots/home.png" width="23%" alt="Home: the matchday cover, each club's star printed as a halftone in its colours">
  <img src="docs/screenshots/club.png" width="23%" alt="Club page: manager record and who they lean on">
  <img src="docs/screenshots/player.png" width="23%" alt="Player page: the career curve forecast with its range">
  <img src="docs/screenshots/scout.png" width="23%" alt="Scouting: Ready for the Big Five and the budget planner">
</p>

## What it does

- **Home**: a matchday-programme cover for the week's biggest match (each club's star as a halftone in its colours, the win/draw/loss strip), then the inside pages: who's running hot, Ready for the Big Five, the sacking-bounce finding, clubs in form, power rankings, bargains and an overworked watch.
- **Clubs**: live tables for the top five leagues, title, top-four and bottom-three odds from 10,000 simulations, and luck-adjusted manager records. Club pages show who the team leans on.
- **Players**: 2,600+ players with search, filters, fair value against market price and the reasons behind it, a five-game forecast, a career curve (value 1–3 seasons out, with its range), a workload index and lookalikes.
- **Scouting**: feeder-league players ready for the Big Five, ranked honestly; give it a budget and positions and it picks the best set of signings, solved exactly on the phone. Or start from a player and find a cheaper version.

## How it works

```mermaid
flowchart LR
  TM[Transfermarkt open data] --> P[pipeline/ · Python]
  FD[football-data.org] --> P
  P -->|8 models + baseline gate| B[(touchline-bundle.json.gz)]
  B -->|GitHub Release, weekly| A[app/ · Flutter APK]
  B -->|beside the web build| W[GitHub Pages demo]
```

A weekly GitHub Action rebuilds the data, retrains and re-scores every model, and publishes one gzipped JSON file. If any model stops beating its simple baseline, nothing is published. The app ships with a copy of the data, works offline, and swaps in the newer file when it has signal.

## Results

Every number is measured on the **2025/26 season, held out from training** (time-based split).

| Model | What it predicts | Result | Simple baseline |
|---|---|---|---|
| Club Elo | Match winner | **68.9%** of decisive games | Always pick the home team: 59.0% |
| Elo-Poisson + Dixon–Coles | Win / draw / loss odds | RPS **0.203**, log-loss **0.996** | Base rates: RPS 0.229, log-loss 1.072 |
| LightGBM valuator (+ TreeSHAP) | Fair market value | Typical error **€4.7M**, median error **29%**, R² (log) **0.85** | Age × position × league median: €10.9M, 60% |
| GRU (deep learning) | Goal involvements, next 5 games | MAE **0.779**, Poisson deviance **1.165** | Poisson GLM: 0.795 / 1.196 · recent average: 0.828 / 1.421 |
| Monte Carlo season | Title / top 4 / bottom 3 | 10,000 simulations per league | — |
| Workload index + Isolation Forest | Load risk band | A risk index, not an injury prediction | — |
| k-NN on per-90 profiles | "Plays like X" | — | — |
| 0/1 integer programme | Best signings for a budget | Exact optimum (matches between Python and Dart) | Greedy value-per-euro |

The GRU's edge over a well-built Poisson GLM is small (about 3% on deviance). Sequence modelling helps a bit with football scoring, not a lot, and the README says so rather than leaning on a weak baseline. Details: [`pipeline/README.md`](pipeline/README.md).

### v2: four new questions, tested honestly

| Analysis | Verdict |
|---|---|
| **Career curve**: GRU with quantile heads forecasts each player's value 1–3 seasons out | Beats the ageing curve (median log error 0.401 vs 0.405 at one season, 0.681 vs 0.711 at three); the 80% band holds 79–81% of outcomes |
| **Ready for the Big Five**: will a feeder-league player become a regular after moving up? | LightGBM **lost** to market value alone on 713 moves (AUC 0.626 vs 0.651), so the app ranks by price and says so |
| **Sacking the manager**: does the new-manager bounce exist? | Teams sack at −0.36 points a game below expectation; clubs on the same run that kept their manager recover to 0.00, new managers to +0.06. Mostly drift back to level, plus a small real edge (95% CI +0.01 to +0.11) |
| **Manager effect**: points above what the squad should get | Weak but real (split-half r = 0.14): shown as "mostly luck with some skill underneath" |
| **Can't-live-without**: results with vs without a player | Not stable across half-seasons (r = −0.01); shown as a plain with/without line |

A fresh code review caught five method problems in the first version (manager judged against his own results, a survivor-biased bounce, missing failed moves, a post-move valuation, a stale career model); the numbers above are after the fixes. Details: [`pipeline/README.md`](pipeline/README.md).

## Run it

**Data pipeline**: see [`pipeline/README.md`](pipeline/README.md) (`python -m touchline.run`, about 10 minutes).

**App**
```bash
cd app
flutter run                    # emulator or device
flutter test                   # 72 tests, including the planner against the pipeline's optimal answers
flutter build apk --release --dart-define=BUNDLE_URL=https://github.com/<you>/<repo>/releases/download/data-latest/touchline-bundle.json.gz
```
Without `BUNDLE_URL` the APK runs on the data shipped inside it and never calls the network.

**Web demo**: push to GitHub, add the `FOOTBALL_API_KEY` secret, and set Settings → Pages → Source to **GitHub Actions**. The `pages` workflow builds the Flutter web app with the latest data beside it.

## Design

The visual idea is the matchday programme you buy at the turnstile. Players are printed as two-colour halftone portraits in their club's colours (computed on the device from the photo), line-ups and rankings read as numbered team sheets, and win/draw/loss is a printed three-part strip with the figures set inside, never colour alone. Type is Archivo: its narrowest, heaviest cut for mastheads, normal width for reading. See [`DESIGN.md`](DESIGN.md).

## Data, licences, limits

- Player and match history: [Transfermarkt open dataset](https://github.com/dcaribou/transfermarkt-datasets) (CC0). Live season: [football-data.org](https://www.football-data.org) (free tier, their terms).
- Market values are crowd estimates, not transfer fees. Player stats show the latest complete season in the open dataset, labelled in the app.
- There are no injury records, so workload is a risk index only.
- Club colours are hand-picked approximations of traditional colours, not official brand assets. Not affiliated with any club or league.
- Code: MIT. Archivo typeface: SIL Open Font License (`app/assets/fonts/Archivo-OFL.txt`).
