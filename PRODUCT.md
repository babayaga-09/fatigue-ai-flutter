# Product

<!-- impeccable:product-schema 1 -->

## Platform

android

## Stack

Flutter (Dart), one codebase built two ways: a release Android APK (primary) and a Flutter web build hosted on GitHub Pages as a click-to-try demo. Data comes from a weekly gzipped JSON bundle produced by `pipeline/` (Python) and published to a GitHub Release (`data-latest`); the contract is `docs/bundle-schema.md`. No backend server in v1.

## Users

Primary: a casual football fan doing a quick check — on the bus, at halftime, before the weekend's games — for one or two minutes. They want plain answers: who's in form, who wins this weekend, is my club safe, who's a bargain. They are not analysts and won't read charts that need explaining.

Secondary: recruiters and interviewers evaluating Aryan's work (the app is a CV centrepiece). They see the same app; the depth for them lives in the "How this works" sheet and the GitHub README, not on the main screens.

## Product Purpose

Touchline turns real football data and evaluated machine-learning models into a dashboard any fan can read in seconds: club power rankings, match win/draw/loss chances, season title/top-4/relegation odds, player fair value vs market price, form forecasts, workload, similar players, and a transfer-budget planner. Success: a friend installs it, understands the home screen in under ten seconds, and comes back on matchday.

## Positioning

Every number is a model output that was tested against a simple baseline on a season it never saw — and the app says so in plain words. Predictions come with the "why" (e.g. what drives a player's value). Where data is thin, the app says "not enough minutes yet" instead of inventing a number.

## Operating Context

- Glance usage on a phone, often one-handed, often outdoors or in a stadium; sessions of 1–2 minutes.
- Offline-first: the app ships a seed bundle and caches the latest; it must work with no signal and show how fresh the data is.
- Data cadence is weekly. Club side (tables, Elo, fixtures, projections) is the live 2026/27 season; player cards show the latest complete season in the dataset (currently 2025/26) and must label it.
- Coverage: top five European leagues (Premier League, LaLiga, Bundesliga, Serie A, Ligue 1).

## Capabilities and Constraints

- Four areas: Home (matchday cover + inside pages), Clubs (table, odds, managers), Players, Scouting (Ready for the Big Five, budget planner, "find similar for less"). Player comparison and local favourites. "How this works" shows data freshness and every model's tested result.
- v2 analytics and how each may be presented: the **career curve** (GRU, quantile range) ships as a forecast with its range; **Ready for the Big Five** is ranked by the price-only model because the ML model lost to price, and the app says so; the **manager effect** is labelled by its split-half agreement (weak); **with/without** is a description of this season, never a ranking of importance; the **sacking bounce** is stated against clubs that kept their manager, worded by its interval.
- `null` in the bundle always means "not enough data" and must render as a friendly empty state, never 0.
- Workload is a risk index; it must never be presented as injury probability.
- Market values are crowd-sourced consensus estimates (Transfermarkt), not transfer fees.
- Crests come from football-data.org URLs and player photos from Transfermarkt URLs; both can be missing and need graceful fallbacks.
- "Ask the Scout" LLM chat is deferred; the Scouting tab ships the non-LLM planner.
- The budget planner runs on-device and must match the pipeline's golden cases (`pipeline/data/out/budget_cases.json`).

## Brand Commitments

- Name: Touchline.
- Voice: sharp pundit with dry wit — confident one-liners ("Running hot: 5 G/A in 5", "Priced like a backup, plays like a starter"). Opinionated, never silly, never hype-shouting. Model jargon only in "How this works".

## Evidence on Hand

- Held-out 2025/26 model results in `pipeline/README.md` and the bundle's `models` section (e.g. Elo picks 68.9% of decisive games vs 59.0% baseline; valuator typical error €4.7M vs €10.9M). These are the only performance claims the app may make.
- No user testimonials, downloads, ratings, press, or partnerships exist — never fabricate them.
- No official league, club, or player endorsement; no club or league logos beyond the crests the data API provides.

## Product Principles

1. Answer first, explain on tap: every card leads with a plain-language verdict; the model detail is one tap away.
2. Honest by construction: show uncertainty and data freshness; never fake a number to fill a slot.
3. Ten-second home screen: a casual fan should get the weekend's story without scrolling far.
4. Works without signal: offline is a normal state, not an error.

## Accessibility & Inclusion

Readable outdoors and one-handed: large touch targets, strong contrast in both themes, colour never the only carrier of meaning (win/draw/loss, risk bands), text scaling respected.
