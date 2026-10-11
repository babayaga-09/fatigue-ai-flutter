# Touchline v2 — Design Spec

*Date: 2026-10-12. Builds on `2026-10-04-touchline-design.md` (v1, shipped). Decisions confirmed by Aryan in chat.*

## 1. What changes

1. **Four new analytics** that standard football apps (FotMob, Sofascore, OneFootball) don't offer, each built from the data we already have and evaluated honestly against a simple baseline.
2. **A full visual replacement**: the Terrace Scarf world is retired; the new world is **The Matchday Programme** (impeccable direction roll, seed `37b0e2b4`, candidate 3 of 7). ui-ux-pro-max supplied structural chart guidance (horizontal bars with value labels for comparisons; line with uncertainty band for trajectories); its default sports palette (Tailwind blue + orange) is explicitly rejected as the "AI look".
3. **Publish** to `https://github.com/babayaga-09/fatigue-ai-flutter.git`, **replacing its history** (force-push of `main`; Aryan chose this knowing the old two commits disappear).

Unchanged: data sources, the weekly bundle pipeline, offline-first loading, the budget planner, tests-first, the baseline gate.

## 2. New analytics

All four ship as additive bundle keys (schema stays `1`; old readers ignore unknown keys). Each model gets a held-out evaluation in `metrics.json` and a plain-words line in "How this works". Population rules from v1 hold: no model output for players under 900 minutes.

### F1. Ready for the Big Five (scouting radar)
- **Question:** which players in feeder leagues would become regulars if they moved to a top-five league?
- **Feeder leagues:** Eredivisie (NL1), Liga Portugal (PO1), Belgian Pro League (BE1), Süper Lig (TR1), Scottish Premiership (SC1), Russian Premier League (RU1), Ukrainian Premier League (UKR1), Greek Super League (GR1), Danish Superliga (DK1) — 14 seasons each in the dataset.
- **Training label:** players whose main league in season *s* was a feeder league and who played top-five league football in *s+1*; **success = at least 40% of their new club's league minutes in *s+1*** ("became a regular").
- **Model:** LightGBM classifier on age, position, feeder league, minutes share, G/A per 90, goals and assists per 90, club Elo, log market value, previous-season output. Time split on move season (train ≤ 2022, validate 2023, test 2024 moves).
- **Baseline:** logistic regression on log market value alone (the "just buy the expensive one" rule). Gate: ROC-AUC must beat it.
- **Also shown:** *translated G/A per 90* = feeder output × league conversion factor (median ratio of movers' top-five vs feeder G/A per 90, per league).
- **Bundle:** `prospects[]` — top 150 current feeder-league players (≥ 900 league minutes in the latest season) by P(regular): id, name, img, club name, league, position, age, market value, G/A per 90, translated G/A per 90, `p_regular`, and the top 3 value drivers.

### F2. Manager effect (luck-adjusted)
- **Question:** is this manager getting more or less out of his squad than its strength predicts?
- **Method:** for every top-five league game from 2014, expected points for each side come from the v1 match model's pre-match probabilities (3·p_win + p_draw). Points above expected (PAE) per game = actual − expected, attributed to the manager on the bench (manager names are on ~100% of games). Tenure PAE is shrunk toward 0 with an empirical-Bayes prior (`n / (n + k)`, *k* fitted from the data) so a 6-game spell can't top the table.
- **Honesty check:** split-half reliability — correlation of a manager's PAE in odd vs even games across tenures of 40+ games. Reported as is; if near zero, the app says "mostly noise" for that metric.
- **New-manager bounce:** across all mid-season changes, mean PAE in the first 10 games vs the following 20. Published as a finding, whatever it shows.
- **Bundle:** `managers[]` — each current top-five manager (latest name on his club's 2025/26 games): name, club id, games, PAE per game (shrunk and raw), per-38 equivalent, first-10 PAE; `models.manager_effect` holds reliability and the bounce finding.

### F3. Can't-live-without index
- **Question:** who does each team actually depend on?
- **Method:** for each current top-five player in the latest season, split his club's league games into *played* (≥ 45 minutes) and *missed*. Index = mean results-residual (actual − expected points, opponent strength included via the match model) when he played minus when he missed, shrunk by the number of missed games; needs ≥ 3 missed games. Correlation, not causation — said in the app.
- **Honesty check:** split-half stability on the previous season (first vs second half of games), reported in `metrics.json`.
- **Bundle:** per player `dependency: {index, played, missed}` (null when ineligible); per club the top five go on a "team sheet".

### F4. Career curve (deep learning)
- **Question:** where is this player's value heading over the next three seasons, and how sure are we?
- **Model:** GRU over the player's yearly sequence (up to six seasons: log value at season end, age, minutes, G/A per 90, club Elo, position) with three quantile heads (10th, 50th, 90th) trained with pinball loss, predicting log value 1, 2 and 3 seasons ahead.
- **Baseline:** empirical ageing curve — median log-value change by position and age.
- **Evaluation:** sequences ending in season ≤ 2022 predicting 2023–2025; report median-forecast error per horizon vs baseline, and 80% interval coverage (target ≈ 80%). Gate: horizon-1 error must beat the ageing curve.
- **Bundle:** per player `career: {p10[3], p50[3], p90[3], peak_value, peak_age, vs_curve}` where `vs_curve` is "ahead", "on" or "behind" the position's ageing curve.

## 3. App changes

- **Navigation (4 tabs):** Home · Clubs · Players · Scouting.
  - **Home:** the matchday cover (big fixture), then inside pages: Ready for the Big Five (top 5), Can't-live-without team sheet (featured club), Manager over-/under-performers, form, rankings, bargains, workload.
  - **Clubs:** table / odds / **managers** views; club page gains the manager card and the team sheet.
  - **Players:** player page gains the **career curve** (fan chart) and **dependency** line.
  - **Scouting** (renamed from Scout): Big Five radar (full list + filters), budget planner, cheaper lookalikes.
- **Design world — The Matchday Programme** (Operate mode: the world lends type, palette, density and one signature move; Material 3 shell and controls stay standard):
  - **Signature move:** player portraits printed as **two-colour halftone in the club's colours** (CPU halftone from the decoded photo, cached; plain duotone fallback; initials fallback when no photo).
  - Condensed programme headline face + a workhorse text face (chosen during the build from the type ranking, avoiding the overused defaults impeccable lists); numbers tabular.
  - Each screen takes its accent from the club in focus; neutral programme stock elsewhere.
  - Team-sheet layouts (numbered rows) for dependency and line-up style lists.
  - The direction contract is rewritten in `.impeccable/surfaces/app-lib-main-dart.md`; DESIGN.md is replaced from the built result by the impeccable documenter after a finish review.

## 4. Publishing

- Push `main` to `babayaga-09/fatigue-ai-flutter`, force-replacing its history (approved). README links and the Pages workflow use the repo name automatically.
- After pushing: Aryan adds the `FOOTBALL_API_KEY` secret and enables Pages; APK rebuilt with `BUNDLE_URL` pointing at that repo's `data-latest` release.

## 5. Risks and limits

- Manager and dependency effects are noisy; the app shows the reliability numbers and says so when a metric is mostly noise.
- Feeder-league coverage is 9 leagues; South American and other leagues have only two seasons in the dataset, so they're excluded.
- The career curve inherits Transfermarkt's crowd valuations; it forecasts market value, not ability.
- 2026/27 manager names aren't in the live feed; manager cards show 2025/26 tenure-to-date, labelled.

## 6. Build order

1. Pipeline: F1–F4 modules with tests, evaluation and gates; bundle keys; schema doc.
2. App: new design world (tokens, type, halftone portrait), then each new screen section, then restyle existing screens.
3. Verify on device and web; impeccable finish review; documenter → DESIGN.md.
4. Final code review, merge, force-push to GitHub, rebuild APK with `BUNDLE_URL`.
