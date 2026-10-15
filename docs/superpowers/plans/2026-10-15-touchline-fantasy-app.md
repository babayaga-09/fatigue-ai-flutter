# Touchline Fantasy: App Implementation Plan (Plan 6)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A Fantasy tab in the Touchline Flutter app: your squad (imported by team ID on Android, picked on web), next-gameweek expected points, best transfers with hit maths, captain/vice, and a chip planner, all from `fpl-bundle.json.gz`.

**Architecture:** A separate FPL bundle loaded with the same offline-first pattern as the main bundle (seed asset, cache, remote; web reads it same-origin). A Dart port of the transfer search and best-XI logic, checked against the Python golden cases. Wildcard and Free Hit squads come pre-solved in the bundle.

**Tech Stack:** Flutter 3.44, Dart, `http`, `shared_preferences`, existing theme/widgets (The Matchday Programme).

**Spec:** `docs/superpowers/specs/2026-10-15-touchline-fantasy-design.md`; consumes Plan 5's `docs/fpl-bundle-schema.md` and `fpl_cases.json`.

## Global Constraints

- Squad rules and hit rule exactly as Plan 5's Global Constraints.
- Team import only on Android/desktop (not web): `https://fantasy.premierleague.com/api/entry/{id}/`, `.../entry/{id}/event/{gw}/picks/`, `.../entry/{id}/history/`.
- Web: squad picker only; squad saved in shared preferences as a list of 15 player ids plus bank.
- Free transfers are editable (0–5); import pre-fills an estimate.
- Visual language: DESIGN.md (The Matchday Programme); no new world.
- When the bundle's `source` is `"fpl"`, the tab says the numbers are FPL's own.

## Review Focus

1. Imported team contains a player missing from the bundle (new signing) — shown as "not in our data", excluded from suggestions; test in Task 3.
2. Squad picker allows an illegal squad (4 from one club, over budget) — save blocked with the reason; test in Task 2.
3. Offline at deadline — tab works from the cached bundle and states its age; test in Task 1.
4. A chip already used — never recommended; test in Task 4.
5. Large text (1.3×) on the team sheet — no overflow; test in Task 5.

---

### Task 1: FPL bundle model and loading
**Files:** Create `app/lib/fpl/fpl_bundle.dart`, `app/lib/fpl/fpl_loader.dart`; Modify `app/lib/state/app_state.dart`, `app/lib/data/platform_io_*.dart`; Test `app/test/fpl_bundle_test.dart`.
- Parse the schema; nulls allowed for news/chance; `FplState` holds the bundle with origin and freshness; loads seed asset `assets/data/fpl-bundle.json.gz`, then cache, then remote (`BUNDLE_URL` dir + `fpl-bundle.json.gz`; web `data/fpl-bundle.json.gz` with the cache-busting query).
- Tests: parse the frozen fixture; missing optional fields; offline keeps the seed and reports its age.

### Task 2: Squad model, validation, picker
**Files:** Create `app/lib/fpl/squad.dart`, `app/lib/fpl/squad_store.dart`, `app/lib/screens/squad_picker_screen.dart`; Test `app/test/fpl_squad_test.dart`.
- `Squad(ids, bank, freeTransfers, chipsUsed)`, `validate(bundle) -> List<String>` (count per position, 3-per-club, budget), persistence in shared preferences.
- Picker: search, position filter, price, running budget, blocked save with reasons.
- Tests: validation reasons; persistence round-trip; picker blocks a 4th player from one club.

### Task 3: Team import (Android)
**Files:** Create `app/lib/fpl/team_import.dart`; Test `app/test/fpl_import_test.dart` with recorded JSON in `app/test/fixtures/fpl_entry*.json`.
- `importTeam(id, http.Client) -> Squad` (picks for the current gameweek, bank, selling values via `entry_history`, chips used from history, free-transfer estimate).
- Errors: unknown id (404) → "No FPL team with that ID"; network → "FPL is not responding".
- Tests: parse recorded responses; missing player flagged; 404 message.

### Task 4: Optimiser port and chip advice
**Files:** Create `app/lib/fpl/fpl_optimiser.dart`; Copy `pipeline/data/out/fpl_cases.json` to `app/test/fixtures/`; Test `app/test/fpl_optimiser_test.dart`.
- `bestXi`, `sellPrice`, `suggestTransfers`, `chipAdvice` mirroring Plan 5 Task 6; Wildcard/Free Hit from the bundle grid (nearest budget ≤ squad value + bank).
- Tests: golden cases match exactly; used chips never recommended; hit rule.

### Task 5: Fantasy tab UI
**Files:** Create `app/lib/screens/fantasy_screen.dart`, `app/lib/screens/fpl_player_sheet.dart`; Modify `app/lib/app.dart` (fifth destination), `app/lib/screens/about_sheet.dart`; Test `app/test/fantasy_test.dart`.
- Header (team or "Pick your squad", deadline countdown, freshness), team sheet XI + bench with next-gw xPts, captain/vice, injury flags; This week's moves (out → in, gain, hit worth it, free transfers editable); chip planner (6 gameweeks); player sheet (per-gw xPts, P(play), why); source note when numbers are FPL's.
- Tests: tab renders from fixture bundle and saved squad; suggestions shown; source note; 1.3× text no overflow; navigation has five destinations.

### Task 6: Verify, review, ship
- Seed bundle + test fixture copied from the pipeline; emulator and web checks; impeccable finish review of the tab against DESIGN.md; code review; README/PRODUCT.md updates; merge; push; release APK.
