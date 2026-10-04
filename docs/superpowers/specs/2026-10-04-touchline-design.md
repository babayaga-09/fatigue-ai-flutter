# Touchline — Design Spec

*Working name; rename freely. Date: 2026-10-04. Supersedes `fatigue_api` + `fatigue_predictor_app`.*

## 1. Goal

A football app for fans that opens on a **live dashboard** — who's trending, which clubs are
in form, club power ratings, match predictions — with players one tap deeper. Built on **real
data** and **real, evaluated ML / deep-learning models**, packaged as an installable Android APK
and a clean GitHub repo.

**Primary purpose:** CV / portfolio centrepiece. **Secondary:** structured so it can become a
real product later without a rewrite.

**Success criteria**
1. A friend installs the APK and it works on their phone — no laptop server, no setup.
2. Home screen is understandable in under 10 seconds by a casual fan.
3. Every model has a held-out evaluation vs a simple baseline, reported in the README.
4. `git clone` → one command reproduces data, models, and metrics.
5. Data refreshes weekly with no manual work.

**Non-goals (v1):** user accounts, live in-match scores, LLM chat (designed-for, built in v2),
iOS release, event-level stats (StatsBomb — v2).

## 2. Why rebuild instead of patching

The current backend's models were trained on randomly generated data, and per-match player stats
are hard-coded by position (every midfielder = 65 passes). football-data.org's free tier has no
per-player stats, so nothing real could be learned from it. The app also only works while a
laptop runs the server. Keeping the Flutter knowledge and screens-as-inspiration; replacing the data
and model layer entirely.

## 3. Data

- **Primary:** open Transfermarkt dataset (`dcaribou/transfermarkt-datasets`, CC0). Tables used:
  `players`, `player_valuations`, `appearances`, `games`, `club_games`, `clubs`,
  `competitions`, `transfers`, `game_lineups`.
- **Upcoming fixtures:** football-data.org (existing token, stored as a GitHub Actions secret —
  never shipped in the app).
- **Scope:** top 5 European leagues (PL, LaLiga, Bundesliga, Serie A, Ligue 1), seasons 2012+.
- **Freshness (verified 2026-10-04):** the Transfermarkt dataset ends at 2025/26. Club side
  (table, Elo, predictions, projections) is live via football-data.org; player side shows the
  latest season in the dataset, labelled in-app, and advances automatically when the dataset does.
- **Known gap, stated in-app and README:** no injury records → workload is a *risk index*, not an
  injury probability.

## 4. Architecture

```
touchline/
├── pipeline/        Python: ingest → features → train → evaluate → score → export
│   ├── ingest/      download + load into DuckDB
│   ├── features/    per-player / per-club feature tables
│   ├── models/      one module per model (below)
│   ├── export/      writes the app bundle
│   └── tests/
├── app/             Flutter Android app (offline-first, reads the bundle)
├── api/             (v2) small FastAPI service for "Ask the Scout" chat
├── docs/            specs, model cards, screenshots
└── .github/workflows/
    ├── ci.yml       lint + tests (pipeline & app)
    └── refresh.yml  weekly: run pipeline → publish bundle to GitHub Releases
```

**Data flow:** weekly GitHub Action → pipeline builds `touchline-bundle.json.gz` (or SQLite)
→ attached to a GitHub Release → app fetches latest on launch, caches locally, falls back to the
cached / bundled copy when offline. The app ships with a seed bundle so first launch works offline.

Each pipeline module is independently runnable and tested; the bundle schema is versioned and is
the only contract between pipeline and app.

## 5. Models (the ML story)

| # | Model | Target | Method | Baseline it must beat |
|---|---|---|---|---|
| M1 | **Club power rating** | Strength rating per club | Elo with home advantage + margin-of-victory, tuned on history | "Home team wins" pick (favourite accuracy on decisive games) |
| M2 | **Match predictor** | P(home / draw / away), expected goals each side | Poisson goals driven by the M1 Elo gap + Dixon–Coles low-score correction | Historical home/draw/away base rates |
| M3 | **Season projector** | Final position / title / top-4 / relegation % | Monte Carlo (10k sims) over remaining fixtures using M2 | Current table order |
| M4 | **Player valuator** | Fair market value | LightGBM on age, position, minutes, G+A/90, league, club strength, value trend; SHAP explanations | Median value by age × position × league |
| M5 | **Form forecast** (deep learning) | Goal involvements over next 5 apps | GRU over last 10 appearances + static position/age; compared on validation with a Poisson GLM and the better one ships | Naive "recent average × 5" (GLM also reported) |
| M6 | **Workload index** | Load risk band | ACWR (acute:chronic workload) on minutes + congestion + age; Isolation Forest flags anomalous loads | — (rule-based index; documented, not "accuracy") |
| M7 | **Player similarity** | "Plays like X, costs less" | Standardised per-90 profile → embedding → k-NN | — |
| M8 | **Transfer budget planner** | Best signings within budget | Integer programming (knapsack with position constraints) maximising M4-value-adjusted output | Greedy by value-per-euro |

**Evaluation rules:** time-based splits only (train on past seasons, test on the latest) — no
random splits, no leakage. Metrics: log-loss / Brier (M2), MAE & MAPE (M4), Poisson deviance &
MAE (M5). Each model gets a short model card in `docs/models/`.

**"Trending" score** (drives the home feed): blend of recent G+A/90 vs the player's own baseline,
latest valuation change, and M5 forecast. Transparent formula, documented.

**Autonomous agent (v2, designed now):** "Ask the Scout" — an LLM agent in `api/` that calls
M4/M5/M7/M8 as tools and writes a plain-language answer. v1 ships a **non-LLM planner** for the
preset flows (e.g. "Build my €100M window") so the feature works free and offline.

## 6. App experience

**Navigation:** 4-tab bottom bar.

1. **Home (dashboard)** — vertical feed of cards:
   - Hero: next big fixture with M2 win/draw/loss bar
   - Trending players (horizontal carousel, with why: "+4 G/A last 5", "value ↑ €8M")
   - Clubs in form (last-5 strip + Elo change)
   - Power rankings top 10 (M1)
   - Bargains: most undervalued players (M4)
   - Overworked watch (M6)
   - League switcher chip row at top (All / PL / LaLiga / …)
2. **Clubs** — league table with M3 projections (title / top-4 / relegation %), power rating;
   club page: form, fixtures with predictions, squad sorted by value / form, workload watch.
3. **Players** — browse by filters (league, position, age, value) + search; player page:
   fair value vs market value with SHAP "why" bars, form forecast, workload gauge, similar players,
   transfer & value history chart.
4. **Scout** — Transfer budget planner (budget, positions, age band → signings list) and
   "Find similar for less". Placeholder for the v2 chat.

Plus: compare two players (from player page), favourites (local), settings (data freshness,
about the models).

**Copy rule:** every number has a plain-words line next to it ("Bargain: worth ~€12M more than
his price"). Model jargon only lives in an "How this works" sheet.

**Design:** full visual redesign via the `impeccable` skill, with `ui-ux-pro-max` for palette /
type / chart guidance. Direction to be chosen during implementation (premium sports-broadcast
feel, dark-first, readable charts). Dark + light themes, accessible contrast, 60fps scrolling.

## 7. Error handling

- No network → cached bundle, banner shows "Data from <date>".
- Bundle schema mismatch → keep using previous bundle, prompt app update.
- Pipeline step failure in CI → workflow fails, previous Release stays live (app unaffected).
- Missing data for a player (few minutes) → model outputs hidden with "Not enough minutes yet",
  never a fabricated number.

## 8. Testing

- Pipeline: pytest unit tests per feature/model module; a small fixture dataset for fast CI;
  leakage test (assert no test-season rows in training).
- Models: evaluation script outputs `metrics.json`; CI fails if a model stops beating its baseline.
- App: widget tests for each card + bundle parsing tests; `flutter analyze` clean.

## 9. Deliverables

1. GitHub-ready monorepo: README (screenshots, architecture diagram, model results table,
   reproduce steps), LICENSE (MIT), model cards, CI badges.
2. Release APK (`app-release.apk`) attached to a GitHub Release.
3. Weekly auto-refresh workflow.

## 10. Build order

1. Pipeline: ingest + DuckDB + club Elo/match predictor/season sim (M1–M3) → first bundle.
2. App skeleton + design system (impeccable) + Home & Clubs on real bundle.
3. Player models M4–M7 + Players tab.
4. Budget planner M8 + Scout tab.
5. CI, weekly refresh, README, release APK.
6. (v2) `api/` + Ask the Scout LLM agent; StatsBomb enrichment.

## 11. Open items / risks

- Exact dataset download URL & table schemas to be confirmed at step 1.
- GitHub CLI not installed; pushing the repo needs `gh` or manual remote setup (user's account).
- APK signing key generated locally; kept out of git.
- Transfermarkt market values are crowd-sourced estimates — valuator learns "consensus value",
  stated as such.
