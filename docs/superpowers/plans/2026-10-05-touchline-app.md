# Touchline App (Plan 2 of 2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A Flutter app (Android APK + web demo) that renders the Touchline bundle as a fan dashboard in the "Terrace Scarf" visual world, with an on-device transfer-budget planner, plus the pipeline additions it needs.

**Architecture:** One Flutter project in `app/`. A pure-Dart data layer (`lib/data/`: bundle models, loader, selectors, planner) is unit-tested against a frozen real bundle. A `ChangeNotifier` AppState exposed through an `InheritedNotifier` feeds four Material 3 destinations (Home, Clubs, Players, Scout) built from a small set of scarf widgets. The app loads local data first (cache, then the seed asset shipped in the app), then refreshes from the network in the background: a GitHub Release on Android, a same-origin file on the web demo.

**Tech Stack:** Flutter 3.44.8 / Dart 3.12, packages `http`, `archive`, `path_provider`, `shared_preferences`; Jersey 10 (OFL) bundled; Python pipeline from Plan 1.

**Spec:** `docs/superpowers/specs/2026-10-04-touchline-design.md` · Product: `PRODUCT.md` · Direction contract: `.impeccable/surfaces/app-lib-main-dart.md` · Data contract: `docs/bundle-schema.md`

## Global Constraints

- Platform android (Material 3 rules from impeccable `reference/android.md`); also builds for web. Flutter at `C:\flutter\bin\flutter`.
- Navigation: `NavigationBar` with 4 destinations (Home, Clubs, Players, Scout) below 840dp width; `NavigationRail` at ≥ 840dp. System Back always works (plain `Navigator` routes).
- Touch targets ≥ 48×48dp. Text sizes come only from `Theme.of(context).textTheme` roles; never hard-code sizes in screens.
- Brand palette: pitch `#0F3D2E`, pink `#F2A7C3`, light ground `#EDEDE8`, dark ground `#0D1311`, ink `#16181D`. Result states: win `#1E7A46` solid knit, draw `#7D838C` cross-stitch, loss `#C8102E` dropped stitch. Colour is never the only carrier: every state also has a pattern or a text label.
- Stitch type: family `Jersey` (Jersey 10, OFL), used only for displayLarge (56), displaySmall (37.333) and headlineSmall (18.667). These are whole-stitch sizes (1 stitch = 75/1400 em, so 18.667 × n gives n px per stitch). Body and UI text: Roboto (theme default). Numbers use tabular figures.
- Elevation: only bottom sheets float; cards are flat tonal surfaces (`elevation: 0`).
- `null` in the bundle is rendered as a friendly empty state ("Not enough minutes yet"), never as `0`.
- Workload copy always says "risk index"; never "injury chance".
- Voice: sharp pundit, dry wit, never hype (PRODUCT.md).
- Data claims shown in-app come only from `bundle.models`.
- No direction-contract text in source code, comments or assets.
- Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Work happens on branch `feat/app`.
- Read `C:\Users\91750\.claude\skills\impeccable\reference\craft-floor.md` before the first UI task (Task 8).

## Review Focus

1. **Unsupported or corrupt bundle** (schema bump, truncated download). The app keeps the previous data (cache or seed) and never shows a blank or broken screen. Tests: Task 4.
2. **Nulls everywhere a player has < 900 minutes** (`fair_value`, `forecast_ga5`, `trend.score`, `workload`). Cards show the empty note and never "€0" or "0.0". Tests: Tasks 3, 10, 12.
3. **Images fail to load** (offline, CORS on web, 404 crests or photos). The crest falls back to a stitched monogram and the photo to initials. Test: Task 9.
4. **League filter with no data** (e.g. no fixtures for a league this week, or an international break). Sections show a sentence instead of collapsing to nothing. Tests: Tasks 5, 10.
5. **Budget planner infeasible input** (budget too small, or 0 positions). The app shows a clear message, never a crash or an empty list without explanation. Tests: Tasks 6, 13.

---

## File Structure

```
pipeline/touchline/ingest/club_colours.json   fd team id -> [primary, secondary] hex (hand-checked)
pipeline/touchline/season.py                   + "colors" on club records
pipeline/touchline/models/trending.py          "Value up" label fix
app/
  pubspec.yaml, analysis_options.yaml
  assets/fonts/Jersey10-Regular.ttf, assets/fonts/OFL.txt
  assets/data/touchline-bundle.json.gz          seed bundle (copied from pipeline output)
  lib/main.dart                                 runApp + AppState bootstrap
  lib/app.dart                                  MaterialApp, themes, Shell (nav bar / rail)
  lib/data/bundle.dart                          models + JSON parsing
  lib/data/bundle_loader.dart                   decode, loadLocal, fetchNewer, BundleIo
  lib/data/seed.dart                            seed asset reader
  lib/data/platform_io.dart (+ _native, _web)   per-platform BundleIo
  lib/data/selectors.dart                       pure queries for every screen
  lib/data/planner.dart                         exact budget planner (Pareto knapsack)
  lib/data/prefs.dart                           Prefs interface + SharedPreferences impl
  lib/state/app_state.dart                      AppState + AppScope
  lib/theme/tokens.dart, lib/theme/theme.dart
  lib/copy/voice.dart                           pundit-voice lines (pure)
  lib/format.dart                               money / percent / date formatting (pure)
  lib/widgets/scarf.dart                        Scarf painter + HalfAndHalfScarf + FormScarf + ClubScarf
  lib/widgets/crest.dart, player_avatar.dart, empty_note.dart, section.dart, stat_bar.dart, value_chart.dart
  lib/screens/home_screen.dart
  lib/screens/clubs_screen.dart, club_detail_screen.dart
  lib/screens/players_screen.dart, player_detail_screen.dart, compare_screen.dart
  lib/screens/scout_screen.dart
  lib/screens/about_sheet.dart
  test/fixtures/bundle.json.gz, test/fixtures/budget_cases.json
  test/helpers.dart, test/*_test.dart
  tool/make_icons.py                            pixel-stitch launcher/web icons
.github/workflows/ci.yml (+ app job), .github/workflows/pages.yml
README.md (root)
```

---

### Task 1: Pipeline — club colours and the "Value up" label

**Files:**
- Create: `pipeline/touchline/ingest/club_colours.json`
- Modify: `pipeline/touchline/season.py` (league_snapshot club record; offline_clubs), `pipeline/touchline/models/trending.py:_reasons`, `docs/bundle-schema.md`
- Test: `pipeline/tests/test_season.py`, `pipeline/tests/test_trending.py`

**Interfaces:**
- Produces: club record key `"colors": ["#RRGGBB", "#RRGGBB"] | null` (additive, schema stays 1); `load_club_colours() -> dict[int, list[str]]` in `touchline/ingest/club_map.py`; `league_snapshot(..., colours: dict[int, list[str]] | None = None)` reading `teams.fd_id`.

- [ ] **Step 1: Failing tests**

Append to `pipeline/tests/test_season.py`:
```python
def test_snapshot_attaches_club_colours():
    today = pd.Timestamp("2026-10-04", tz="UTC")
    hist = pd.DataFrame({"date": pd.to_datetime(["2026-05-01"] * 2), "club_id": [11, 31],
                         "rating": [1700.0, 1650.0]})
    clubs, _ = league_snapshot("GB1", _teams(), _matches(today), {11: 1700.0, 31: 1650.0}, hist,
                               EloParams(), MODEL, today, n_sims=50,
                               colours={57: ["#DB0007", "#FFFFFF"]})
    by = {c["id"]: c for c in clubs}
    assert by[11]["colors"] == ["#DB0007", "#FFFFFF"]
    assert by[31]["colors"] is None


def test_colour_table_is_well_formed():
    import re

    from touchline.ingest.club_map import load_club_colours
    table = load_club_colours()
    assert len(table) >= 96
    assert all(len(v) == 2 and all(re.fullmatch(r"#[0-9A-F]{6}", c) for c in v)
               for v in table.values())
```

Append to `pipeline/tests/test_trending.py`:
```python
def test_small_value_rises_get_one_decimal_and_tiny_ones_none():
    df = pd.DataFrame({
        "player_id": [1, 2], "minutes": [2500, 2500], "ga90": [0.2, 0.2],
        "last5_ga": [0, 0], "last5_minutes": [450, 450],
        "value_now": [1.4e6, 330e3], "value_6m_ago": [1.0e6, 300e3],
        "forecast_ga5": [0.5, 0.5]})
    t = trending(df).set_index("player_id")
    assert "Value up €0.4M" in t.loc[1, "reasons"]
    assert t.loc[2, "reasons"] == []  # +€30k is not news
```

- [ ] **Step 2: Run, expect FAIL** — `cd pipeline && .venv/Scripts/python -m pytest tests/test_season.py tests/test_trending.py -q` (unexpected kwarg `colours`; missing `load_club_colours`; label mismatch).

- [ ] **Step 3: Implement**

`pipeline/touchline/ingest/club_colours.json` (football-data team id → traditional scarf colours, hand-checked; approximations of club colours, not official brand assets):
```json
{
  "57": ["#DB0007", "#FFFFFF"], "58": ["#670E36", "#95BFE5"], "61": ["#034694", "#FFFFFF"],
  "62": ["#003399", "#FFFFFF"], "63": ["#FFFFFF", "#000000"], "64": ["#C8102E", "#FFFFFF"],
  "65": ["#6CABDD", "#FFFFFF"], "66": ["#DA291C", "#FFFFFF"], "67": ["#241F20", "#FFFFFF"],
  "71": ["#EB172B", "#FFFFFF"], "73": ["#132257", "#FFFFFF"], "322": ["#F5A12D", "#000000"],
  "341": ["#FFFFFF", "#1D428A"], "349": ["#3A64A3", "#FFFFFF"], "351": ["#DD0000", "#FFFFFF"],
  "354": ["#1B458F", "#C4122E"], "397": ["#0057B8", "#FFFFFF"], "402": ["#E30613", "#FFFFFF"],
  "1044": ["#DA291C", "#000000"], "1076": ["#6CB4E4", "#FFFFFF"],
  "77": ["#EE2523", "#FFFFFF"], "78": ["#CB3524", "#FFFFFF"], "79": ["#D91A21", "#0A346F"],
  "80": ["#007FC8", "#FFFFFF"], "81": ["#A50044", "#004D98"], "82": ["#005999", "#FFFFFF"],
  "84": ["#00609C", "#FFFFFF"], "86": ["#FFFFFF", "#FEBE10"], "87": ["#FFFFFF", "#E53027"],
  "88": ["#B4053F", "#005DA8"], "90": ["#00954C", "#FFFFFF"], "92": ["#0067B1", "#FFFFFF"],
  "94": ["#FFE667", "#005187"], "95": ["#FFFFFF", "#EE3524"], "263": ["#0761AF", "#FFFFFF"],
  "285": ["#FFFFFF", "#05642C"], "558": ["#8AC3EE", "#FFFFFF"], "559": ["#D71920", "#FFFFFF"],
  "560": ["#0050A0", "#FFFFFF"], "5335": ["#FFFFFF", "#00703C"],
  "1": ["#ED1C24", "#FFFFFF"], "2": ["#1961B5", "#FFFFFF"], "3": ["#E32221", "#000000"],
  "4": ["#FDE100", "#000000"], "5": ["#DC052D", "#FFFFFF"], "6": ["#004D9D", "#FFFFFF"],
  "7": ["#0A3F86", "#FFFFFF"], "10": ["#FFFFFF", "#E32219"], "12": ["#1D9053", "#FFFFFF"],
  "15": ["#C3141E", "#FFFFFF"], "16": ["#BA3733", "#46714D"], "17": ["#E2001A", "#000000"],
  "18": ["#000000", "#00915E"], "19": ["#E1000F", "#000000"], "28": ["#EB1923", "#FFFFFF"],
  "29": ["#005CA9", "#000000"], "719": ["#000000", "#FFFFFF"], "721": ["#DD0741", "#FFFFFF"],
  "98": ["#FB090B", "#000000"], "99": ["#482E92", "#FFFFFF"], "100": ["#8E1F2F", "#F0BC42"],
  "102": ["#1E71B8", "#000000"], "103": ["#1A2F48", "#A21C26"], "104": ["#A71930", "#002350"],
  "107": ["#AD1919", "#002147"], "108": ["#010E80", "#000000"], "109": ["#000000", "#FFFFFF"],
  "110": ["#87D8F7", "#FFFFFF"], "112": ["#FFD200", "#1B4F9C"], "113": ["#12A0D7", "#FFFFFF"],
  "115": ["#000000", "#FFFFFF"], "454": ["#000000", "#F26522"], "470": ["#FFDD00", "#0055A4"],
  "471": ["#00A752", "#000000"], "586": ["#8A1E03", "#FFFFFF"], "5890": ["#FFE500", "#E30613"],
  "5911": ["#E30613", "#FFFFFF"], "7397": ["#003DA5", "#FFFFFF"],
  "511": ["#5A2D82", "#FFFFFF"], "512": ["#E30613", "#FFFFFF"], "516": ["#2FAEE0", "#FFFFFF"],
  "519": ["#FFFFFF", "#0A5CA8"], "521": ["#E01E13", "#20325F"], "522": ["#C8102E", "#000000"],
  "523": ["#DA001A", "#004494"], "524": ["#004170", "#DA291C"], "525": ["#F58113", "#000000"],
  "529": ["#E13327", "#000000"], "531": ["#005BAC", "#FFFFFF"], "532": ["#000000", "#FFFFFF"],
  "533": ["#6AB1E7", "#0B2341"], "535": ["#E30613", "#FFD100"], "546": ["#EC1C24", "#FFD200"],
  "548": ["#E7212B", "#FFFFFF"], "576": ["#009FE3", "#FFFFFF"], "1045": ["#18223D", "#FFFFFF"]
}
```

Add to `pipeline/touchline/ingest/club_map.py`:
```python
_COLOURS = Path(__file__).with_name("club_colours.json")


def load_club_colours() -> dict[int, list[str]]:
    return {int(k): v for k, v in json.loads(_COLOURS.read_text()).items()}
```

In `pipeline/touchline/season.py`:
- `league_snapshot` signature gains `colours: dict[int, list[str]] | None = None` (after `history_until`).
- before the club loop: `fd_of = dict(zip(teams.club_id, teams.fd_id, strict=True)); colours = colours or {}`
- in each club record add `"colors": colours.get(int(fd_of[c]))`.
- `build_current_season` passes `colours=load_club_colours()` (import from `touchline.ingest.club_map`).
- `offline_clubs` records get `"colors": None`.

In `pipeline/touchline/models/trending.py`, replace the value branch of `_reasons`:
```python
    if (pd.notna(r.value_change_pct) and r.value_change_pct >= 0.10
            and r.value_change >= 250_000):
        m = r.value_change / 1e6
        out.append(f"Value up €{m:.0f}M" if m >= 10 else f"Value up €{m:.1f}M")
```

In `docs/bundle-schema.md`, add to the club example after `"league": "GB1",`:
`"colors": ["#DB0007", "#FFFFFF"],   // traditional scarf colours (primary, secondary); null when unknown`

- [ ] **Step 4: Run, expect PASS** — `.venv/Scripts/python -m pytest -q -p no:cacheprovider` (all) and `.venv/Scripts/python -m ruff check touchline tests`.

- [ ] **Step 5: Regenerate the bundle** — `.venv/Scripts/python -m touchline.run --skip-download`; exit 0; check `colors` present on all 96 clubs:
```bash
.venv/Scripts/python -c "import gzip,json;b=json.load(gzip.open('data/out/touchline-bundle.json.gz'));print(sum(c['colors'] is not None for c in b['clubs']),len(b['clubs']))"
```
Expected: `96 96`.

- [ ] **Step 6: Commit** — `git add pipeline docs/bundle-schema.md && git commit -m "feat(pipeline): club scarf colours; readable value-rise labels"`

---

### Task 2: Flutter scaffold, assets, fixtures

**Files:**
- Create: `app/` via `flutter create --empty`; `app/assets/fonts/Jersey10-Regular.ttf`, `app/assets/fonts/OFL.txt`, `app/assets/data/touchline-bundle.json.gz`, `app/test/fixtures/bundle.json.gz`, `app/test/fixtures/budget_cases.json`
- Modify: `app/pubspec.yaml`, `app/analysis_options.yaml`
- Test: `app/test/fixture_files_test.dart`

**Interfaces:**
- Produces: package `touchline`; asset `assets/data/touchline-bundle.json.gz`; font family `Jersey`; frozen fixtures `test/fixtures/bundle.json.gz` and `test/fixtures/budget_cases.json` (both from the Task 1 run).

- [ ] **Step 1: Create the project**

```bash
cd /c/Users/91750/touchline && git checkout -b feat/app
/c/flutter/bin/flutter create --org com.aryan --project-name touchline --platforms android,web --empty app
cd app && /c/flutter/bin/flutter pub add http archive path_provider shared_preferences
mkdir -p assets/fonts assets/data test/fixtures
curl -sSfL -o assets/fonts/Jersey10-Regular.ttf https://raw.githubusercontent.com/google/fonts/main/ofl/jersey10/Jersey10-Regular.ttf
curl -sSfL -o assets/fonts/OFL.txt https://raw.githubusercontent.com/google/fonts/main/ofl/jersey10/OFL.txt
```

- [ ] **Step 2: Failing test** — `app/test/fixture_files_test.dart`:
```dart
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('seed and fixture bundles are schema-1 gzip JSON with club colours', () {
    for (final path in ['assets/data/touchline-bundle.json.gz', 'test/fixtures/bundle.json.gz']) {
      final raw = GZipDecoder().decodeBytes(File(path).readAsBytesSync());
      final j = jsonDecode(utf8.decode(raw)) as Map<String, dynamic>;
      expect(j['schema_version'], 1, reason: path);
      expect((j['clubs'] as List).every((c) => (c as Map)['colors'] != null), isTrue,
          reason: path);
    }
  });

  test('budget golden cases exist', () {
    final cases = jsonDecode(File('test/fixtures/budget_cases.json').readAsStringSync()) as List;
    expect(cases, hasLength(3));
  });
}
```
Run `/c/flutter/bin/flutter test test/fixture_files_test.dart` → FAIL (files missing).

- [ ] **Step 3: Copy data, configure pubspec**

```bash
cp ../pipeline/data/out/touchline-bundle.json.gz assets/data/
cp ../pipeline/data/out/touchline-bundle.json.gz test/fixtures/bundle.json.gz
cp ../pipeline/data/out/budget_cases.json test/fixtures/
```
In `app/pubspec.yaml` set `description: "Touchline: football, read in seconds."` and replace the `flutter:` section with:
```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/data/
  fonts:
    - family: Jersey
      fonts:
        - asset: assets/fonts/Jersey10-Regular.ttf
```
`app/analysis_options.yaml`:
```yaml
include: package:flutter_lints/flutter.yaml

linter:
  rules:
    prefer_const_constructors: true
    prefer_final_locals: true
    avoid_print: true
```

- [ ] **Step 4: Run, expect PASS**; `/c/flutter/bin/flutter analyze` → no issues.

- [ ] **Step 5: Commit** — `git add app && git commit -m "feat(app): flutter scaffold, Jersey font, seed bundle and fixtures"`

---

### Task 3: Bundle models

**Files:**
- Create: `app/lib/data/bundle.dart`
- Test: `app/test/bundle_test.dart`

**Interfaces:**
- Produces: `supportedSchemaVersion`, `UnsupportedBundleError`, `parseHexColor(String?) -> int?`; `League{id, fd, name}`, `ClubTable{pos, played, points, gd, gf, ga}`, `Projection{expPoints, expPos, pTitle, pTop4, pReleg}`, `ClubColors{primary, secondary}` (ARGB ints), `Club{id, name, crest, league, elo, eloChange30d, form, table, proj, colors}`, `Fixture{id, league, kickoff, home, away, status, score, p, xg, finished}`, `ValueWhy{label, effectPct}`, `SeasonStats{apps, minutes, goals, assists, ga90}`, `RecentGame{date, opp, ga, minutes}`, `Workload{index, band, acwr, seasonMinutes, congestedApps, flag, asOf}`, `ValuePoint{date, value}`, `Transfer{date, from, to, fee}`, `Player{id, name, img, club, clubName, league, pos, subPos, age, nat, foot, height, marketValue, fairValue, valueGapPct, valueWhy, season, last5, forecastGa5, workload, valueHistory, transfers, similar, trendScore, trendReasons, qualified}`, `Bundle{schemaVersion, generatedAt, playersThrough, clubsThrough, playerSeason, leagues, clubs, fixtures, players, models, clubById, playerById, leagueById}` with `Bundle.fromJson`.

- [ ] **Step 1: Failing tests** — `app/test/bundle_test.dart`:
```dart
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchline/data/bundle.dart';

Map<String, dynamic> minimalBundleJson() => {
      'schema_version': 1,
      'generated_at': '2026-10-04T06:00:00Z',
      'data_through': {'players': '2026-06-28', 'clubs': '2026-10-03'},
      'player_season': '2025/26',
      'leagues': [
        {'id': 'GB1', 'fd': 'PL', 'name': 'Premier League'}
      ],
      'clubs': [
        {
          'id': 11, 'name': 'Arsenal', 'crest': null, 'league': 'GB1', 'elo': 1912.4,
          'elo_change_30d': 14.2, 'form': ['W', 'D'], 'colors': ['#DB0007', '#FFFFFF'],
          'table': {'pos': 1, 'played': 7, 'points': 19, 'gd': 12, 'gf': 15, 'ga': 3},
          'proj': null,
        }
      ],
      'fixtures': [
        {
          'id': 5, 'league': 'GB1', 'kickoff': '2026-10-10T14:00:00Z', 'home': 11,
          'away': -1076, 'status': 'TIMED', 'score': null, 'p': [0.7, 0.2, 0.1],
          'xg': [1.9, 0.8],
        }
      ],
      'players': [
        {
          'id': 7, 'name': 'Young Sub', 'img': null, 'club': 11, 'club_name': 'Arsenal FC',
          'league': 'GB1', 'pos': 'Attack', 'sub_pos': null, 'age': null, 'nat': null,
          'foot': null, 'height': null, 'market_value': 500000, 'fair_value': null,
          'value_gap_pct': null, 'value_why': null,
          'season': {'apps': 3, 'minutes': 120, 'goals': 0, 'assists': 0, 'ga90': 0.0},
          'form': {'last5': [], 'forecast_ga5': null}, 'workload': null,
          'value_history': [], 'transfers': [], 'similar': [],
          'trend': {'score': null, 'reasons': []},
        }
      ],
      'models': {'club_elo': {'favourite_accuracy': 0.689}},
    };

void main() {
  test('parses a minimal bundle and keeps nulls as nulls', () {
    final b = Bundle.fromJson(minimalBundleJson());
    final p = b.playerById[7]!;
    expect(p.fairValue, isNull);
    expect(p.forecastGa5, isNull);
    expect(p.workload, isNull);
    expect(p.trendScore, isNull);
    expect(p.qualified, isFalse);
    expect(b.clubById[11]!.colors!.primary, 0xFFDB0007);
    expect(b.clubById[11]!.proj, isNull);
    expect(b.fixtures.single.finished, isFalse);
    expect(b.fixtures.single.kickoff.isUtc, isTrue);
  });

  test('rejects other schema versions', () {
    final j = minimalBundleJson()..['schema_version'] = 2;
    expect(() => Bundle.fromJson(j), throwsA(isA<UnsupportedBundleError>()));
  });

  test('parseHexColor', () {
    expect(parseHexColor('#0F3D2E'), 0xFF0F3D2E);
    expect(parseHexColor('nope'), isNull);
    expect(parseHexColor(null), isNull);
  });

  test('parses the real frozen bundle', () {
    final raw = GZipDecoder().decodeBytes(File('test/fixtures/bundle.json.gz').readAsBytesSync());
    final b = Bundle.fromJson(jsonDecode(utf8.decode(raw)) as Map<String, dynamic>);
    expect(b.clubs.length, 96);
    expect(b.players.length, greaterThan(2000));
    expect(b.players.where((p) => !p.qualified).every((p) => p.fairValue == null), isTrue);
    expect(b.leagues.map((l) => l.id), containsAll(['GB1', 'ES1', 'L1', 'IT1', 'FR1']));
  });
}
```

- [ ] **Step 2: Run, expect FAIL** — `/c/flutter/bin/flutter test test/bundle_test.dart` (library missing).

- [ ] **Step 3: Implement** `app/lib/data/bundle.dart`. Parsing rules: every number read as `num` then converted (`_d`, `_i`) so `3` and `3.0` both parse; absent lists become empty; `null` stays `null`. Full source:

```dart
/// Typed view of the Touchline bundle (docs/bundle-schema.md, schema v1).
library;

const supportedSchemaVersion = 1;

class UnsupportedBundleError implements Exception {
  UnsupportedBundleError(this.version);
  final Object? version;
  @override
  String toString() => 'Unsupported bundle schema: $version';
}

double? _d(Object? v) => v == null ? null : (v as num).toDouble();
int? _i(Object? v) => v == null ? null : (v as num).toInt();
String? _s(Object? v) => v as String?;
Map<String, dynamic> _m(Object? v) => (v as Map).cast<String, dynamic>();
List<Map<String, dynamic>> _maps(Object? v) => [for (final e in (v as List? ?? const [])) _m(e)];
List<double> _ds(Object? v) => [for (final e in (v as List? ?? const [])) (e as num).toDouble()];

int? parseHexColor(String? hex) {
  if (hex == null || !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(hex)) return null;
  return 0xFF000000 | int.parse(hex.substring(1), radix: 16);
}

class League {
  const League({required this.id, required this.fd, required this.name});
  factory League.fromJson(Map<String, dynamic> j) =>
      League(id: j['id'] as String, fd: j['fd'] as String, name: j['name'] as String);
  final String id;
  final String fd;
  final String name;
}

class ClubTable {
  const ClubTable({required this.pos, required this.played, required this.points,
      required this.gd, required this.gf, required this.ga});
  factory ClubTable.fromJson(Map<String, dynamic> j) => ClubTable(
      pos: _i(j['pos'])!, played: _i(j['played'])!, points: _i(j['points'])!,
      gd: _i(j['gd'])!, gf: _i(j['gf'])!, ga: _i(j['ga'])!);
  final int pos, played, points, gd, gf, ga;
}

class Projection {
  const Projection({required this.expPoints, required this.expPos, required this.pTitle,
      required this.pTop4, required this.pReleg});
  factory Projection.fromJson(Map<String, dynamic> j) => Projection(
      expPoints: _d(j['exp_points'])!, expPos: _d(j['exp_pos'])!,
      pTitle: _d(j['p_title'])!, pTop4: _d(j['p_top4'])!, pReleg: _d(j['p_releg'])!);
  final double expPoints, expPos, pTitle, pTop4, pReleg;
}

class ClubColors {
  const ClubColors(this.primary, this.secondary);
  final int primary;
  final int secondary;
}

class Club {
  const Club({required this.id, required this.name, required this.crest, required this.league,
      required this.elo, required this.eloChange30d, required this.form, required this.table,
      required this.proj, required this.colors});
  factory Club.fromJson(Map<String, dynamic> j) {
    final cols = j['colors'] as List?;
    final a = cols != null && cols.length == 2 ? parseHexColor(cols[0] as String?) : null;
    final b = cols != null && cols.length == 2 ? parseHexColor(cols[1] as String?) : null;
    return Club(
      id: _i(j['id'])!,
      name: j['name'] as String,
      crest: _s(j['crest']),
      league: j['league'] as String,
      elo: _d(j['elo'])!,
      eloChange30d: _d(j['elo_change_30d']) ?? 0,
      form: [for (final f in (j['form'] as List? ?? const [])) f as String],
      table: ClubTable.fromJson(_m(j['table'])),
      proj: j['proj'] == null ? null : Projection.fromJson(_m(j['proj'])),
      colors: a != null && b != null ? ClubColors(a, b) : null,
    );
  }
  final int id;
  final String name;
  final String? crest;
  final String league;
  final double elo;
  final double eloChange30d;
  final List<String> form;
  final ClubTable table;
  final Projection? proj;
  final ClubColors? colors;
}

class Fixture {
  const Fixture({required this.id, required this.league, required this.kickoff,
      required this.home, required this.away, required this.status, required this.score,
      required this.p, required this.xg});
  factory Fixture.fromJson(Map<String, dynamic> j) => Fixture(
        id: _i(j['id'])!,
        league: j['league'] as String,
        kickoff: DateTime.parse(j['kickoff'] as String),
        home: _i(j['home'])!,
        away: _i(j['away'])!,
        status: j['status'] as String,
        score: (j['score'] as List?)?.map((e) => (e as num).toInt()).toList(),
        p: _ds(j['p']),
        xg: _ds(j['xg']),
      );
  final int id;
  final String league;
  final DateTime kickoff;
  final int home;
  final int away;
  final String status;
  final List<int>? score;

  /// Pre-match probabilities: home, draw, away.
  final List<double> p;
  final List<double> xg;
  bool get finished => status == 'FINISHED' || status == 'AWARDED';
}

class ValueWhy {
  const ValueWhy(this.label, this.effectPct);
  final String label;
  final double effectPct;
}

class SeasonStats {
  const SeasonStats({required this.apps, required this.minutes, required this.goals,
      required this.assists, required this.ga90});
  final int apps, minutes, goals, assists;
  final double ga90;
}

class RecentGame {
  const RecentGame({required this.date, required this.opp, required this.ga,
      required this.minutes});
  final DateTime date;
  final String? opp;
  final int ga;
  final int minutes;
}

class Workload {
  const Workload({required this.index, required this.band, required this.acwr,
      required this.seasonMinutes, required this.congestedApps, required this.flag,
      required this.asOf});
  final int index;
  final String band;
  final double acwr;
  final int seasonMinutes;
  final int congestedApps;
  final bool flag;
  final DateTime asOf;
}

class ValuePoint {
  const ValuePoint(this.date, this.value);
  final DateTime date;
  final int value;
}

class Transfer {
  const Transfer({required this.date, required this.from, required this.to, required this.fee});
  final DateTime date;
  final String? from;
  final String? to;
  final int? fee;
}

class Player {
  const Player({required this.id, required this.name, required this.img, required this.club,
      required this.clubName, required this.league, required this.pos, required this.subPos,
      required this.age, required this.nat, required this.foot, required this.height,
      required this.marketValue, required this.fairValue, required this.valueGapPct,
      required this.valueWhy, required this.season, required this.last5,
      required this.forecastGa5, required this.workload, required this.valueHistory,
      required this.transfers, required this.similar, required this.trendScore,
      required this.trendReasons});

  factory Player.fromJson(Map<String, dynamic> j) {
    final s = _m(j['season']);
    final f = _m(j['form']);
    final w = j['workload'] == null ? null : _m(j['workload']);
    final t = _m(j['trend']);
    return Player(
      id: _i(j['id'])!,
      name: j['name'] as String,
      img: _s(j['img']),
      club: _i(j['club']),
      clubName: _s(j['club_name']),
      league: j['league'] as String,
      pos: _s(j['pos']),
      subPos: _s(j['sub_pos']),
      age: _d(j['age']),
      nat: _s(j['nat']),
      foot: _s(j['foot']),
      height: _d(j['height']),
      marketValue: _i(j['market_value']),
      fairValue: _i(j['fair_value']),
      valueGapPct: _d(j['value_gap_pct']),
      valueWhy: j['value_why'] == null
          ? null
          : [
              for (final e in _maps(j['value_why']))
                ValueWhy(e['f'] as String, _d(e['effect_pct'])!)
            ],
      season: SeasonStats(apps: _i(s['apps'])!, minutes: _i(s['minutes'])!,
          goals: _i(s['goals'])!, assists: _i(s['assists'])!, ga90: _d(s['ga90'])!),
      last5: [
        for (final g in _maps(f['last5']))
          RecentGame(date: DateTime.parse(g['date'] as String), opp: _s(g['opp']),
              ga: _i(g['ga'])!, minutes: _i(g['min'])!)
      ],
      forecastGa5: _d(f['forecast_ga5']),
      workload: w == null
          ? null
          : Workload(index: _i(w['index'])!, band: w['band'] as String,
              acwr: _d(w['acwr'])!, seasonMinutes: _i(w['season_minutes'])!,
              congestedApps: _i(w['congested_apps'])!, flag: w['flag'] as bool,
              asOf: DateTime.parse(w['as_of'] as String)),
      valueHistory: [
        for (final e in (j['value_history'] as List? ?? const []))
          ValuePoint(DateTime.parse((e as List)[0] as String), (e[1] as num).toInt())
      ],
      transfers: [
        for (final e in _maps(j['transfers']))
          Transfer(date: DateTime.parse(e['date'] as String), from: _s(e['from']),
              to: _s(e['to']), fee: _i(e['fee']))
      ],
      similar: [for (final e in (j['similar'] as List? ?? const [])) (e as num).toInt()],
      trendScore: _d(t['score']),
      trendReasons: [for (final e in (t['reasons'] as List? ?? const [])) e as String],
    );
  }

  final int id;
  final String name;
  final String? img;
  final int? club;
  final String? clubName;
  final String league;
  final String? pos;
  final String? subPos;
  final double? age;
  final String? nat;
  final String? foot;
  final double? height;
  final int? marketValue;
  final int? fairValue;
  final double? valueGapPct;
  final List<ValueWhy>? valueWhy;
  final SeasonStats season;
  final List<RecentGame> last5;
  final double? forecastGa5;
  final Workload? workload;
  final List<ValuePoint> valueHistory;
  final List<Transfer> transfers;
  final List<int> similar;
  final double? trendScore;
  final List<String> trendReasons;

  /// Model outputs are only shown for players with 900+ minutes in the season.
  bool get qualified => season.minutes >= 900;
}

class Bundle {
  Bundle({required this.schemaVersion, required this.generatedAt, required this.playersThrough,
      required this.clubsThrough, required this.playerSeason, required this.leagues,
      required this.clubs, required this.fixtures, required this.players, required this.models});

  factory Bundle.fromJson(Map<String, dynamic> j) {
    final v = j['schema_version'];
    if (v != supportedSchemaVersion) throw UnsupportedBundleError(v);
    final dt = _m(j['data_through']);
    return Bundle(
      schemaVersion: v as int,
      generatedAt: DateTime.parse(j['generated_at'] as String),
      playersThrough: dt['players'] as String,
      clubsThrough: dt['clubs'] as String,
      playerSeason: j['player_season'] as String,
      leagues: [for (final e in _maps(j['leagues'])) League.fromJson(e)],
      clubs: [for (final e in _maps(j['clubs'])) Club.fromJson(e)],
      fixtures: [for (final e in _maps(j['fixtures'])) Fixture.fromJson(e)],
      players: [for (final e in _maps(j['players'])) Player.fromJson(e)],
      models: _m(j['models']),
    );
  }

  final int schemaVersion;
  final DateTime generatedAt;
  final String playersThrough;
  final String clubsThrough;
  final String playerSeason;
  final List<League> leagues;
  final List<Club> clubs;
  final List<Fixture> fixtures;
  final List<Player> players;
  final Map<String, dynamic> models;

  late final Map<int, Club> clubById = {for (final c in clubs) c.id: c};
  late final Map<int, Player> playerById = {for (final p in players) p.id: p};
  late final Map<String, League> leagueById = {for (final l in leagues) l.id: l};
}
```

- [ ] **Step 4: Run, expect PASS** — `/c/flutter/bin/flutter test test/bundle_test.dart && /c/flutter/bin/flutter analyze`.

- [ ] **Step 5: Commit** — `git add app && git commit -m "feat(app): typed bundle models"`

---

### Task 4: Bundle loader (local first, network refresh)

**Files:**
- Create: `app/lib/data/bundle_loader.dart`, `app/lib/data/seed.dart`, `app/lib/data/platform_io.dart`, `app/lib/data/platform_io_native.dart`, `app/lib/data/platform_io_web.dart`, `app/test/helpers.dart`
- Modify: `app/test/bundle_test.dart` (import `minimalBundleJson` from helpers instead of defining it)
- Test: `app/test/bundle_loader_test.dart`

**Interfaces:**
- Consumes: `Bundle.fromJson`, `UnsupportedBundleError` (Task 3)
- Produces: `enum BundleOrigin {network, cache, seed}`; `typedef BundleDecoder = Future<Bundle> Function(List<int>)`; `Bundle decodeBundleGz(List<int>)`; `Future<Bundle> decodeInline(List<int>)`; `class BundleIo{readSeed, readCache?, writeCache?, fetchRemote?}`; `class LocalLoad{bundle, origin}`; `class FetchResult{reachable, bundle?}`; `Future<LocalLoad> loadLocal(BundleIo, {BundleDecoder decode})`; `Future<FetchResult> fetchNewer(BundleIo, Bundle current, {BundleDecoder decode})`; `BundleIo platformBundleIo()`; test helpers `minimalBundleJson()`, `List<int> gz(Map<String, dynamic>)`, `Bundle fixtureBundle()`.

- [ ] **Step 1: Helpers** — create `app/test/helpers.dart`, move `minimalBundleJson()` there from `bundle_test.dart` (which now does `import 'helpers.dart';`), and add:
```dart
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:touchline/data/bundle.dart';

List<int> gz(Map<String, dynamic> json) => GZipEncoder().encode(utf8.encode(jsonEncode(json)));

Bundle? _fixture;

/// The frozen real bundle (test/fixtures/bundle.json.gz), parsed once per test run.
Bundle fixtureBundle() => _fixture ??= Bundle.fromJson(jsonDecode(utf8.decode(
    GZipDecoder().decodeBytes(File('test/fixtures/bundle.json.gz').readAsBytesSync())))
    as Map<String, dynamic>);
```
(`minimalBundleJson` body exactly as written in Task 3's test.)

- [ ] **Step 2: Failing tests** — `app/test/bundle_loader_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:touchline/data/bundle.dart';
import 'package:touchline/data/bundle_loader.dart';

import 'helpers.dart';

Map<String, dynamic> _at(String generatedAt, {int schema = 1}) =>
    minimalBundleJson()
      ..['generated_at'] = generatedAt
      ..['schema_version'] = schema;

void main() {
  final seed = gz(_at('2026-10-01T00:00:00Z'));
  final cache = gz(_at('2026-10-03T00:00:00Z'));

  test('valid cache wins over seed', () async {
    final r = await loadLocal(BundleIo(readSeed: () async => seed, readCache: () async => cache));
    expect(r.origin, BundleOrigin.cache);
    expect(r.bundle.generatedAt, DateTime.utc(2026, 10, 3));
  });

  test('corrupt or unsupported cache falls back to seed', () async {
    for (final bad in [
      [1, 2, 3],
      gz(_at('2026-10-09T00:00:00Z', schema: 2)),
    ]) {
      final r = await loadLocal(BundleIo(readSeed: () async => seed, readCache: () async => bad));
      expect(r.origin, BundleOrigin.seed);
    }
  });

  test('missing cache falls back to seed', () async {
    final r = await loadLocal(BundleIo(readSeed: () async => seed, readCache: () async => null));
    expect(r.origin, BundleOrigin.seed);
  });

  group('fetchNewer', () {
    final current = Bundle.fromJson(_at('2026-10-03T00:00:00Z'));

    test('newer bundle is returned and cached', () async {
      List<int>? written;
      final r = await fetchNewer(
          BundleIo(readSeed: () async => seed,
              fetchRemote: () async => gz(_at('2026-10-10T00:00:00Z')),
              writeCache: (b) async => written = b),
          current);
      expect(r.reachable, isTrue);
      expect(r.bundle!.generatedAt, DateTime.utc(2026, 10, 10));
      expect(written, isNotNull);
    });

    test('same or older bundle: reachable, nothing to swap', () async {
      final r = await fetchNewer(
          BundleIo(readSeed: () async => seed, fetchRemote: () async => cache), current);
      expect(r.reachable, isTrue);
      expect(r.bundle, isNull);
    });

    test('unsupported schema from network is ignored and not cached', () async {
      var wrote = false;
      final r = await fetchNewer(
          BundleIo(readSeed: () async => seed,
              fetchRemote: () async => gz(_at('2026-10-10T00:00:00Z', schema: 2)),
              writeCache: (_) async => wrote = true),
          current);
      expect(r.bundle, isNull);
      expect(wrote, isFalse);
    });

    test('network failure or no remote configured: unreachable', () async {
      final failing = await fetchNewer(
          BundleIo(readSeed: () async => seed, fetchRemote: () async => throw Exception('x')),
          current);
      expect(failing.reachable, isFalse);
      final none = await fetchNewer(BundleIo(readSeed: () async => seed), current);
      expect(none.reachable, isFalse);
    });
  });
}
```

- [ ] **Step 3: Run, expect FAIL** — `/c/flutter/bin/flutter test test/bundle_loader_test.dart`.

- [ ] **Step 4: Implement**

`app/lib/data/bundle_loader.dart`:
```dart
import 'dart:convert';

import 'package:archive/archive.dart';

import 'bundle.dart';

enum BundleOrigin { network, cache, seed }

typedef BundleDecoder = Future<Bundle> Function(List<int> bytes);

Bundle decodeBundleGz(List<int> bytes) => Bundle.fromJson(
    jsonDecode(utf8.decode(GZipDecoder().decodeBytes(bytes))) as Map<String, dynamic>);

Future<Bundle> decodeInline(List<int> bytes) async => decodeBundleGz(bytes);

class BundleIo {
  const BundleIo({required this.readSeed, this.readCache, this.writeCache, this.fetchRemote});
  final Future<List<int>> Function() readSeed;
  final Future<List<int>?> Function()? readCache;
  final Future<void> Function(List<int> bytes)? writeCache;
  final Future<List<int>?> Function()? fetchRemote;
}

class LocalLoad {
  const LocalLoad(this.bundle, this.origin);
  final Bundle bundle;
  final BundleOrigin origin;
}

class FetchResult {
  const FetchResult({required this.reachable, this.bundle});
  final bool reachable;
  final Bundle? bundle;
}

/// Cached bundle if it is valid, otherwise the seed shipped inside the app.
Future<LocalLoad> loadLocal(BundleIo io, {BundleDecoder decode = decodeInline}) async {
  try {
    final cached = await io.readCache?.call();
    if (cached != null) return LocalLoad(await decode(cached), BundleOrigin.cache);
  } catch (_) {
    // Corrupt or unsupported cache: fall through to the seed.
  }
  return LocalLoad(await decode(await io.readSeed()), BundleOrigin.seed);
}

/// Fetch the published bundle; hand it back only when it is valid and newer.
Future<FetchResult> fetchNewer(BundleIo io, Bundle current,
    {BundleDecoder decode = decodeInline}) async {
  final fetch = io.fetchRemote;
  if (fetch == null) return const FetchResult(reachable: false);
  final List<int>? bytes;
  try {
    bytes = await fetch();
  } catch (_) {
    return const FetchResult(reachable: false);
  }
  if (bytes == null) return const FetchResult(reachable: false);
  final Bundle fresh;
  try {
    fresh = await decode(bytes);
  } catch (_) {
    return const FetchResult(reachable: true);
  }
  if (!fresh.generatedAt.isAfter(current.generatedAt)) {
    return const FetchResult(reachable: true);
  }
  try {
    await io.writeCache?.call(bytes);
  } catch (_) {
    // A failed cache write must not lose the fresh data for this session.
  }
  return FetchResult(reachable: true, bundle: fresh);
}
```

`app/lib/data/seed.dart`:
```dart
import 'package:flutter/services.dart';

const seedAsset = 'assets/data/touchline-bundle.json.gz';

Future<List<int>> readSeedAsset() async =>
    (await rootBundle.load(seedAsset)).buffer.asUint8List();
```

`app/lib/data/platform_io.dart`:
```dart
export 'platform_io_web.dart' if (dart.library.io) 'platform_io_native.dart';
```

`app/lib/data/platform_io_native.dart`:
```dart
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'bundle_loader.dart';
import 'seed.dart';

/// Set at build time: --dart-define=BUNDLE_URL=https://github.com/<owner>/<repo>/releases/download/data-latest/touchline-bundle.json.gz
const bundleUrl = String.fromEnvironment('BUNDLE_URL');

BundleIo platformBundleIo() {
  Future<File> cacheFile() async =>
      File('${(await getApplicationSupportDirectory()).path}/touchline-bundle.json.gz');
  return BundleIo(
    readSeed: readSeedAsset,
    readCache: () async {
      final f = await cacheFile();
      return await f.exists() ? f.readAsBytes() : null;
    },
    writeCache: (bytes) async => (await cacheFile()).writeAsBytes(bytes, flush: true),
    fetchRemote: bundleUrl.isEmpty
        ? null
        : () async {
            final r = await http.get(Uri.parse(bundleUrl)).timeout(const Duration(seconds: 20));
            return r.statusCode == 200 ? r.bodyBytes : null;
          },
  );
}
```

`app/lib/data/platform_io_web.dart`:
```dart
import 'package:http/http.dart' as http;

import 'bundle_loader.dart';
import 'seed.dart';

/// The web demo is deployed with the latest bundle beside it (same origin, no CORS).
BundleIo platformBundleIo() => BundleIo(
      readSeed: readSeedAsset,
      fetchRemote: () async {
        final r = await http
            .get(Uri.base.resolve('data/touchline-bundle.json.gz'))
            .timeout(const Duration(seconds: 20));
        return r.statusCode == 200 ? r.bodyBytes : null;
      },
    );
```

- [ ] **Step 5: Run, expect PASS** — `/c/flutter/bin/flutter test && /c/flutter/bin/flutter analyze`.

- [ ] **Step 6: Commit** — `git add app && git commit -m "feat(app): offline-first bundle loader with background refresh"`

---

### Task 5: Selectors

**Files:**
- Create: `app/lib/data/selectors.dart`
- Test: `app/test/selectors_test.dart`

**Interfaces:**
- Consumes: Task 3 models
- Produces: `bool inLeague(String league, String? filter)`; `String fold(String)` (lowercase, accents removed); `List<Fixture> weekFixtures(Bundle, String? league, DateTime now)`; `Fixture? featuredFixture(Bundle, String? league, DateTime now)`; `List<Fixture> recentResults(Bundle, String? league)`; `List<Player> trendingPlayers(Bundle, String? league, {int n = 12})`; `List<Club> clubsInForm(Bundle, String? league, {int n = 5})`; `List<Club> powerRankings(Bundle, String? league, {int n = 10})`; `const bargainFloor = 5000000`; `List<Player> bargains(Bundle, String? league, {int n = 10})`; `List<Player> overworked(Bundle, String? league, {int n = 10})`; `List<Club> leagueTable(Bundle, String league)`; `List<Player> squad(Bundle, int clubId)`; `List<Fixture> clubFixtures(Bundle, int clubId)`; `List<Player> similarCheaper(Bundle, Player)`; `enum PlayerSort {trending, valueGap, forecast, marketValue, name}`; `class PlayerQuery{text, league, pos, maxAge, maxPrice, sort}`; `List<Player> searchPlayers(Bundle, PlayerQuery)`.

- [ ] **Step 1: Failing tests** — `app/test/selectors_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:touchline/data/bundle.dart';
import 'package:touchline/data/selectors.dart';

import 'helpers.dart';

Map<String, dynamic> _club(int id, String league, double elo, {double change = 0, int pos = 1}) => {
      'id': id, 'name': 'C$id', 'crest': null, 'league': league, 'elo': elo,
      'elo_change_30d': change, 'form': ['W'], 'colors': null, 'proj': null,
      'table': {'pos': pos, 'played': 5, 'points': 10, 'gd': 1, 'gf': 5, 'ga': 4},
    };

Map<String, dynamic> _fix(int id, int h, int a, DateTime k,
        {String league = 'GB1', String status = 'TIMED'}) => {
      'id': id, 'league': league, 'kickoff': k.toIso8601String(), 'home': h, 'away': a,
      'status': status, 'score': status == 'FINISHED' ? [1, 0] : null,
      'p': [0.5, 0.3, 0.2], 'xg': [1.4, 1.0],
    };

Map<String, dynamic> _player(int id, String name,
    {String league = 'GB1', int minutes = 2000, double? trend, int? fair, int? market,
    Map<String, dynamic>? workload, String pos = 'Attack', double age = 24,
    List<int> similar = const []}) => {
      'id': id, 'name': name, 'img': null, 'club': 1, 'club_name': 'C1', 'league': league,
      'pos': pos, 'sub_pos': null, 'age': age, 'nat': null, 'foot': null, 'height': null,
      'market_value': market, 'fair_value': fair,
      'value_gap_pct': fair != null && market != null ? (fair - market) / market : null,
      'value_why': null,
      'season': {'apps': 30, 'minutes': minutes, 'goals': 5, 'assists': 3, 'ga90': 0.4},
      'form': {'last5': [], 'forecast_ga5': trend == null ? null : 2.0}, 'workload': workload,
      'value_history': [], 'transfers': [], 'similar': similar,
      'trend': {'score': trend, 'reasons': trend == null ? [] : ['Hot']},
    };

Map<String, dynamic> _wl(int index, bool flag) => {
      'index': index, 'band': 'High', 'acwr': 1.1, 'season_minutes': 4000,
      'congested_apps': 9, 'flag': flag, 'as_of': '2026-05-24'};

final now = DateTime.utc(2026, 10, 5, 12);

Bundle _bundle() => Bundle.fromJson(minimalBundleJson()
  ..['clubs'] = [
    _club(1, 'GB1', 1900, change: 20, pos: 2),
    _club(2, 'GB1', 1700, change: -5, pos: 1),
    _club(3, 'GB1', 1600, change: 8, pos: 3),
    _club(4, 'ES1', 1950, change: 3, pos: 1),
  ]
  ..['fixtures'] = [
    _fix(10, 2, 3, now.add(const Duration(days: 1))),
    _fix(11, 1, 2, now.add(const Duration(days: 2))),
    _fix(12, 1, 3, now.add(const Duration(days: 9))),
    _fix(13, 3, 1, now.subtract(const Duration(days: 2)), status: 'FINISHED'),
    _fix(14, 4, 4, now.add(const Duration(days: 3)), league: 'ES1'),
  ]
  ..['players'] = [
    _player(1, 'Kylian Mbappé', trend: 2.0, fair: 30000000, market: 20000000,
        workload: _wl(70, false), similar: [2, 3]),
    _player(2, 'Cheap Lookalike', trend: 1.0, fair: 9000000, market: 6000000,
        workload: _wl(90, false)),
    _player(3, 'Pricey Lookalike', trend: null, fair: 4000000, market: 50000000,
        workload: _wl(40, true), pos: 'Defender', age: 31),
    _player(4, 'Tiny Club Hero', trend: 0.5, fair: 3000000, market: 1000000, league: 'ES1'),
    _player(5, 'Bench Kid', minutes: 200),
  ]);

void main() {
  final b = _bundle();

  test('week fixtures: upcoming within 7 days, sorted, league-filtered', () {
    expect(weekFixtures(b, null, now).map((f) => f.id), [10, 11, 14]);
    expect(weekFixtures(b, 'GB1', now).map((f) => f.id), [10, 11]);
  });

  test('featured fixture is the biggest match by combined Elo', () {
    expect(featuredFixture(b, 'GB1', now)!.id, 11);
    expect(featuredFixture(b, 'IT1', now), isNull);
  });

  test('recent results are finished games, newest first', () {
    expect(recentResults(b, null).map((f) => f.id), [13]);
  });

  test('trending excludes null scores and respects league', () {
    expect(trendingPlayers(b, null).map((p) => p.id), [1, 2, 4]);
    expect(trendingPlayers(b, 'GB1').map((p) => p.id), [1, 2]);
  });

  test('bargains: positive gap, market >= floor, sorted by euro gap', () {
    expect(bargains(b, null).map((p) => p.id), [1, 2]);
  });

  test('overworked: flagged first, then index', () {
    expect(overworked(b, null).map((p) => p.id), [3, 2, 1]);
  });

  test('clubs in form, power rankings, table', () {
    expect(clubsInForm(b, 'GB1').map((c) => c.id), [1, 3, 2]);
    expect(powerRankings(b, null).map((c) => c.id), [4, 1, 2, 3]);
    expect(leagueTable(b, 'GB1').map((c) => c.id), [2, 1, 3]);
  });

  test('similar cheaper keeps only lower market value', () {
    expect(similarCheaper(b, b.playerById[1]!).map((p) => p.id), [2]);
  });

  test('search folds accents and case; filters and sorts', () {
    expect(searchPlayers(b, const PlayerQuery(text: 'mbappe')).map((p) => p.id), [1]);
    expect(searchPlayers(b, const PlayerQuery(pos: 'Defender')).map((p) => p.id), [3]);
    expect(searchPlayers(b, const PlayerQuery(maxAge: 30, maxPrice: 10000000,
            sort: PlayerSort.marketValue)).map((p) => p.id), [2, 4]);
    // Euro gap, not percentage: cheap players with huge % gaps must not flood the list.
    expect(searchPlayers(b, const PlayerQuery(sort: PlayerSort.valueGap)).first.id, 1);
  });

  test('fold', () {
    expect(fold('Vinícius Júnior'), 'vinicius junior');
    expect(fold('Øde­gaard'), contains('odegaard'));
  });
}
```

- [ ] **Step 2: Run, expect FAIL.**

- [ ] **Step 3: Implement** `app/lib/data/selectors.dart`:
```dart
import 'bundle.dart';

bool inLeague(String league, String? filter) => filter == null || league == filter;

const _accents = {
  'á': 'a', 'à': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a', 'ą': 'a', 'æ': 'ae',
  'ç': 'c', 'ć': 'c', 'č': 'c', 'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', 'ę': 'e', 'ě': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i', 'ı': 'i', 'ñ': 'n', 'ń': 'n', 'ň': 'n',
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o', 'ø': 'o', 'ő': 'o', 'œ': 'oe',
  'ś': 's', 'š': 's', 'ş': 's', 'ß': 'ss', 'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', 'ű': 'u',
  'ů': 'u', 'ý': 'y', 'ÿ': 'y', 'ž': 'z', 'ź': 'z', 'ż': 'z', 'ł': 'l', 'đ': 'd', 'ğ': 'g',
  'ř': 'r', 'ť': 't',
};

/// Lowercase, accents removed, invisible characters dropped: "Mbappé" matches "mbappe".
String fold(String s) {
  final b = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    if (ch == '­' || ch == '​') continue;
    b.write(_accents[ch] ?? ch);
  }
  return b.toString();
}

List<T> _top<T>(Iterable<T> xs, double Function(T) key, int n) {
  final l = xs.toList()..sort((a, c) => key(c).compareTo(key(a)));
  return l.take(n).toList();
}

List<Fixture> weekFixtures(Bundle b, String? league, DateTime now) => b.fixtures
    .where((f) =>
        !f.finished &&
        inLeague(f.league, league) &&
        f.kickoff.isAfter(now.subtract(const Duration(hours: 2))) &&
        f.kickoff.isBefore(now.add(const Duration(days: 7))))
    .toList()
  ..sort((a, c) => a.kickoff.compareTo(c.kickoff));

Fixture? featuredFixture(Bundle b, String? league, DateTime now) {
  final week = weekFixtures(b, league, now);
  if (week.isEmpty) return null;
  double weight(Fixture f) =>
      (b.clubById[f.home]?.elo ?? 1500) + (b.clubById[f.away]?.elo ?? 1500);
  return week.reduce((a, c) => weight(c) > weight(a) ? c : a);
}

List<Fixture> recentResults(Bundle b, String? league) =>
    b.fixtures.where((f) => f.finished && inLeague(f.league, league)).toList()
      ..sort((a, c) => c.kickoff.compareTo(a.kickoff));

List<Player> trendingPlayers(Bundle b, String? league, {int n = 12}) => _top(
    b.players.where((p) => p.trendScore != null && inLeague(p.league, league)),
    (p) => p.trendScore!, n);

List<Club> clubsInForm(Bundle b, String? league, {int n = 5}) => _top(
    b.clubs.where((c) => c.table.played > 0 && inLeague(c.league, league)),
    (c) => c.eloChange30d, n);

List<Club> powerRankings(Bundle b, String? league, {int n = 10}) =>
    _top(b.clubs.where((c) => inLeague(c.league, league)), (c) => c.elo, n);

const bargainFloor = 5000000;

List<Player> bargains(Bundle b, String? league, {int n = 10}) => _top(
    b.players.where((p) =>
        p.fairValue != null &&
        p.marketValue != null &&
        p.marketValue! >= bargainFloor &&
        p.fairValue! > p.marketValue! &&
        inLeague(p.league, league)),
    (p) => (p.fairValue! - p.marketValue!).toDouble(), n);

List<Player> overworked(Bundle b, String? league, {int n = 10}) => _top(
    b.players.where((p) => p.workload != null && inLeague(p.league, league)),
    (p) => (p.workload!.flag ? 1000 : 0) + p.workload!.index.toDouble(), n);

List<Club> leagueTable(Bundle b, String league) =>
    b.clubs.where((c) => c.league == league).toList()
      ..sort((a, c) => a.table.pos.compareTo(c.table.pos));

List<Player> squad(Bundle b, int clubId) => b.players.where((p) => p.club == clubId).toList()
  ..sort((a, c) => (c.marketValue ?? -1).compareTo(a.marketValue ?? -1));

List<Fixture> clubFixtures(Bundle b, int clubId) =>
    b.fixtures.where((f) => f.home == clubId || f.away == clubId).toList()
      ..sort((a, c) => a.kickoff.compareTo(c.kickoff));

List<Player> similarCheaper(Bundle b, Player p) => [
      for (final id in p.similar)
        if (b.playerById[id] case final s?)
          if ((s.marketValue ?? 0) < (p.marketValue ?? 0)) s
    ];

enum PlayerSort { trending, valueGap, forecast, marketValue, name }

class PlayerQuery {
  const PlayerQuery({this.text = '', this.league, this.pos, this.maxAge, this.maxPrice,
      this.sort = PlayerSort.trending});
  final String text;
  final String? league;
  final String? pos;
  final double? maxAge;
  final int? maxPrice;
  final PlayerSort sort;
}

List<Player> searchPlayers(Bundle b, PlayerQuery q) {
  final needle = fold(q.text.trim());
  final out = b.players.where((p) =>
      (needle.isEmpty || fold(p.name).contains(needle)) &&
      inLeague(p.league, q.league) &&
      (q.pos == null || p.pos == q.pos) &&
      (q.maxAge == null || (p.age != null && p.age! <= q.maxAge!)) &&
      (q.maxPrice == null || (p.marketValue != null && p.marketValue! <= q.maxPrice!)));
  const low = -1e18;
  final double Function(Player) key = switch (q.sort) {
    PlayerSort.trending => (p) => p.trendScore ?? low,
    PlayerSort.valueGap => (p) => p.fairValue != null && p.marketValue != null
        ? (p.fairValue! - p.marketValue!).toDouble()
        : low,
    PlayerSort.forecast => (p) => p.forecastGa5 ?? low,
    PlayerSort.marketValue => (p) => (p.marketValue ?? low).toDouble(),
    PlayerSort.name => (p) => 0,
  };
  final list = out.toList();
  if (q.sort == PlayerSort.name) {
    list.sort((a, c) => fold(a.name).compareTo(fold(c.name)));
  } else {
    list.sort((a, c) => key(c).compareTo(key(a)));
  }
  return list;
}
```

- [ ] **Step 4: Run, expect PASS** — `/c/flutter/bin/flutter test test/selectors_test.dart && /c/flutter/bin/flutter analyze`.

- [ ] **Step 5: Commit** — `git add app && git commit -m "feat(app): screen selectors with league filters and accent-folding search"`

---

### Task 6: Budget planner (exact, on-device)

**Files:**
- Create: `app/lib/data/planner.dart`
- Test: `app/test/planner_test.dart`

**Interfaces:**
- Consumes: Task 3 models
- Produces: `class PlanItem{id, pos, price, score}` (price and score in € millions); `class Plan{ids, cost, score}`; `Plan? planSignings(List<PlanItem> items, double budget, Map<String, int> needs)` (null = infeasible; `Plan([],0,0)` when needs are all zero); `List<PlanItem> planCandidates(Bundle, {String? league, double? maxAge})` (players with fairValue and marketValue > 0, excluding nothing else; same pool as the pipeline's golden cases).

Method: per position, a 0/1 knapsack over Pareto fronts (cost ascending, score strictly increasing) for each exact pick count; positions are then combined front-by-front. Dominated states are dropped, so the result is exactly optimal. Before that, any item beaten on both price and score by at least `need` other items of its position is pruned (it can never be in an optimal set).

- [ ] **Step 1: Failing tests** — `app/test/planner_test.dart`:
```dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:touchline/data/planner.dart';

import 'helpers.dart';

const toy = [
  PlanItem(1, 'Attack', 60, 80),
  PlanItem(2, 'Attack', 30, 45),
  PlanItem(3, 'Midfield', 40, 50),
  PlanItem(4, 'Midfield', 25, 40),
  PlanItem(5, 'Defender', 20, 30),
];

void main() {
  test('finds the optimum, not the greedy pick', () {
    final p = planSignings(toy, 100, {'Attack': 1, 'Midfield': 1})!;
    expect(p.ids.toSet(), {1, 3}); // 60 + 40 = 100, score 130 beats {1, 4} = 120
    expect(p.score, 130);
    expect(p.cost, 100);
  });

  test('infeasible budget returns null; zero needs returns an empty plan', () {
    expect(planSignings(toy, 10, {'Attack': 1}), isNull);
    expect(planSignings(toy, 100, {'Attack': 3}), isNull);
    final empty = planSignings(toy, 100, {'Attack': 0})!;
    expect(empty.ids, isEmpty);
  });

  test('matches the pipeline ILP on the real golden cases', () {
    final cases = jsonDecode(File('test/fixtures/budget_cases.json').readAsStringSync()) as List;
    final items = planCandidates(fixtureBundle());
    for (final c in cases.cast<Map<String, dynamic>>()) {
      final needs = (c['needs'] as Map).map((k, v) => MapEntry(k as String, v as int));
      final plan = planSignings(items, (c['budget_m'] as num).toDouble(), needs)!;
      expect(plan.score, closeTo((c['ilp_score'] as num).toDouble(), 1e-6),
          reason: 'budget ${c['budget_m']}');
      expect(plan.cost, lessThanOrEqualTo((c['budget_m'] as num).toDouble() + 1e-9));
    }
  });
}
```

- [ ] **Step 2: Run, expect FAIL.**

- [ ] **Step 3: Implement** `app/lib/data/planner.dart`:
```dart
import 'bundle.dart';

class PlanItem {
  const PlanItem(this.id, this.pos, this.price, this.score);
  final int id;
  final String pos;

  /// € millions.
  final double price;

  /// Fair value in € millions: the quality the planner maximises.
  final double score;
}

class Plan {
  const Plan(this.ids, this.cost, this.score);
  final List<int> ids;
  final double cost;
  final double score;
}

class _State {
  const _State(this.cost, this.score, this.ids);
  final double cost;
  final double score;
  final List<int> ids;
}

const _eps = 1e-9;

List<_State> _pareto(List<_State> states) {
  states.sort((a, b) => a.cost != b.cost ? a.cost.compareTo(b.cost) : b.score.compareTo(a.score));
  final out = <_State>[];
  var best = double.negativeInfinity;
  for (final s in states) {
    if (s.score > best + _eps) {
      out.add(s);
      best = s.score;
    }
  }
  return out;
}

List<PlanItem> _prune(List<PlanItem> items, int need) => [
      for (final it in items)
        if (items.where((o) =>
                    !identical(o, it) &&
                    o.price <= it.price &&
                    o.score >= it.score &&
                    (o.price < it.price || o.score > it.score))
                .length <
            need)
          it
    ];

Plan? planSignings(List<PlanItem> items, double budget, Map<String, int> needs) {
  var acc = [const _State(0, 0, <int>[])];
  for (final MapEntry(key: pos, value: need) in needs.entries) {
    if (need <= 0) continue;
    final cands = _prune(
        [for (final it in items) if (it.pos == pos && it.price <= budget + _eps) it], need);
    final fronts = List.generate(need + 1, (_) => <_State>[]);
    fronts[0] = [const _State(0, 0, <int>[])];
    for (final it in cands) {
      for (var c = need; c >= 1; c--) {
        if (fronts[c - 1].isEmpty) continue;
        final added = [
          for (final s in fronts[c - 1])
            if (s.cost + it.price <= budget + _eps)
              _State(s.cost + it.price, s.score + it.score, [...s.ids, it.id])
        ];
        if (added.isNotEmpty) fronts[c] = _pareto([...fronts[c], ...added]);
      }
    }
    if (fronts[need].isEmpty) return null;
    acc = _pareto([
      for (final a in acc)
        for (final s in fronts[need])
          if (a.cost + s.cost <= budget + _eps)
            _State(a.cost + s.cost, a.score + s.score, [...a.ids, ...s.ids])
    ]);
    if (acc.isEmpty) return null;
  }
  final best = acc.reduce((a, b) => b.score > a.score ? b : a);
  return Plan(best.ids, best.cost, best.score);
}

List<PlanItem> planCandidates(Bundle b, {String? league, double? maxAge}) => [
      for (final p in b.players)
        if (p.fairValue != null &&
            (p.marketValue ?? 0) > 0 &&
            p.pos != null &&
            (league == null || p.league == league) &&
            (maxAge == null || (p.age != null && p.age! <= maxAge)))
          PlanItem(p.id, p.pos!, p.marketValue! / 1e6, p.fairValue! / 1e6)
    ];
```

- [ ] **Step 4: Run, expect PASS** — `/c/flutter/bin/flutter test test/planner_test.dart`. The golden test must finish in under ~10 s; if it doesn't, profile the front sizes before changing the algorithm (pruning is the lever).

- [ ] **Step 5: Commit** — `git add app && git commit -m "feat(app): exact on-device budget planner matching pipeline ILP"`

---

### Task 7: Formatting and pundit voice

**Files:**
- Create: `app/lib/format.dart`, `app/lib/copy/voice.dart`
- Test: `app/test/format_test.dart`, `app/test/voice_test.dart`

**Interfaces:**
- Produces: `String money(int? eur)` ("€2.4M", "€45M", "€750K", "–"); `String signedMoney(int eur)` ("+€12M", "−€3.5M"); `String pct(double p)` ("71%"); `String shortDate(DateTime)` ("24 May"); `String kickoffLabel(DateTime utc, DateTime now)` ("Today 15:00", "Tomorrow 20:45", "Sat 15:00", "12 Oct"); `String fixtureVerdict(String home, String away, List<double> p)`; `String playerVerdict(Player)`; `String formVerdict(List<String> form)`; `String workloadVerdict(String band)`; `String clubVerdict(Club)`.

- [ ] **Step 1: Failing tests**

`app/test/format_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:touchline/format.dart';

void main() {
  test('money', () {
    expect(money(null), '–');
    expect(money(750000), '€750K');
    expect(money(2400000), '€2.4M');
    expect(money(45000000), '€45M');
    expect(money(180000000), '€180M');
    expect(signedMoney(12000000), '+€12M');
    expect(signedMoney(-3500000), '−€3.5M');
  });

  test('pct and dates', () {
    expect(pct(0.706), '71%');
    expect(shortDate(DateTime(2026, 5, 24)), '24 May');
    final now = DateTime(2026, 10, 5, 9); // Monday
    expect(kickoffLabel(DateTime(2026, 10, 5, 15), now), 'Today 15:00');
    expect(kickoffLabel(DateTime(2026, 10, 6, 20, 45), now), 'Tomorrow 20:45');
    expect(kickoffLabel(DateTime(2026, 10, 10, 15), now), 'Sat 15:00');
    expect(kickoffLabel(DateTime(2026, 10, 20, 15), now), '20 Oct');
  });
}
```
(`kickoffLabel` converts with `.toLocal()`; the test passes local `DateTime`s, for which `toLocal()` is a no-op.)

`app/test/voice_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:touchline/copy/voice.dart';
import 'package:touchline/data/bundle.dart';

import 'helpers.dart';

void main() {
  test('fixture verdicts scale with confidence', () {
    expect(fixtureVerdict('Arsenal', 'Leeds', [0.71, 0.18, 0.11]),
        'Arsenal should handle this. Leeds need a miracle.');
    expect(fixtureVerdict('A', 'B', [0.55, 0.25, 0.20]), 'A are favourites, not certainties.');
    expect(fixtureVerdict('A', 'B', [0.36, 0.30, 0.34]), 'Too close to call. Expect nerves.');
    expect(fixtureVerdict('A', 'B', [0.20, 0.25, 0.55]), 'B are favourites, not certainties.');
  });

  test('form and workload', () {
    expect(formVerdict(['W', 'W', 'W', 'W', 'W']), 'Five from five. Somebody stop them.');
    expect(formVerdict(['L', 'L', 'L', 'D', 'L']), 'Grim viewing.');
    expect(formVerdict([]), 'No games yet.');
    expect(workloadVerdict('Heavy'), 'Legs are being asked a lot.');
    expect(workloadVerdict('Light'), 'Fresh legs.');
  });

  test('player verdict never judges an unqualified player', () {
    final p = Bundle.fromJson(minimalBundleJson()).playerById[7]!;
    expect(playerVerdict(p), 'Not enough minutes yet to judge.');
  });

  test('real players get a verdict line', () {
    for (final p in fixtureBundle().players.where((p) => p.qualified).take(200)) {
      expect(playerVerdict(p), isNotEmpty);
    }
  });
}
```

- [ ] **Step 2: Run, expect FAIL.**

- [ ] **Step 3: Implement**

`app/lib/format.dart`:
```dart
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov',
    'Dec'];
const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String money(int? eur) {
  if (eur == null) return '–';
  final m = eur / 1e6;
  if (m >= 10) return '€${m.round()}M';
  if (m >= 1) return '€${m.toStringAsFixed(1)}M';
  return '€${(eur / 1e3).round()}K';
}

String signedMoney(int eur) => '${eur >= 0 ? '+' : '−'}${money(eur.abs())}';

String pct(double p) => '${(p * 100).round()}%';

String shortDate(DateTime d) => '${d.day} ${_months[d.month - 1]}';

String _hm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String kickoffLabel(DateTime utc, DateTime now) {
  final k = utc.toLocal();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(k.year, k.month, k.day);
  final diff = day.difference(today).inDays;
  if (diff == 0) return 'Today ${_hm(k)}';
  if (diff == 1) return 'Tomorrow ${_hm(k)}';
  if (diff > 1 && diff < 7) return '${_days[k.weekday - 1]} ${_hm(k)}';
  return shortDate(k);
}
```

`app/lib/copy/voice.dart`:
```dart
import '../data/bundle.dart';
import '../format.dart';

String fixtureVerdict(String home, String away, List<double> p) {
  final homeFav = p[0] >= p[2];
  final fav = homeFav ? home : away;
  final dog = homeFav ? away : home;
  final top = homeFav ? p[0] : p[2];
  final low = homeFav ? p[2] : p[0];
  if (top >= 0.65 && low <= 0.12) return '$fav should handle this. $dog need a miracle.';
  if (top >= 0.65) return '$fav should handle this.';
  if (top >= 0.5) return '$fav are favourites, not certainties.';
  if ((p[0] - p[2]).abs() < 0.08) return 'Too close to call. Expect nerves.';
  return '$fav shade it, but a draw is live.';
}

String formVerdict(List<String> form) {
  if (form.isEmpty) return 'No games yet.';
  final w = form.where((r) => r == 'W').length;
  final l = form.where((r) => r == 'L').length;
  if (w == 5) return 'Five from five. Somebody stop them.';
  if (w >= 4) return 'Flying.';
  if (l >= 4) return 'Grim viewing.';
  if (l >= 3) return 'Wobbling.';
  return 'Mixed bag.';
}

String workloadVerdict(String band) => switch (band) {
      'Heavy' => 'Legs are being asked a lot.',
      'High' => 'Busy schedule.',
      'Normal' => 'Load looks normal.',
      _ => 'Fresh legs.',
    };

String playerVerdict(Player p) {
  if (!p.qualified) return 'Not enough minutes yet to judge.';
  final gap = p.valueGapPct;
  final mv = p.marketValue ?? 0;
  if (gap != null && gap >= 0.5 && mv >= 2000000) {
    return 'Priced like a backup, plays like a starter.';
  }
  if (gap != null && gap <= -0.35) return 'Paying for the name more than the numbers.';
  if (p.trendReasons.isNotEmpty) {
    final r = p.trendReasons.first;
    return 'Running hot: ${r[0].toLowerCase()}${r.substring(1)}.';
  }
  final f = p.forecastGa5;
  if (f != null && f >= 2.5) {
    return 'Due a big week: about ${f.toStringAsFixed(1)} goal involvements in the next five.';
  }
  return 'Steady. Does the job, rarely the headline.';
}

String clubVerdict(Club c) {
  final p = c.proj;
  if (p == null) return formVerdict(c.form);
  if (p.pTitle >= 0.4) return 'In the title race: ${pct(p.pTitle)} to win it.';
  if (p.pTop4 >= 0.5) return 'Top four looks likely.';
  if (p.pReleg >= 0.5) return 'In real trouble at the bottom.';
  if (p.pReleg >= 0.2) return 'Looking over their shoulder.';
  return 'Mid-table and comfortable.';
}
```

- [ ] **Step 4: Run, expect PASS** — `/c/flutter/bin/flutter test && /c/flutter/bin/flutter analyze`.

- [ ] **Step 5: Commit** — `git add app && git commit -m "feat(app): formatting helpers and pundit voice"`

---

### Task 8: Theme, preferences, app state

Read `C:\Users\91750\.claude\skills\impeccable\reference\craft-floor.md` before starting. Rules that bind this app: no eyebrow or kicker above a heading; no hero-metric template (the hero % lives on the scarf); no same-size icon-card grids as page structure; real icons only (Material Icons); themed text selection, caret, scrollbars and tabular numerals; contrast ≥ 4.5:1 for body text.

**Files:**
- Create: `app/lib/theme/tokens.dart`, `app/lib/theme/theme.dart`, `app/lib/data/prefs.dart`, `app/lib/state/app_state.dart`
- Modify: `app/test/helpers.dart` (add `fixtureNow`, `pumpApp`)
- Test: `app/test/theme_test.dart`, `app/test/app_state_test.dart`

**Interfaces:**
- Consumes: Task 4 loader
- Produces: `TL` colour tokens (`pitch, pink, concrete, nightGround, ink, win, draw, loss, neutralA, neutralB`), `Color onColor(Color)`; `const stitchUnit = 18.6667`; `ThemeData buildTheme(Brightness)`; `TextStyle tabular(TextStyle)`; `abstract class Prefs{read, write}`, `MemoryPrefs`, `DevicePrefs`; `AppState` (fields `bundle, origin, reachable, refreshing, loadError, league, themeMode, favourites`; methods `start(), refresh(), setLeague(String?), isFavourite(int), toggleFavourite(int), setThemeMode(ThemeMode)`, getter `now`); `AppState.preloaded(Bundle, {Prefs? prefs, DateTime Function()? clock})`; `AppScope.of(context)`, `AppScope.read(context)`; test helpers `fixtureNow` (2026-10-05 12:00 UTC) and `pumpApp(tester, child, {state, brightness})`.

- [ ] **Step 1: Failing tests**

`app/test/theme_test.dart`:
```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchline/theme/theme.dart';
import 'package:touchline/theme/tokens.dart';

double contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  for (final b in Brightness.values) {
    test('$b: stitch roles use Jersey at whole-stitch sizes', () {
      final t = buildTheme(b).textTheme;
      expect(t.displayLarge!.fontFamily, 'Jersey');
      expect(t.displayLarge!.fontSize, closeTo(56, 0.01));
      expect(t.displaySmall!.fontSize, closeTo(37.33, 0.01));
      expect(t.headlineSmall!.fontSize, closeTo(18.67, 0.01));
      expect(t.bodyMedium!.fontFamily, isNot('Jersey'));
    });

    test('$b: text contrast on the ground and on containers', () {
      final s = buildTheme(b).colorScheme;
      expect(contrast(s.onSurface, s.surface), greaterThanOrEqualTo(7));
      expect(contrast(s.onSurfaceVariant, s.surface), greaterThanOrEqualTo(4.5));
      expect(contrast(s.onSurfaceVariant, s.surfaceContainerLow), greaterThanOrEqualTo(4.5));
      expect(contrast(s.onPrimary, s.primary), greaterThanOrEqualTo(4.5));
      expect(contrast(s.onTertiaryContainer, s.tertiaryContainer), greaterThanOrEqualTo(4.5));
    });
  }

  test('onColor picks a readable ink for any club colour', () {
    for (final c in [Colors.white, const Color(0xFFFDE100), TL.pitch, const Color(0xFF6CABDD),
        const Color(0xFFDB0007), Colors.black]) {
      expect(contrast(onColor(c), c), greaterThanOrEqualTo(3), reason: '$c');
    }
  });
}
```

`app/test/app_state_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchline/data/bundle_loader.dart';
import 'package:touchline/data/prefs.dart';
import 'package:touchline/state/app_state.dart';

import 'helpers.dart';

void main() {
  test('start shows local data first, then swaps in a newer network bundle', () async {
    final seed = gz(minimalBundleJson()..['generated_at'] = '2026-10-01T00:00:00Z');
    final remote = gz(minimalBundleJson()..['generated_at'] = '2026-10-08T00:00:00Z');
    final origins = <BundleOrigin?>[];
    final s = AppState(
      io: BundleIo(readSeed: () async => seed, fetchRemote: () async => remote),
      prefs: MemoryPrefs(),
      decode: decodeInline,
    )..addListener(() => origins.add(null));
    await s.start();
    expect(s.origin, BundleOrigin.network);
    expect(s.reachable, isTrue);
    expect(s.bundle!.generatedAt, DateTime.utc(2026, 10, 8));
  });

  test('offline start keeps the seed and reports unreachable', () async {
    final seed = gz(minimalBundleJson());
    final s = AppState(io: BundleIo(readSeed: () async => seed), prefs: MemoryPrefs(),
        decode: decodeInline);
    await s.start();
    expect(s.origin, BundleOrigin.seed);
    expect(s.reachable, isFalse);
    expect(s.bundle, isNotNull);
  });

  test('favourites and theme persist across launches', () async {
    final prefs = MemoryPrefs();
    final seed = gz(minimalBundleJson());
    final a = AppState(io: BundleIo(readSeed: () async => seed), prefs: prefs,
        decode: decodeInline);
    await a.start();
    await a.toggleFavourite(7);
    await a.setThemeMode(ThemeMode.dark);
    final b = AppState(io: BundleIo(readSeed: () async => seed), prefs: prefs,
        decode: decodeInline);
    await b.start();
    expect(b.isFavourite(7), isTrue);
    expect(b.themeMode, ThemeMode.dark);
  });

  test('corrupt favourites pref is ignored', () async {
    final prefs = MemoryPrefs();
    await prefs.write('favourites', '7,abc,,9');
    final s = AppState(io: BundleIo(readSeed: () async => gz(minimalBundleJson())),
        prefs: prefs, decode: decodeInline);
    await s.start();
    expect(s.favourites, {7, 9});
  });

  test('league filter notifies only on change', () {
    final s = AppState.preloaded(fixtureBundle());
    var n = 0;
    s.addListener(() => n++);
    s.setLeague('GB1');
    s.setLeague('GB1');
    expect(n, 1);
  });
}
```

- [ ] **Step 2: Run, expect FAIL.**

- [ ] **Step 3: Implement**

`app/lib/theme/tokens.dart`:
```dart
import 'package:flutter/material.dart';

/// Touchline's scarf: pitch green and paper pink, on terrace concrete.
abstract final class TL {
  static const pitch = Color(0xFF0F3D2E);
  static const pink = Color(0xFFF2A7C3);
  static const concrete = Color(0xFFEDEDE8);
  static const nightGround = Color(0xFF0D1311);
  static const ink = Color(0xFF16181D);
  static const win = Color(0xFF1E7A46);
  static const draw = Color(0xFF7D838C);
  static const loss = Color(0xFFC8102E);

  /// Used when a club has no known colours.
  static const neutralA = Color(0xFF5C6670);
  static const neutralB = Color(0xFFD9DCE0);
}

/// Ink that reads on top of [c] (white on dark colours, near-black on light ones).
Color onColor(Color c) => c.computeLuminance() > 0.36 ? TL.ink : Colors.white;
```

`app/lib/theme/theme.dart`:
```dart
import 'dart:ui';

import 'package:flutter/material.dart';

import 'tokens.dart';

/// Font size at which one Jersey stitch is one logical pixel (cap height = 10 stitches).
const stitchUnit = 18.6667;

TextStyle tabular(TextStyle s) =>
    s.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final seeded = ColorScheme.fromSeed(
      seedColor: TL.pitch, brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity);
  final scheme = seeded.copyWith(
    primary: dark ? const Color(0xFF8FD6AE) : TL.pitch,
    onPrimary: dark ? const Color(0xFF003920) : Colors.white,
    primaryContainer: dark ? const Color(0xFF1C4A39) : const Color(0xFFCDE9D9),
    onPrimaryContainer: dark ? const Color(0xFFCDE9D9) : TL.pitch,
    tertiary: dark ? TL.pink : const Color(0xFF8E3B5E),
    onTertiary: dark ? TL.ink : Colors.white,
    tertiaryContainer: TL.pink,
    onTertiaryContainer: TL.ink,
    surface: dark ? TL.nightGround : TL.concrete,
    onSurface: dark ? const Color(0xFFE6E8E3) : TL.ink,
    onSurfaceVariant: dark ? const Color(0xFFA9B1AC) : const Color(0xFF4A4F57),
    surfaceContainerLowest: dark ? const Color(0xFF0A0F0D) : const Color(0xFFFAFAF7),
    surfaceContainerLow: dark ? const Color(0xFF141B18) : const Color(0xFFF6F6F2),
    surfaceContainer: dark ? const Color(0xFF18201C) : const Color(0xFFE6E6E0),
    surfaceContainerHigh: dark ? const Color(0xFF1F2824) : const Color(0xFFDEDED8),
    surfaceContainerHighest: dark ? const Color(0xFF27312C) : const Color(0xFFD6D6D0),
    outline: dark ? const Color(0xFF8A918C) : const Color(0xFF767C85),
    outlineVariant: dark ? const Color(0xFF2E3833) : const Color(0xFFC9CBC6),
  );
  final base = ThemeData(colorScheme: scheme, useMaterial3: true);
  final tt = base.textTheme;

  TextStyle stitch(double size) => TextStyle(
      fontFamily: 'Jersey', fontSize: size, height: 1.0, letterSpacing: 0,
      color: scheme.onSurface, fontFeatures: const [FontFeature.tabularFigures()]);

  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    textTheme: tt.copyWith(
      displayLarge: stitch(stitchUnit * 3),
      displaySmall: stitch(stitchUnit * 2),
      headlineSmall: stitch(stitchUnit),
      titleLarge: tt.titleLarge!.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.2),
      titleMedium: tt.titleMedium!.copyWith(fontWeight: FontWeight.w600),
      labelLarge: tabular(tt.labelLarge!),
      labelMedium: tabular(tt.labelMedium!),
      bodyMedium: tt.bodyMedium!.copyWith(height: 1.4),
    ),
    appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface, foregroundColor: scheme.onSurface, elevation: 0,
        scrolledUnderElevation: 0, centerTitle: false),
    cardTheme: CardThemeData(
        elevation: 0, color: scheme.surfaceContainerLow, margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
    navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainer, indicatorColor: scheme.tertiaryContainer,
        elevation: 0),
    navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surfaceContainer, indicatorColor: scheme.tertiaryContainer),
    chipTheme: ChipThemeData(
        selectedColor: scheme.primary,
        secondaryLabelStyle: TextStyle(color: scheme.onPrimary, fontWeight: FontWeight.w600),
        side: BorderSide(color: scheme.outlineVariant),
        showCheckmark: false),
    bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow, showDragHandle: true, elevation: 1),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1, thickness: 1),
    textSelectionTheme: TextSelectionThemeData(
        selectionColor: TL.pink.withValues(alpha: 0.55), cursorColor: scheme.primary,
        selectionHandleColor: scheme.primary),
    scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(scheme.outline.withValues(alpha: 0.6)),
        thickness: const WidgetStatePropertyAll(6), radius: const Radius.circular(8)),
  );
}
```

`app/lib/data/prefs.dart`:
```dart
import 'package:shared_preferences/shared_preferences.dart';

abstract class Prefs {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class MemoryPrefs implements Prefs {
  final _values = <String, String>{};
  @override
  Future<String?> read(String key) async => _values[key];
  @override
  Future<void> write(String key, String value) async => _values[key] = value;
}

class DevicePrefs implements Prefs {
  @override
  Future<String?> read(String key) async => (await SharedPreferences.getInstance()).getString(key);
  @override
  Future<void> write(String key, String value) async =>
      (await SharedPreferences.getInstance()).setString(key, value);
}
```

`app/lib/state/app_state.dart`:
```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/bundle.dart';
import '../data/bundle_loader.dart';
import '../data/prefs.dart';

/// Decodes the 5 MB bundle off the UI isolate (inline on the web).
Future<Bundle> decodeInBackground(List<int> bytes) => compute(decodeBundleGz, bytes);

class AppState extends ChangeNotifier {
  AppState({required this.io, required this.prefs, this.decode = decodeInBackground,
      DateTime Function()? clock})
      : clock = clock ?? DateTime.now;

  AppState.preloaded(Bundle b, {Prefs? prefs, DateTime Function()? clock})
      : io = BundleIo(readSeed: () async => const <int>[]),
        prefs = prefs ?? MemoryPrefs(),
        decode = decodeInline,
        clock = clock ?? DateTime.now,
        bundle = b,
        origin = BundleOrigin.seed;

  final BundleIo io;
  final Prefs prefs;
  final BundleDecoder decode;
  final DateTime Function() clock;

  Bundle? bundle;
  BundleOrigin? origin;
  bool reachable = false;
  bool refreshing = false;
  Object? loadError;
  String? league;
  ThemeMode themeMode = ThemeMode.system;
  final Set<int> favourites = {};

  DateTime get now => clock();

  Future<void> start() async {
    await _restorePrefs();
    try {
      final local = await loadLocal(io, decode: decode);
      bundle = local.bundle;
      origin = local.origin;
    } catch (e) {
      loadError = e;
    }
    notifyListeners();
    await refresh();
  }

  Future<void> refresh() async {
    final current = bundle;
    if (current == null || refreshing) return;
    refreshing = true;
    notifyListeners();
    final r = await fetchNewer(io, current, decode: decode);
    reachable = r.reachable;
    if (r.bundle != null) {
      bundle = r.bundle;
      origin = BundleOrigin.network;
    }
    refreshing = false;
    notifyListeners();
  }

  void setLeague(String? id) {
    if (league == id) return;
    league = id;
    notifyListeners();
  }

  bool isFavourite(int id) => favourites.contains(id);

  Future<void> toggleFavourite(int id) async {
    if (!favourites.remove(id)) favourites.add(id);
    notifyListeners();
    await prefs.write('favourites', favourites.join(','));
  }

  Future<void> setThemeMode(ThemeMode m) async {
    themeMode = m;
    notifyListeners();
    await prefs.write('theme', m.name);
  }

  Future<void> _restorePrefs() async {
    final f = await prefs.read('favourites');
    if (f != null) favourites.addAll(f.split(',').map(int.tryParse).whereType<int>());
    final t = await prefs.read('theme');
    themeMode = ThemeMode.values.firstWhere((m) => m.name == t, orElse: () => ThemeMode.system);
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
```

Append to `app/test/helpers.dart` (add imports `package:flutter/material.dart`, `package:flutter_test/flutter_test.dart`, `package:touchline/state/app_state.dart`, `package:touchline/theme/theme.dart`):
```dart
/// "Now" for widget tests: inside the frozen bundle's fixture window.
final fixtureNow = DateTime.utc(2026, 10, 5, 12);

Future<AppState> pumpApp(WidgetTester tester, Widget child,
    {AppState? state, Brightness brightness = Brightness.light}) async {
  final s = state ?? AppState.preloaded(fixtureBundle(), clock: () => fixtureNow);
  await tester.pumpWidget(AppScope(
      state: s,
      child: MaterialApp(theme: buildTheme(brightness), home: child)));
  await tester.pump(const Duration(milliseconds: 800));
  return s;
}
```

- [ ] **Step 4: Run, expect PASS** — `/c/flutter/bin/flutter test && /c/flutter/bin/flutter analyze`. If a contrast assertion fails, adjust the token (never the threshold) and note the change.

- [ ] **Step 5: Commit** — `git add app && git commit -m "feat(app): terrace-scarf theme tokens, prefs and app state"`

---

### Task 9: Scarf and shared widgets

**Files:**
- Create: `app/lib/widgets/scarf.dart`, `app/lib/widgets/crest.dart`, `app/lib/widgets/player_avatar.dart`, `app/lib/widgets/empty_note.dart`, `app/lib/widgets/section.dart`, `app/lib/widgets/stat_bar.dart`, `app/lib/widgets/value_chart.dart`
- Test: `app/test/widgets_test.dart`

**Interfaces:**
- Consumes: tokens/theme (Task 8), models (Task 3), `pct`, `money`, `shortDate` (Task 7)
- Produces:
  - `enum Knit {solid, cross, dropped}`; `class ScarfBand{flex, colors, knit, label}`; `class ScarfPainter extends CustomPainter` (public field `progress`); `class Scarf extends StatefulWidget{bands, semanticLabel, height=48, stripeWidth=12, fringe=false, labelStyles}`; `List<Color> clubColors(Club?)`; `class FixtureScarf{fixture, home, away, height=48, hero=false}`; `class FormScarf{form, cell=22}`; `class ClubScarf{club, height=72}`
  - `class Crest{club, size=32}` (network crest; stitched monogram fallback keyed `ValueKey('monogram')`)
  - `class PlayerAvatar{player, size=56}` (portrait 3:4; initials fallback keyed `ValueKey('initials')`)
  - `class EmptyNote{text}`; `class SectionHeading{title, action?, onAction?}`
  - `class EffectBar{label, effect}` (signed, centred at zero, value text "+35%"); `class ShareBar{label, value}` (0..1 with % text)
  - `class ValueChart{points}` (EmptyNote when fewer than 2 points)

- [ ] **Step 1: Failing tests** — `app/test/widgets_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchline/data/bundle.dart';
import 'package:touchline/widgets/crest.dart';
import 'package:touchline/widgets/empty_note.dart';
import 'package:touchline/widgets/player_avatar.dart';
import 'package:touchline/widgets/scarf.dart';
import 'package:touchline/widgets/value_chart.dart';

import 'helpers.dart';

Club _club(String? crest) => Club.fromJson({
      'id': 1, 'name': 'Borussia Dortmund', 'crest': crest, 'league': 'L1', 'elo': 1800,
      'elo_change_30d': 0, 'form': [], 'colors': ['#FDE100', '#000000'], 'proj': null,
      'table': {'pos': 1, 'played': 0, 'points': 0, 'gd': 0, 'gf': 0, 'ga': 0},
    });

void main() {
  testWidgets('fixture scarf announces the split in words', (tester) async {
    final b = fixtureBundle();
    final f = b.fixtures.firstWhere((f) => !f.finished);
    await pumpApp(tester, Scaffold(body: FixtureScarf(
        fixture: f, home: b.clubById[f.home], away: b.clubById[f.away], hero: true)));
    final home = b.clubById[f.home]!.name;
    expect(find.bySemanticsLabel(RegExp('^$home win \\d+%, draw \\d+%, .+ win \\d+%\$')),
        findsOneWidget);
  });

  testWidgets('scarves skip the knit-in when animations are disabled', (tester) async {
    await pumpApp(tester, const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: Scaffold(body: FormScarf(form: ['W', 'D', 'L']))));
    final paint = tester.widget<CustomPaint>(find.descendant(
        of: find.byType(Scarf), matching: find.byType(CustomPaint)).first);
    expect((paint.painter! as ScarfPainter).progress, 1.0);
    expect(find.bySemanticsLabel('Form: won, drew, lost'), findsOneWidget);
  });

  testWidgets('empty form says so', (tester) async {
    await pumpApp(tester, const Scaffold(body: FormScarf(form: [])));
    expect(find.text('No games yet'), findsOneWidget);
  });

  testWidgets('crest falls back to a stitched monogram (null and failed URL)', (tester) async {
    await pumpApp(tester, Scaffold(body: Column(children: [
      Crest(club: _club(null)),
      Crest(club: _club('https://example.invalid/crest.png')),
    ])));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('monogram')), findsNWidgets(2));
    expect(find.text('BD'), findsNWidgets(2));
  });

  testWidgets('player avatar falls back to initials', (tester) async {
    final p = fixtureBundle().players.first;
    await pumpApp(tester, Scaffold(body: PlayerAvatar(player: p)));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('initials')), findsOneWidget);
  });

  testWidgets('value chart with one point shows an empty note', (tester) async {
    await pumpApp(tester, Scaffold(
        body: ValueChart(points: [ValuePoint(DateTime(2025, 7, 1), 1000000)])));
    expect(find.byType(EmptyNote), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run, expect FAIL.**

- [ ] **Step 3: Implement**

`app/lib/widgets/scarf.dart`:
```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/bundle.dart';
import '../format.dart';
import '../theme/tokens.dart';

enum Knit { solid, cross, dropped }

class ScarfBand {
  const ScarfBand({required this.flex, required this.colors, this.knit = Knit.solid, this.label});

  /// Relative width.
  final double flex;

  /// Stripe colours cycled across the band (a club's pair, or one colour).
  final List<Color> colors;
  final Knit knit;

  /// Knitted onto a solid name panel in the band's first colour, if it fits.
  final String? label;
}

class ScarfPainter extends CustomPainter {
  ScarfPainter({required this.bands, required this.progress, required this.stripeWidth,
      required this.fringe, required this.labelStyles, required this.ground,
      required this.edge});

  final List<ScarfBand> bands;
  final double progress;
  final double stripeWidth;
  final bool fringe;

  /// Tried in order; the first style whose text fits the band is used.
  final List<TextStyle> labelStyles;
  final Color ground;
  final Color edge;

  static const _row = 4.0; // one knitted row
  static const _fringe = 6.0;

  @override
  void paint(Canvas canvas, Size size) {
    final left = fringe ? _fringe : 0.0;
    final body = Rect.fromLTWH(left, 0, size.width - 2 * left, size.height);
    final total = bands.fold<double>(0, (s, b) => s + b.flex);
    if (total <= 0 || body.width <= 0) return;

    // Knit in row by row: reveal whole rows from the top.
    final rows = (body.height / _row).ceil();
    final shown = (rows * progress).ceil() * _row;
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, math.min(shown, size.height)),
        const Radius.circular(3)));

    var x = body.left;
    for (final band in bands) {
      final w = body.width * band.flex / total;
      final r = Rect.fromLTWH(x, body.top, w, body.height);
      _paintBand(canvas, r, band);
      x += w;
    }
    if (fringe) _paintFringe(canvas, size, body);
    canvas.restore();

    canvas.drawRRect(RRect.fromRectAndRadius(body, const Radius.circular(3)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = edge);
  }

  void _paintBand(Canvas canvas, Rect r, ScarfBand band) {
    canvas.save();
    canvas.clipRect(r);
    if (band.knit == Knit.dropped) {
      canvas.drawRect(r, Paint()..color = ground);
      final ladder = Paint()
        ..color = band.colors.first
        ..strokeWidth = 2;
      for (var y = r.top + _row; y < r.bottom; y += _row * 2) {
        canvas.drawLine(Offset(r.left + 3, y), Offset(r.right - 3, y), ladder);
      }
    } else {
      var sx = r.left;
      var i = 0;
      while (sx < r.right) {
        canvas.drawRect(Rect.fromLTWH(sx, r.top, stripeWidth, r.height),
            Paint()..color = band.colors[i % band.colors.length]);
        sx += stripeWidth;
        i++;
      }
      _paintStitches(canvas, r, band.colors.first);
      if (band.knit == Knit.cross) _paintCross(canvas, r, band.colors.first);
    }
    if (band.label != null) _paintLabel(canvas, r, band);
    canvas.restore();
  }

  void _paintStitches(Canvas canvas, Rect r, Color base) {
    final shade = (base.computeLuminance() > 0.5 ? Colors.black : Colors.white)
        .withValues(alpha: 0.10);
    final p = Paint()
      ..color = shade
      ..strokeWidth = 1;
    for (var y = r.top + 1; y < r.bottom; y += _row) {
      for (var x = r.left; x < r.right; x += 6) {
        canvas.drawLine(Offset(x, y), Offset(x + 3, y + 3), p);
        canvas.drawLine(Offset(x + 3, y + 3), Offset(x + 6, y), p);
      }
    }
  }

  void _paintCross(Canvas canvas, Rect r, Color base) {
    final p = Paint()
      ..color = onColor(base).withValues(alpha: 0.35)
      ..strokeWidth = 1.2;
    for (var y = r.top + 6; y < r.bottom - 4; y += 12) {
      for (var x = r.left + 6; x < r.right - 4; x += 12) {
        canvas.drawLine(Offset(x - 3, y - 3), Offset(x + 3, y + 3), p);
        canvas.drawLine(Offset(x - 3, y + 3), Offset(x + 3, y - 3), p);
      }
    }
  }

  void _paintLabel(Canvas canvas, Rect r, ScarfBand band) {
    final panel = band.knit == Knit.dropped ? ground : band.colors.first;
    for (final style in labelStyles) {
      final tp = TextPainter(
          text: TextSpan(text: band.label, style: style.copyWith(color: onColor(panel))),
          textDirection: TextDirection.ltr,
          maxLines: 1)
        ..layout();
      final padW = tp.width + 12;
      if (padW > r.width - 4 || tp.height > r.height) continue;
      final pr = Rect.fromCenter(center: r.center, width: padW, height: r.height);
      if (band.knit != Knit.dropped) canvas.drawRect(pr, Paint()..color = panel);
      tp.paint(canvas, Offset(r.center.dx - tp.width / 2, r.center.dy - tp.height / 2));
      return;
    }
  }

  void _paintFringe(Canvas canvas, Size size, Rect body) {
    final first = bands.first.colors.first;
    final last = bands.last.colors.last;
    for (var y = body.top + 3; y < body.bottom - 2; y += 5) {
      canvas.drawLine(Offset(0, y), Offset(body.left, y + 1),
          Paint()..color = first..strokeWidth = 2);
      canvas.drawLine(Offset(body.right, y), Offset(size.width, y + 1),
          Paint()..color = last..strokeWidth = 2);
    }
  }

  @override
  bool shouldRepaint(ScarfPainter old) =>
      old.progress != progress || old.bands != bands || old.ground != ground;
}

class Scarf extends StatefulWidget {
  const Scarf({super.key, required this.bands, required this.semanticLabel, this.height = 48,
      this.stripeWidth = 12, this.fringe = false, this.labelStyles});

  final List<ScarfBand> bands;
  final String semanticLabel;
  final double height;
  final double stripeWidth;
  final bool fringe;
  final List<TextStyle>? labelStyles;

  @override
  State<Scarf> createState() => _ScarfState();
}

class _ScarfState extends State<Scarf> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Semantics(
      label: widget.semanticLabel,
      container: true,
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(
            size: Size.fromHeight(widget.height),
            painter: ScarfPainter(
              bands: widget.bands,
              progress: Curves.easeOutExpo.transform(_c.value),
              stripeWidth: widget.stripeWidth,
              fringe: widget.fringe,
              labelStyles: widget.labelStyles ?? [tt.headlineSmall!],
              ground: scheme.surface,
              edge: scheme.outlineVariant,
            ),
          ),
        ),
      ),
    );
  }
}

List<Color> clubColors(Club? c) => c?.colors == null
    ? const [TL.neutralA, TL.neutralB]
    : [Color(c!.colors!.primary), Color(c.colors!.secondary)];

/// A half-and-half matchday scarf: home colours, a draw band, away colours, each as wide
/// as its probability.
class FixtureScarf extends StatelessWidget {
  const FixtureScarf({super.key, required this.fixture, required this.home, required this.away,
      this.height = 48, this.hero = false});

  final Fixture fixture;
  final Club? home;
  final Club? away;
  final double height;
  final bool hero;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final p = fixture.p;
    String? label(double v) => v >= 0.12 ? pct(v) : null;
    final hn = home?.name ?? 'Home';
    final an = away?.name ?? 'Away';
    return Scarf(
      height: hero ? 72 : height,
      fringe: hero,
      stripeWidth: hero ? 14 : 10,
      labelStyles: hero
          ? [tt.displayLarge!, tt.displaySmall!, tt.headlineSmall!]
          : [tt.headlineSmall!],
      semanticLabel: '$hn win ${pct(p[0])}, draw ${pct(p[1])}, $an win ${pct(p[2])}',
      bands: [
        ScarfBand(flex: p[0], colors: clubColors(home), label: label(p[0])),
        ScarfBand(flex: p[1], colors: const [TL.draw], knit: Knit.cross, label: label(p[1])),
        ScarfBand(flex: p[2], colors: clubColors(away), label: label(p[2])),
      ],
    );
  }
}

/// Last results as a short bar scarf: won solid, drew cross-stitched, lost a dropped stitch.
class FormScarf extends StatelessWidget {
  const FormScarf({super.key, required this.form, this.cell = 22});

  final List<String> form;
  final double cell;

  @override
  Widget build(BuildContext context) {
    if (form.isEmpty) {
      return Text('No games yet', style: Theme.of(context).textTheme.bodySmall);
    }
    const words = {'W': 'won', 'D': 'drew', 'L': 'lost'};
    return SizedBox(
      width: cell * form.length,
      child: Scarf(
        height: cell,
        stripeWidth: cell,
        semanticLabel: 'Form: ${form.map((r) => words[r] ?? r).join(', ')}',
        bands: [
          for (final r in form)
            ScarfBand(
              flex: 1,
              colors: [r == 'W' ? TL.win : r == 'D' ? TL.draw : TL.loss],
              knit: r == 'W' ? Knit.solid : r == 'D' ? Knit.cross : Knit.dropped,
              label: r,
            ),
        ],
      ),
    );
  }
}

/// A club's own bar scarf with its name knitted on a panel.
class ClubScarf extends StatelessWidget {
  const ClubScarf({super.key, required this.club, this.height = 72});

  final Club club;
  final double height;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Scarf(
      height: height,
      fringe: true,
      stripeWidth: 16,
      labelStyles: [tt.displaySmall!, tt.headlineSmall!],
      semanticLabel: '${club.name} scarf',
      bands: [ScarfBand(flex: 1, colors: clubColors(club), label: club.name.toUpperCase())],
    );
  }
}
```

`app/lib/widgets/crest.dart`:
```dart
import 'package:flutter/material.dart';

import '../data/bundle.dart';
import '../theme/tokens.dart';
import 'scarf.dart';

/// First letters of up to two capitalised words: "Borussia Dortmund" -> "BD".
String initials(String name) {
  final words = name.split(RegExp(r'[\s.\-]+')).where((w) => w.isNotEmpty).toList();
  final caps = words.where((w) => w[0] != w[0].toLowerCase()).toList();
  final pick = (caps.isEmpty ? words : caps).take(2);
  return pick.isEmpty ? '?' : pick.map((w) => w[0]).join().toUpperCase();
}

class Crest extends StatelessWidget {
  const Crest({super.key, required this.club, this.size = 32});

  final Club? club;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = club;
    final fallback = _Monogram(club: c, size: size);
    if (c?.crest == null) return fallback;
    return Image.network(
      c!.crest!,
      width: size,
      height: size,
      fit: BoxFit.contain,
      semanticLabel: '${c.name} crest',
      webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
      errorBuilder: (context, error, stack) => fallback,
    );
  }
}

class _Monogram extends StatelessWidget {
  const _Monogram({required this.club, required this.size});

  final Club? club;
  final double size;

  @override
  Widget build(BuildContext context) {
    final bg = clubColors(club).first;
    return Container(
      key: const ValueKey('monogram'),
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(size / 4)),
      child: Text(
        initials(club?.name ?? '?'),
        style: Theme.of(context).textTheme.headlineSmall!.copyWith(color: onColor(bg)),
      ),
    );
  }
}
```

`app/lib/widgets/player_avatar.dart`:
```dart
import 'package:flutter/material.dart';

import '../data/bundle.dart';
import 'crest.dart';

class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({super.key, required this.player, this.size = 56});

  final Player player;

  /// Width; height is 4:3 of it (Transfermarkt portraits are 3:4).
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fallback = Container(
      key: const ValueKey('initials'),
      color: scheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Text(initials(player.name),
          style: Theme.of(context).textTheme.headlineSmall!
              .copyWith(color: scheme.onSurfaceVariant)),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: size,
        height: size * 4 / 3,
        child: player.img == null
            ? fallback
            : Image.network(player.img!,
                fit: BoxFit.cover,
                semanticLabel: player.name,
                webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                errorBuilder: (context, error, stack) => fallback),
      ),
    );
  }
}
```

`app/lib/widgets/empty_note.dart`:
```dart
import 'package:flutter/material.dart';

class EmptyNote extends StatelessWidget {
  const EmptyNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Icon(Icons.hourglass_empty_rounded, size: 18, color: scheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: Theme.of(context).textTheme.bodyMedium!
                  .copyWith(color: scheme.onSurfaceVariant)),
        ),
      ]),
    );
  }
}
```

`app/lib/widgets/section.dart`:
```dart
import 'package:flutter/material.dart';

/// Section title with more space above than below; optional trailing action.
class SectionHeading extends StatelessWidget {
  const SectionHeading(this.title, {super.key, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 28, 8, 8),
        child: Row(children: [
          Expanded(
              child: Semantics(
                  header: true,
                  child: Text(title, style: Theme.of(context).textTheme.titleLarge))),
          if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
        ]),
      );
}
```

`app/lib/widgets/stat_bar.dart`:
```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../format.dart';
import '../theme/theme.dart';

/// Signed effect bar centred at zero ("+35%" pushes right, "−12%" left).
class EffectBar extends StatelessWidget {
  const EffectBar({super.key, required this.label, required this.effect, this.maxAbs = 1.0});

  final String label;
  final double effect;
  final double maxAbs;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final frac = (effect.abs() / maxAbs).clamp(0.0, 1.0);
    final positive = effect >= 0;
    final text = '${positive ? '+' : '−'}${(effect.abs() * 100).round()}%';
    return Semantics(
      label: '$label: $text',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Expanded(flex: 5, child: Text(label, style: tt.bodyMedium)),
            Expanded(
              flex: 4,
              child: LayoutBuilder(builder: (context, c) {
                final half = c.maxWidth / 2;
                final w = math.max(2.0, half * frac);
                return SizedBox(
                  height: 10,
                  child: Stack(children: [
                    Positioned(left: half - 0.5, top: 0, bottom: 0,
                        child: Container(width: 1, color: scheme.outline)),
                    Positioned(
                      left: positive ? half : half - w,
                      width: w, top: 1, bottom: 1,
                      child: DecoratedBox(decoration: BoxDecoration(
                          color: positive ? scheme.primary : scheme.tertiary,
                          borderRadius: BorderRadius.circular(2))),
                    ),
                  ]),
                );
              }),
            ),
            SizedBox(width: 56,
                child: Text(text, textAlign: TextAlign.end, style: tabular(tt.labelLarge!))),
          ]),
        ),
      ),
    );
  }
}

/// A 0–1 share with its percentage.
class ShareBar extends StatelessWidget {
  const ShareBar({super.key, required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Semantics(
      label: '$label ${pct(value)}',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            SizedBox(width: 96, child: Text(label, style: tt.bodyMedium)),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                    value: value.clamp(0.0, 1.0), minHeight: 10,
                    color: scheme.primary, backgroundColor: scheme.surfaceContainerHighest),
              ),
            ),
            SizedBox(width: 52,
                child: Text(pct(value), textAlign: TextAlign.end,
                    style: tabular(tt.labelLarge!))),
          ]),
        ),
      ),
    );
  }
}
```

`app/lib/widgets/value_chart.dart`:
```dart
import 'package:flutter/material.dart';

import '../data/bundle.dart';
import '../format.dart';
import 'empty_note.dart';

class ValueChart extends StatelessWidget {
  const ValueChart({super.key, required this.points});

  final List<ValuePoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) return const EmptyNote('Not enough valuations to draw a trend yet.');
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final first = points.first, last = points.last;
    final hi = points.map((p) => p.value).reduce((a, b) => a > b ? a : b);
    return Semantics(
      label: 'Market value from ${money(first.value)} in ${first.date.year} '
          'to ${money(last.value)} in ${last.date.year}, peak ${money(hi)}',
      child: ExcludeSemantics(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            height: 120,
            child: CustomPaint(
              size: Size.infinite,
              painter: _LinePainter(points, scheme.primary, scheme.outlineVariant),
            ),
          ),
          const SizedBox(height: 6),
          Row(children: [
            Text('${first.date.year}', style: tt.labelMedium),
            const Spacer(),
            Text('Peak ${money(hi)}', style: tt.labelMedium),
            const Spacer(),
            Text('${last.date.year} · ${money(last.value)}', style: tt.labelMedium),
          ]),
        ]),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter(this.points, this.line, this.grid);

  final List<ValuePoint> points;
  final Color line;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    final t0 = points.first.date.millisecondsSinceEpoch.toDouble();
    final t1 = points.last.date.millisecondsSinceEpoch.toDouble();
    final vmax = points.map((p) => p.value).reduce((a, b) => a > b ? a : b).toDouble();
    Offset at(ValuePoint p) => Offset(
        (p.date.millisecondsSinceEpoch - t0) / (t1 - t0 == 0 ? 1 : t1 - t0) * size.width,
        size.height - 4 - (p.value / (vmax == 0 ? 1 : vmax)) * (size.height - 12));
    final gp = Paint()
      ..color = grid
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, size.height - 4), Offset(size.width, size.height - 4), gp);
    final path = Path()..moveTo(at(points.first).dx, at(points.first).dy);
    for (final p in points.skip(1)) {
      path.lineTo(at(p).dx, at(p).dy);
    }
    canvas.drawPath(path, Paint()
      ..color = line
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round);
    canvas.drawCircle(at(points.last), 4, Paint()..color = line);
  }

  @override
  bool shouldRepaint(_LinePainter old) => old.points != points || old.line != line;
}
```

- [ ] **Step 4: Run, expect PASS** — `/c/flutter/bin/flutter test test/widgets_test.dart && /c/flutter/bin/flutter analyze`. If `Image.network` rejects `webHtmlElementStrategy`, check the parameter name in `flutter/lib/src/widgets/image.dart` of the installed SDK and use what it declares (record a ruling).

- [ ] **Step 5: Commit** — `git add app && git commit -m "feat(app): scarf painter, fixture/form/club scarves and shared widgets"`

---

### Task 10: Rows, routes, club and player detail screens

The two detail screens link to each other (squad → player, player → club), so they ship together.

**Files:**
- Modify: `app/lib/format.dart` (+ `thousands`, `ordinal`), `app/lib/widgets/section.dart` (`padded` flag)
- Create: `app/lib/widgets/rows.dart`, `app/lib/screens/routes.dart`, `app/lib/screens/club_detail_screen.dart`, `app/lib/screens/player_detail_screen.dart`
- Test: `app/test/format_test.dart` (extend), `app/test/detail_screens_test.dart`

**Interfaces:**
- Consumes: selectors (Task 5), voice/format (Task 7), widgets (Task 9), `AppScope` (Task 8)
- Produces: `String thousands(int)` ("4,498"), `String ordinal(int)` ("1st", "22nd", "13th"); `SectionHeading(..., padded: true)`; rows `PlayerRow{player, subtitle?, trailing?, onTap?}`, `ClubRow{club, subtitle?, trailing?, onTap?}`, `FixtureRow{fixture, home, away, now, onTap?}`, `PlayerTile{player, note?, onTap?}`, `PlayerStrip{players, notes?}`; routes `openClub(context, id)`, `openPlayer(context, id)`, `openCompare(context, firstId)` (the last is wired in Task 11); screens `ClubDetailScreen{clubId}`, `PlayerDetailScreen{playerId}`.

- [ ] **Step 1: Failing tests**

Append to `app/test/format_test.dart` inside `main()`:
```dart
  test('thousands and ordinal', () {
    expect(thousands(4498), '4,498');
    expect(thousands(980), '980');
    expect(thousands(1234567), '1,234,567');
    expect([1, 2, 3, 4, 11, 12, 13, 21, 22, 23].map(ordinal),
        ['1st', '2nd', '3rd', '4th', '11th', '12th', '13th', '21st', '22nd', '23rd']);
  });
```

`app/test/detail_screens_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchline/screens/club_detail_screen.dart';
import 'package:touchline/screens/player_detail_screen.dart';

import 'helpers.dart';

void main() {
  testWidgets('qualified player shows value, why, forecast and workload', (tester) async {
    final p = fixtureBundle().players.firstWhere((p) =>
        p.qualified && p.fairValue != null && p.forecastGa5 != null && p.workload != null &&
        p.valueHistory.length > 2);
    await pumpApp(tester, PlayerDetailScreen(playerId: p.id));
    expect(find.text(p.name), findsWidgets);
    expect(find.textContaining('Fair'), findsWidgets);
    await tester.scrollUntilVisible(find.textContaining('not an injury prediction'), 300);
    expect(find.textContaining('not an injury prediction'), findsOneWidget);
  });

  testWidgets('unqualified player never shows a fair value or forecast', (tester) async {
    final p = fixtureBundle().players.firstWhere((p) => !p.qualified);
    await pumpApp(tester, PlayerDetailScreen(playerId: p.id));
    expect(find.text('Not enough minutes yet to judge.'), findsOneWidget);
    expect(find.textContaining('Not enough minutes yet for a fair-value read'), findsOneWidget);
    expect(find.textContaining('€0'), findsNothing);
  });

  testWidgets('favourite toggles from the player screen', (tester) async {
    final p = fixtureBundle().players.first;
    final s = await pumpApp(tester, PlayerDetailScreen(playerId: p.id));
    await tester.tap(find.byTooltip('Add to your players'));
    await tester.pump();
    expect(s.isFavourite(p.id), isTrue);
    expect(find.byTooltip('Remove from your players'), findsOneWidget);
  });

  testWidgets('club detail shows the scarf, odds and squad', (tester) async {
    final b = fixtureBundle();
    final c = b.clubs.firstWhere((c) => c.proj != null && b.players.any((p) => p.club == c.id));
    await pumpApp(tester, ClubDetailScreen(clubId: c.id));
    expect(find.bySemanticsLabel('${c.name} scarf'), findsOneWidget);
    expect(find.text('Season odds'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Squad'), 300);
    expect(find.text('Squad'), findsOneWidget);
  });

  testWidgets('unknown ids show a friendly note instead of crashing', (tester) async {
    await pumpApp(tester, const PlayerDetailScreen(playerId: -42));
    expect(find.textContaining('no longer in the data'), findsOneWidget);
    await pumpApp(tester, const ClubDetailScreen(clubId: -42));
    expect(find.textContaining('no longer in the data'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run, expect FAIL.**

- [ ] **Step 3: Implement**

Append to `app/lib/format.dart`:
```dart
String thousands(int n) {
  final s = n.abs().toString();
  final b = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

String ordinal(int n) {
  final t = n % 100;
  if (t >= 11 && t <= 13) return '${n}th';
  return '$n${switch (n % 10) { 1 => 'st', 2 => 'nd', 3 => 'rd', _ => 'th' }}';
}
```

In `app/lib/widgets/section.dart` add `this.padded = true` (field `final bool padded;`) and use padding `padded ? const EdgeInsets.fromLTRB(16, 28, 8, 8) : const EdgeInsets.fromLTRB(0, 28, 0, 8)`.

`app/lib/widgets/rows.dart`:
```dart
import 'package:flutter/material.dart';

import '../data/bundle.dart';
import '../format.dart';
import 'crest.dart';
import 'player_avatar.dart';
import 'scarf.dart';

class _RowShell extends StatelessWidget {
  const _RowShell({required this.leading, required this.title, this.subtitle, this.trailing,
      this.onTap});

  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: tt.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (subtitle != null)
                  Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: tt.bodySmall!.copyWith(color: scheme.onSurfaceVariant)),
              ]),
            ),
            if (trailing != null) ...[const SizedBox(width: 12), trailing!],
          ]),
        ),
      ),
    );
  }
}

class PlayerRow extends StatelessWidget {
  const PlayerRow({super.key, required this.player, this.subtitle, this.trailing, this.onTap});
  final Player player;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => _RowShell(
      leading: PlayerAvatar(player: player, size: 36),
      title: player.name,
      subtitle: subtitle ?? player.clubName,
      trailing: trailing,
      onTap: onTap);
}

class ClubRow extends StatelessWidget {
  const ClubRow({super.key, required this.club, this.subtitle, this.trailing, this.onTap});
  final Club club;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => _RowShell(
      leading: Crest(club: club), title: club.name, subtitle: subtitle, trailing: trailing,
      onTap: onTap);
}

class FixtureRow extends StatelessWidget {
  const FixtureRow({super.key, required this.fixture, required this.home, required this.away,
      required this.now, this.onTap});
  final Fixture fixture;
  final Club? home;
  final Club? away;
  final DateTime now;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final score = fixture.score;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          SizedBox(
            width: 92,
            child: Text(score != null ? '${score[0]}–${score[1]}' : kickoffLabel(fixture.kickoff, now),
                style: score != null ? tt.headlineSmall : tt.labelLarge!
                    .copyWith(color: scheme.onSurfaceVariant)),
          ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${home?.name ?? 'TBC'} v ${away?.name ?? 'TBC'}',
                  style: tt.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              FixtureScarf(fixture: fixture, home: home, away: away, height: 18),
            ]),
          ),
        ]),
      ),
    );
  }
}

class PlayerTile extends StatelessWidget {
  const PlayerTile({super.key, required this.player, this.note, this.onTap});
  final Player player;
  final String? note;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 156,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              PlayerAvatar(player: player, size: 52),
              const SizedBox(height: 10),
              Text(player.name, style: tt.titleSmall, maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              Text(player.clubName ?? '', style: tt.bodySmall!
                  .copyWith(color: scheme.onSurfaceVariant), maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const Spacer(),
              if (note != null)
                Text(note!, style: tt.labelMedium!.copyWith(color: scheme.primary),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
            ]),
          ),
        ),
      ),
    );
  }
}

class PlayerStrip extends StatelessWidget {
  const PlayerStrip({super.key, required this.players, this.notes, this.onTap});
  final List<Player> players;
  final String? Function(Player)? notes;
  final void Function(Player)? onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 228,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          itemCount: players.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, i) => PlayerTile(
              player: players[i],
              note: notes?.call(players[i]) ??
                  (players[i].trendReasons.isEmpty ? null : players[i].trendReasons.first),
              onTap: onTap == null ? null : () => onTap!(players[i])),
        ),
      );
}
```

`app/lib/screens/routes.dart`:
```dart
import 'package:flutter/material.dart';

import 'club_detail_screen.dart';
import 'compare_screen.dart';
import 'player_detail_screen.dart';

void openClub(BuildContext context, int id) => Navigator.of(context)
    .push(MaterialPageRoute<void>(builder: (_) => ClubDetailScreen(clubId: id)));

void openPlayer(BuildContext context, int id) => Navigator.of(context)
    .push(MaterialPageRoute<void>(builder: (_) => PlayerDetailScreen(playerId: id)));

void openCompare(BuildContext context, int firstId) => Navigator.of(context)
    .push(MaterialPageRoute<void>(builder: (_) => CompareScreen(firstId: firstId)));
```
Ruling for the executor: Tasks 10 and 11 land together. Write `app/lib/screens/compare_screen.dart` exactly as given in Task 11 Step 3 during this step (routes import it); Task 11 then adds only its tests and commit.

`app/lib/screens/club_detail_screen.dart`:
```dart
import 'package:flutter/material.dart';

import '../copy/voice.dart';
import '../data/selectors.dart';
import '../format.dart';
import '../state/app_state.dart';
import '../widgets/crest.dart';
import '../widgets/empty_note.dart';
import '../widgets/rows.dart';
import '../widgets/scarf.dart';
import '../widgets/section.dart';
import '../widgets/stat_bar.dart';
import 'routes.dart';

class ClubDetailScreen extends StatelessWidget {
  const ClubDetailScreen({super.key, required this.clubId});
  final int clubId;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final b = s.bundle!;
    final c = b.clubById[clubId];
    if (c == null) {
      return Scaffold(appBar: AppBar(),
          body: const Padding(padding: EdgeInsets.all(16),
              child: EmptyNote('This club is no longer in the data.')));
    }
    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final p = c.proj;
    final fixtures = clubFixtures(b, c.id);
    final players = squad(b, c.id);
    final change = c.eloChange30d;
    return Scaffold(
      appBar: AppBar(title: Text(c.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          ClubScarf(club: c),
          const SizedBox(height: 16),
          Row(children: [
            Crest(club: c, size: 44),
            const SizedBox(width: 12),
            Expanded(child: Text(clubVerdict(c), style: tt.titleMedium)),
          ]),
          const SizedBox(height: 8),
          Text('${b.leagueById[c.league]?.name ?? c.league} · ${ordinal(c.table.pos)} · '
              '${c.table.points} pts from ${c.table.played}',
              style: tt.bodyMedium!.copyWith(color: scheme.onSurfaceVariant)),
          const SectionHeading('Form', padded: false),
          Row(children: [
            FormScarf(form: c.form),
            const SizedBox(width: 12),
            Expanded(child: Text(formVerdict(c.form), style: tt.bodyMedium)),
          ]),
          const SectionHeading('Season odds', padded: false),
          if (p == null)
            const EmptyNote('Odds appear once the live season has loaded.')
          else ...[
            ShareBar(label: 'Title', value: p.pTitle),
            ShareBar(label: 'Top four', value: p.pTop4),
            ShareBar(label: 'Bottom three', value: p.pReleg),
            const SizedBox(height: 6),
            Text('Expected finish ${ordinal(p.expPos.round())} on about '
                '${p.expPoints.round()} points.', style: tt.bodyMedium),
          ],
          const SectionHeading('Power rating', padded: false),
          Text('Elo ${c.elo.round()} · ${change >= 0 ? '+' : '−'}${change.abs().round()} in 30 days',
              style: tt.titleMedium),
          const SectionHeading('Fixtures', padded: false),
          if (fixtures.isEmpty)
            const EmptyNote('No fixtures in the window we track.')
          else
            for (final f in fixtures)
              FixtureRow(fixture: f, home: b.clubById[f.home], away: b.clubById[f.away],
                  now: s.now),
          const SectionHeading('Squad', padded: false),
          if (players.isEmpty)
            const EmptyNote('No squad data for this club yet.')
          else
            for (final pl in players.take(30))
              PlayerRow(
                player: pl,
                subtitle: '${pl.subPos ?? pl.pos ?? ''}${pl.age == null ? '' : ' · ${pl.age!.floor()}'}',
                trailing: Text(money(pl.marketValue), style: tt.labelLarge),
                onTap: () => openPlayer(context, pl.id),
              ),
        ],
      ),
    );
  }
}
```

`app/lib/screens/player_detail_screen.dart`:
```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../copy/voice.dart';
import '../data/bundle.dart';
import '../data/selectors.dart';
import '../format.dart';
import '../state/app_state.dart';
import '../widgets/empty_note.dart';
import '../widgets/player_avatar.dart';
import '../widgets/rows.dart';
import '../widgets/section.dart';
import '../widgets/stat_bar.dart';
import '../widgets/value_chart.dart';
import 'routes.dart';

class PlayerDetailScreen extends StatelessWidget {
  const PlayerDetailScreen({super.key, required this.playerId});
  final int playerId;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final b = s.bundle!;
    final p = b.playerById[playerId];
    if (p == null) {
      return Scaffold(appBar: AppBar(),
          body: const Padding(padding: EdgeInsets.all(16),
              child: EmptyNote('This player is no longer in the data.')));
    }
    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final fav = s.isFavourite(p.id);
    final muted = tt.bodyMedium!.copyWith(color: scheme.onSurfaceVariant);
    final cheaper = similarCheaper(b, p).map((x) => x.id).toSet();
    final similar = [for (final id in p.similar) if (b.playerById[id] case final x?) x];
    return Scaffold(
      appBar: AppBar(title: Text(p.name), actions: [
        IconButton(
          tooltip: fav ? 'Remove from your players' : 'Add to your players',
          icon: Icon(fav ? Icons.star_rounded : Icons.star_outline_rounded),
          onPressed: () => s.toggleFavourite(p.id),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openCompare(context, p.id),
        icon: const Icon(Icons.compare_arrows_rounded),
        label: const Text('Compare'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 104),
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            PlayerAvatar(player: p, size: 84),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.name, style: tt.titleLarge),
                if (p.clubName != null)
                  InkWell(
                    onTap: p.club != null && b.clubById.containsKey(p.club)
                        ? () => openClub(context, p.club!)
                        : null,
                    child: Padding(padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(p.clubName!, style: tt.titleSmall!
                            .copyWith(color: scheme.primary))),
                  ),
                Text([
                  p.subPos ?? p.pos,
                  if (p.age != null) 'Age ${p.age!.floor()}',
                  p.nat,
                ].whereType<String>().join(' · '), style: muted),
              ]),
            ),
          ]),
          const SizedBox(height: 20),
          Text(playerVerdict(p), style: tt.titleMedium),
          const SizedBox(height: 6),
          Text('${b.playerSeason}: ${p.season.apps} apps · ${thousands(p.season.minutes)} min · '
              '${p.season.goals} goals · ${p.season.assists} assists', style: muted),
          const SectionHeading('Value', padded: false),
          ..._value(context, p),
          const SectionHeading('Form', padded: false),
          ..._form(context, p),
          const SectionHeading('Workload', padded: false),
          ..._workload(context, p),
          const SectionHeading('Market value over time', padded: false),
          ValueChart(points: p.valueHistory),
          const SectionHeading('Transfers', padded: false),
          if (p.transfers.isEmpty)
            const EmptyNote('No transfers on record.')
          else
            for (final t in p.transfers.reversed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  SizedBox(width: 64, child: Text('${t.date.year}', style: tt.labelLarge)),
                  Expanded(child: Text('${t.from ?? '?'} → ${t.to ?? '?'}',
                      style: tt.bodyMedium, maxLines: 2)),
                  Text(t.fee == null ? '–' : t.fee == 0 ? 'Free' : money(t.fee),
                      style: tt.labelLarge),
                ]),
              ),
          const SectionHeading('Plays like', padded: false),
          if (similar.isEmpty)
            const EmptyNote('Not enough minutes to find lookalikes.')
          else
            Transform.translate(
              offset: const Offset(-16, 0),
              child: SizedBox(
                width: MediaQuery.sizeOf(context).width,
                child: PlayerStrip(
                  players: similar,
                  notes: (x) => cheaper.contains(x.id) ? 'Cheaper · ${money(x.marketValue)}'
                      : money(x.marketValue),
                  onTap: (x) => openPlayer(context, x.id),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _value(BuildContext context, Player p) {
    final tt = Theme.of(context).textTheme;
    final fv = p.fairValue, mv = p.marketValue;
    if (fv == null) {
      return [
        Text('Market ${money(mv)}', style: tt.titleMedium),
        const EmptyNote('Not enough minutes yet for a fair-value read.'),
      ];
    }
    final gap = fv - (mv ?? 0);
    final why = p.valueWhy ?? const <ValueWhy>[];
    final maxAbs = why.isEmpty ? 1.0 : why.map((w) => w.effectPct.abs()).reduce(math.max);
    return [
      Text('Market ${money(mv)} · Fair ${money(fv)}', style: tt.titleMedium),
      const SizedBox(height: 4),
      Text(gap >= 0
          ? 'The numbers say ${signedMoney(gap)} more than his price.'
          : 'Priced ${money(-gap)} above what the numbers show.', style: tt.bodyMedium),
      if (why.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text('What moves his value', style: tt.titleSmall),
        for (final w in why) EffectBar(label: w.label, effect: w.effectPct, maxAbs: maxAbs),
      ],
    ];
  }

  List<Widget> _form(BuildContext context, Player p) {
    final tt = Theme.of(context).textTheme;
    return [
      if (p.last5.isEmpty)
        const EmptyNote('No recent appearances.')
      else
        for (final g in p.last5.reversed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              SizedBox(width: 64, child: Text(shortDate(g.date), style: tt.labelLarge)),
              Expanded(child: Text(g.opp ?? 'Unknown opponent', style: tt.bodyMedium,
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
              Text('${g.ga} G/A · ${g.minutes}′', style: tt.labelLarge),
            ]),
          ),
      const SizedBox(height: 8),
      if (p.forecastGa5 == null)
        const EmptyNote('Not enough minutes yet for a forecast.')
      else
        Text('Projected ${p.forecastGa5!.toStringAsFixed(1)} goal involvements in the next five.',
            style: tt.titleMedium),
    ];
  }

  List<Widget> _workload(BuildContext context, Player p) {
    final tt = Theme.of(context).textTheme;
    final w = p.workload;
    if (w == null) return const [EmptyNote('No appearances to measure.')];
    return [
      Text('${w.band} · ${workloadVerdict(w.band)}', style: tt.titleMedium),
      ShareBar(label: 'Risk index', value: w.index / 100),
      Text('${thousands(w.seasonMinutes)} minutes · ${w.congestedApps} games on short rest · '
          'as of ${shortDate(w.asOf)}', style: tt.bodyMedium),
      const SizedBox(height: 4),
      Text('A workload risk index, not an injury prediction.',
          style: tt.bodySmall!.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
    ];
  }
}
```

- [ ] **Step 4: Run, expect PASS** — `/c/flutter/bin/flutter test && /c/flutter/bin/flutter analyze`.

- [ ] **Step 5: Commit** — `git add app && git commit -m "feat(app): club and player detail screens"`

---

### Task 11: Compare

**Files:**
- Create: `app/lib/screens/compare_screen.dart`
- Test: `app/test/compare_test.dart`

**Interfaces:**
- Consumes: `searchPlayers`, `PlayerQuery` (Task 5); `PlayerRow` (Task 10)
- Produces: `CompareScreen{firstId, secondId?}`; `List<CompareLine> compareLines(Player a, Player b)` where `CompareLine{label, a, b, better}` (`better` is -1 for a, 1 for b, 0 for none or no data).

- [ ] **Step 1: Failing tests** — `app/test/compare_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchline/screens/compare_screen.dart';

import 'helpers.dart';

void main() {
  test('compare lines mark the better side and skip judgement on missing data', () {
    final ps = fixtureBundle().players.where((p) => p.qualified).toList();
    final a = ps.first, b = ps[1];
    final lines = compareLines(a, b);
    expect(lines.map((l) => l.label), contains('Fair value'));
    final work = lines.firstWhere((l) => l.label == 'Workload index');
    if (a.workload != null && b.workload != null && a.workload!.index != b.workload!.index) {
      expect(work.better, a.workload!.index < b.workload!.index ? -1 : 1); // lower is better
    }
    final unq = fixtureBundle().players.firstWhere((p) => !p.qualified);
    expect(compareLines(a, unq).firstWhere((l) => l.label == 'Fair value').better, 0);
  });

  testWidgets('pick a second player, then see the table', (tester) async {
    final ps = fixtureBundle().players.where((p) => p.qualified).toList();
    await pumpApp(tester, CompareScreen(firstId: ps.first.id));
    await tester.enterText(find.byType(TextField), ps[1].name);
    await tester.pump();
    await tester.tap(find.text(ps[1].name).last);
    await tester.pump();
    expect(find.text('Fair value'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_drop_up_rounded), findsWidgets);
  });
}
```

- [ ] **Step 2: Run, expect FAIL.**

- [ ] **Step 3: Implement** `app/lib/screens/compare_screen.dart`:
```dart
import 'package:flutter/material.dart';

import '../data/bundle.dart';
import '../data/selectors.dart';
import '../format.dart';
import '../state/app_state.dart';
import '../theme/theme.dart';
import '../widgets/empty_note.dart';
import '../widgets/rows.dart';

class CompareLine {
  const CompareLine(this.label, this.a, this.b, this.better);
  final String label;
  final String a;
  final String b;

  /// -1: first is better, 1: second is better, 0: equal or not comparable.
  final int better;
}

int _cmp(num? a, num? b, {bool lowerIsBetter = false}) {
  if (a == null || b == null || a == b) return 0;
  final aWins = lowerIsBetter ? a < b : a > b;
  return aWins ? -1 : 1;
}

List<CompareLine> compareLines(Player a, Player b) {
  String f1(double? v) => v == null ? '–' : v.toStringAsFixed(1);
  String f2(double? v) => v == null ? '–' : v.toStringAsFixed(2);
  return [
    CompareLine('Market value', money(a.marketValue), money(b.marketValue), 0),
    CompareLine('Fair value', money(a.fairValue), money(b.fairValue),
        _cmp(a.fairValue, b.fairValue)),
    CompareLine('Value vs price',
        a.valueGapPct == null ? '–' : pct(a.valueGapPct!),
        b.valueGapPct == null ? '–' : pct(b.valueGapPct!),
        _cmp(a.valueGapPct, b.valueGapPct)),
    CompareLine('G/A per 90', f2(a.season.ga90), f2(b.season.ga90),
        a.qualified && b.qualified ? _cmp(a.season.ga90, b.season.ga90) : 0),
    CompareLine('Goals', '${a.season.goals}', '${b.season.goals}',
        _cmp(a.season.goals, b.season.goals)),
    CompareLine('Assists', '${a.season.assists}', '${b.season.assists}',
        _cmp(a.season.assists, b.season.assists)),
    CompareLine('Minutes', thousands(a.season.minutes), thousands(b.season.minutes), 0),
    CompareLine('Projected G/A, next 5', f1(a.forecastGa5), f1(b.forecastGa5),
        _cmp(a.forecastGa5, b.forecastGa5)),
    CompareLine('Workload index', '${a.workload?.index ?? '–'}', '${b.workload?.index ?? '–'}',
        _cmp(a.workload?.index, b.workload?.index, lowerIsBetter: true)),
    CompareLine('Age', a.age == null ? '–' : '${a.age!.floor()}',
        b.age == null ? '–' : '${b.age!.floor()}', 0),
  ];
}

class CompareScreen extends StatefulWidget {
  const CompareScreen({super.key, required this.firstId, this.secondId});
  final int firstId;
  final int? secondId;

  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  late int? second = widget.secondId;
  String query = '';

  @override
  Widget build(BuildContext context) {
    final b = AppScope.of(context).bundle!;
    final a = b.playerById[widget.firstId];
    final other = second == null ? null : b.playerById[second];
    if (a == null) {
      return Scaffold(appBar: AppBar(),
          body: const Padding(padding: EdgeInsets.all(16),
              child: EmptyNote('This player is no longer in the data.')));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(other == null ? 'Compare ${a.name} with…' : 'Compare'),
        actions: [
          if (other != null)
            TextButton(onPressed: () => setState(() => second = null),
                child: const Text('Change')),
        ],
      ),
      body: other == null ? _picker(context, b, a) : _table(context, a, other),
    );
  }

  Widget _picker(BuildContext context, Bundle b, Player a) {
    final results = query.trim().isEmpty
        ? [for (final id in a.similar) if (b.playerById[id] case final x?) x]
        : searchPlayers(b, PlayerQuery(text: query)).where((p) => p.id != a.id).take(30)
            .toList();
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: TextField(
          autofocus: true,
          decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded), hintText: 'Search a player',
              border: OutlineInputBorder()),
          onChanged: (v) => setState(() => query = v),
        ),
      ),
      if (query.trim().isEmpty)
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(alignment: Alignment.centerLeft,
                child: Text('Players like him', style: Theme.of(context).textTheme.titleSmall))),
      Expanded(
        child: results.isEmpty
            ? const Padding(padding: EdgeInsets.all(16),
                child: EmptyNote('Nobody by that name. Try a surname.'))
            : ListView(children: [
                for (final p in results)
                  PlayerRow(player: p, onTap: () => setState(() => second = p.id)),
              ]),
      ),
    ]);
  }

  Widget _table(BuildContext context, Player a, Player b) {
    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    Widget cell(String v, bool wins, TextAlign align) => Row(
          mainAxisAlignment: align == TextAlign.end ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            if (wins && align == TextAlign.end)
              Icon(Icons.arrow_drop_up_rounded, color: scheme.primary, semanticLabel: 'better'),
            Text(v, style: tabular(wins ? tt.titleMedium!.copyWith(color: scheme.primary)
                : tt.bodyLarge!)),
            if (wins && align == TextAlign.start)
              Icon(Icons.arrow_drop_up_rounded, color: scheme.primary, semanticLabel: 'better'),
          ],
        );
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Row(children: [
          Expanded(child: Text(a.name, style: tt.titleMedium, textAlign: TextAlign.end)),
          const SizedBox(width: 120),
          Expanded(child: Text(b.name, style: tt.titleMedium)),
        ]),
        const SizedBox(height: 8),
        for (final l in compareLines(a, b)) ...[
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(children: [
              Expanded(child: cell(l.a, l.better == -1, TextAlign.end)),
              SizedBox(width: 120,
                  child: Text(l.label, textAlign: TextAlign.center,
                      style: tt.labelMedium!.copyWith(color: scheme.onSurfaceVariant))),
              Expanded(child: cell(l.b, l.better == 1, TextAlign.start)),
            ]),
          ),
        ],
        const SizedBox(height: 12),
        Text('Season figures are ${AppScope.of(context).bundle!.playerSeason}. '
            'Workload: lower is fresher.', style: tt.bodySmall),
      ],
    );
  }
}
```

- [ ] **Step 4: Run, expect PASS** — `/c/flutter/bin/flutter test && /c/flutter/bin/flutter analyze`.

- [ ] **Step 5: Commit** — `git add app && git commit -m "feat(app): player compare with search picker"`

---

### Task 12: Home dashboard

**Files:**
- Create: `app/lib/widgets/league_chips.dart`, `app/lib/widgets/brand.dart` (BrandBand, Wordmark, FreshnessChip), `app/lib/screens/match_sheet.dart`, `app/lib/screens/home_screen.dart`, `app/lib/screens/about_sheet.dart` (minimal entry point `showAboutSheet`, completed in Task 16)
- Test: `app/test/home_test.dart`

**Interfaces:**
- Consumes: everything in Tasks 5–10
- Produces: `LeagueChips{allowAll=true, selected?, onSelected?}` (global league when `onSelected` is null); `BrandBand`, `Wordmark`, `FreshnessChip`; `showMatchSheet(context, Fixture)`, `MatchSheet{fixture}`; `HeroFixture{fixture}`; `HomeScreen`; `showAboutSheet(context)`.

- [ ] **Step 1: Failing tests** — `app/test/home_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchline/data/bundle.dart';
import 'package:touchline/screens/home_screen.dart';
import 'package:touchline/state/app_state.dart';

import 'helpers.dart';

void main() {
  testWidgets('home leads with the hero scarf and has every section', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    await pumpApp(tester, const HomeScreen());
    expect(find.text('TOUCHLINE'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'win \d+%, draw \d+%')), findsWidgets);
    for (final h in ['Running hot', 'This week', 'Clubs in form', 'Power rankings', 'Bargains',
        'Overworked watch']) {
      await tester.scrollUntilVisible(find.text(h), 400);
      expect(find.text(h), findsOneWidget, reason: h);
    }
  });

  testWidgets('league chip filters globally', (tester) async {
    final s = await pumpApp(tester, const HomeScreen());
    await tester.tap(find.widgetWithText(ChoiceChip, 'LaLiga'));
    await tester.pump();
    expect(s.league, 'ES1');
  });

  testWidgets('tapping the hero opens the match breakdown', (tester) async {
    await pumpApp(tester, const HomeScreen());
    await tester.tap(find.byType(HeroFixture));
    await tester.pumpAndSettle();
    expect(find.textContaining('Expected goals'), findsWidgets);
    expect(find.text('Draw'), findsOneWidget);
  });

  testWidgets('a quiet week says so instead of collapsing', (tester) async {
    final s = AppState.preloaded(fixtureBundle(), clock: () => DateTime.utc(2027, 6, 1));
    await pumpApp(tester, const HomeScreen(), state: s);
    expect(find.textContaining('No fixtures in the next seven days'), findsOneWidget);
  });

  testWidgets('renders in dark mode without overflow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 780));
    await pumpApp(tester, const HomeScreen(), brightness: Brightness.dark);
    expect(tester.takeException(), isNull);
  });

  test('fixture bundle has fixtures around fixtureNow', () {
    final Bundle b = fixtureBundle();
    expect(b.fixtures.any((f) => !f.finished && f.kickoff.isAfter(fixtureNow)), isTrue);
  });
}
```

- [ ] **Step 2: Run, expect FAIL.**

- [ ] **Step 3: Implement**

`app/lib/widgets/league_chips.dart`:
```dart
import 'package:flutter/material.dart';

import '../state/app_state.dart';

class LeagueChips extends StatelessWidget {
  const LeagueChips({super.key, this.allowAll = true, this.selected, this.onSelected});

  final bool allowAll;
  final String? selected;

  /// When null, the chips drive the app-wide league filter.
  final ValueChanged<String?>? onSelected;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final current = onSelected == null ? s.league : selected;
    final select = onSelected ?? s.setLeague;
    Widget chip(String label, String? id) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(label: Text(label), selected: current == id,
              onSelected: (_) => select(id)),
        );
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          if (allowAll) chip('All', null),
          for (final l in s.bundle!.leagues) chip(l.name, l.id),
        ],
      ),
    );
  }
}
```
(The Premier League chip reads "Premier League", LaLiga "LaLiga": names come from the bundle.)

`app/lib/widgets/brand.dart`:
```dart
import 'package:flutter/material.dart';

import '../format.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import 'scarf.dart';

/// Touchline's own scarf as a thin knitted band.
class BrandBand extends StatelessWidget {
  const BrandBand({super.key});

  @override
  Widget build(BuildContext context) => const ExcludeSemantics(
        child: Scarf(
          height: 8,
          stripeWidth: 12,
          semanticLabel: '',
          bands: [ScarfBand(flex: 1, colors: [TL.pitch, TL.pink])],
        ),
      );
}

class Wordmark extends StatelessWidget {
  const Wordmark({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
        header: true,
        label: 'Touchline',
        child: ExcludeSemantics(
          child: Text('TOUCHLINE', style: Theme.of(context).textTheme.displaySmall!
              .copyWith(color: Theme.of(context).colorScheme.primary)),
        ),
      );
}

class FreshnessChip extends StatelessWidget {
  const FreshnessChip({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final (icon, label) = s.refreshing
        ? (Icons.sync_rounded, 'Updating')
        : s.reachable
            ? (Icons.cloud_done_outlined, 'Up to date')
            : (Icons.cloud_off_outlined, 'Offline');
    return Tooltip(
      message: 'Club data from ${shortDate(DateTime.parse(s.bundle!.clubsThrough))}',
      child: ActionChip(
        avatar: Icon(icon, size: 18),
        label: Text(label),
        onPressed: s.refreshing ? null : s.refresh,
      ),
    );
  }
}
```

`app/lib/screens/match_sheet.dart`:
```dart
import 'package:flutter/material.dart';

import '../copy/voice.dart';
import '../data/bundle.dart';
import '../format.dart';
import '../state/app_state.dart';
import '../widgets/scarf.dart';
import '../widgets/section.dart';
import '../widgets/stat_bar.dart';
import 'club_detail_screen.dart';

Future<void> showMatchSheet(BuildContext context, Fixture f) => showModalBottomSheet<void>(
    context: context, isScrollControlled: true, builder: (_) => MatchSheet(fixture: f));

class MatchSheet extends StatelessWidget {
  const MatchSheet({super.key, required this.fixture});
  final Fixture fixture;

  void _openClub(BuildContext context, int id) {
    final nav = Navigator.of(context);
    nav.pop();
    nav.push(MaterialPageRoute<void>(builder: (_) => ClubDetailScreen(clubId: id)));
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final b = s.bundle!;
    final f = fixture;
    final home = b.clubById[f.home];
    final away = b.clubById[f.away];
    final hn = home?.name ?? 'Home', an = away?.name ?? 'Away';
    final tt = Theme.of(context).textTheme;
    final muted = tt.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Text('$hn v $an', style: tt.titleLarge),
          Text('${kickoffLabel(f.kickoff, s.now)} · ${b.leagueById[f.league]?.name ?? f.league}',
              style: muted),
          const SizedBox(height: 16),
          FixtureScarf(fixture: f, home: home, away: away, hero: true),
          const SizedBox(height: 12),
          Text(fixtureVerdict(hn, an, f.p), style: tt.titleMedium),
          if (f.score != null) ...[
            const SizedBox(height: 6),
            Text('Final score ${f.score![0]}–${f.score![1]}', style: tt.titleMedium),
          ],
          const SizedBox(height: 12),
          ShareBar(label: hn, value: f.p[0]),
          ShareBar(label: 'Draw', value: f.p[1]),
          ShareBar(label: an, value: f.p[2]),
          const SizedBox(height: 6),
          Text('Expected goals: $hn ${f.xg[0].toStringAsFixed(1)} · '
              '$an ${f.xg[1].toStringAsFixed(1)}', style: muted),
          const SectionHeading('Form', padded: false),
          for (final c in [home, away])
            if (c != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  SizedBox(width: 120, child: Text(c.name, style: tt.bodyMedium,
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                  FormScarf(form: c.form, cell: 18),
                ]),
              ),
          const SizedBox(height: 16),
          Row(children: [
            if (home != null)
              Expanded(child: OutlinedButton(
                  onPressed: () => _openClub(context, home.id), child: Text(hn))),
            if (home != null && away != null) const SizedBox(width: 12),
            if (away != null)
              Expanded(child: OutlinedButton(
                  onPressed: () => _openClub(context, away.id), child: Text(an))),
          ]),
        ],
      ),
    );
  }
}
```

`app/lib/screens/about_sheet.dart` (entry point only; Task 16 fills in the body):
```dart
import 'package:flutter/material.dart';

Future<void> showAboutSheet(BuildContext context) => showModalBottomSheet<void>(
    context: context, isScrollControlled: true, builder: (_) => const AboutSheet());

class AboutSheet extends StatelessWidget {
  const AboutSheet({super.key});
  @override
  Widget build(BuildContext context) =>
      const Padding(padding: EdgeInsets.all(16), child: Text('How this works'));
}
```

`app/lib/screens/home_screen.dart`:
```dart
import 'package:flutter/material.dart';

import '../copy/voice.dart';
import '../data/bundle.dart';
import '../data/selectors.dart';
import '../format.dart';
import '../state/app_state.dart';
import '../widgets/brand.dart';
import '../widgets/crest.dart';
import '../widgets/empty_note.dart';
import '../widgets/league_chips.dart';
import '../widgets/rows.dart';
import '../widgets/scarf.dart';
import '../widgets/section.dart';
import 'about_sheet.dart';
import 'match_sheet.dart';
import 'routes.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final b = s.bundle!;
    final lg = s.league;
    final now = s.now;
    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final featured = featuredFixture(b, lg, now);
    final week = weekFixtures(b, lg, now).where((f) => f.id != featured?.id).take(6).toList();
    final hot = trendingPlayers(b, lg);
    final inForm = clubsInForm(b, lg);
    final ranks = powerRankings(b, lg);
    final deals = bargains(b, lg, n: 6);
    final tired = overworked(b, lg, n: 6);
    final favs = [for (final id in s.favourites) if (b.playerById[id] case final p?) p];

    Widget box(Widget w) => SliverToBoxAdapter(child: w);
    Widget pad(Widget w) =>
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: w);
    Widget list(List<Widget> rows, String empty) =>
        rows.isEmpty ? box(pad(EmptyNote(empty))) : SliverList.list(children: rows);

    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverAppBar(
          pinned: true,
          toolbarHeight: 64,
          titleSpacing: 16,
          title: const Wordmark(),
          actions: [
            const FreshnessChip(),
            IconButton(tooltip: 'How this works', icon: const Icon(Icons.info_outline_rounded),
                onPressed: () => showAboutSheet(context)),
            const SizedBox(width: 4),
          ],
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(60),
            child: Column(children: [BrandBand(), SizedBox(height: 4), LeagueChips()]),
          ),
        ),
        box(Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: featured == null
              ? const EmptyNote('No fixtures in the next seven days. International break, probably.')
              : HeroFixture(fixture: featured),
        )),
        if (favs.isNotEmpty) ...[
          box(const SectionHeading('Your players')),
          box(PlayerStrip(players: favs, onTap: (p) => openPlayer(context, p.id))),
        ],
        box(const SectionHeading('Running hot')),
        box(hot.isEmpty
            ? pad(const EmptyNote('Nobody is on a run worth shouting about.'))
            : PlayerStrip(players: hot, onTap: (p) => openPlayer(context, p.id))),
        box(const SectionHeading('This week')),
        list([
          for (final f in week)
            FixtureRow(fixture: f, home: b.clubById[f.home], away: b.clubById[f.away], now: now,
                onTap: () => showMatchSheet(context, f)),
        ], 'Nothing else on this week.'),
        box(const SectionHeading('Clubs in form')),
        list([
          for (final c in inForm)
            ClubRow(
              club: c,
              subtitle: formVerdict(c.form),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                FormScarf(form: c.form, cell: 16),
                const SizedBox(width: 10),
                _EloDelta(c.eloChange30d),
              ]),
              onTap: () => openClub(context, c.id),
            ),
        ], 'No league games played yet.'),
        box(const SectionHeading('Power rankings')),
        list([
          for (final (i, c) in ranks.indexed)
            ClubRow(
              club: c,
              subtitle: '${ordinal(i + 1)} · ${b.leagueById[c.league]?.name ?? c.league}',
              trailing: Text('${c.elo.round()}', style: tt.labelLarge),
              onTap: () => openClub(context, c.id),
            ),
        ], 'No ratings for this league.'),
        box(const SectionHeading('Bargains')),
        list([
          for (final p in deals)
            PlayerRow(
              player: p,
              subtitle: '${p.clubName ?? ''} · priced ${money(p.marketValue)}',
              trailing: Text(signedMoney(p.fairValue! - p.marketValue!),
                  style: tt.titleSmall!.copyWith(color: scheme.primary)),
              onTap: () => openPlayer(context, p.id),
            ),
        ], 'No clear bargains above ${money(bargainFloor)} here.'),
        box(const SectionHeading('Overworked watch')),
        list([
          for (final p in tired)
            PlayerRow(
              player: p,
              subtitle: '${thousands(p.workload!.seasonMinutes)} min · '
                  '${p.workload!.congestedApps} on short rest',
              trailing: _BandLabel(p.workload!),
              onTap: () => openPlayer(context, p.id),
            ),
        ], 'Nobody is carrying an unusual load.'),
        box(Padding(
          padding: const EdgeInsets.fromLTRB(16, 32, 16, 32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Club data from ${shortDate(DateTime.parse(b.clubsThrough))}. '
                'Player stats: ${b.playerSeason} season.',
                style: tt.bodySmall!.copyWith(color: scheme.onSurfaceVariant)),
            TextButton(onPressed: () => showAboutSheet(context),
                child: const Text('How the numbers are made')),
          ]),
        )),
      ]),
    );
  }
}

class HeroFixture extends StatelessWidget {
  const HeroFixture({super.key, required this.fixture});
  final Fixture fixture;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final b = s.bundle!;
    final f = fixture;
    final home = b.clubById[f.home], away = b.clubById[f.away];
    final hn = home?.name ?? 'Home', an = away?.name ?? 'Away';
    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showMatchSheet(context, f),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$hn v $an', style: tt.titleLarge),
            Text('${kickoffLabel(f.kickoff, s.now)} · ${b.leagueById[f.league]?.name ?? ''}',
                style: tt.bodyMedium!.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            Row(children: [
              Crest(club: home, size: 36),
              const SizedBox(width: 8),
              Expanded(child: FixtureScarf(fixture: f, home: home, away: away, hero: true)),
              const SizedBox(width: 8),
              Crest(club: away, size: 36),
            ]),
            const SizedBox(height: 14),
            Text(fixtureVerdict(hn, an, f.p), style: tt.titleMedium),
            const SizedBox(height: 4),
            Row(children: [
              Text('Expected goals ${f.xg[0].toStringAsFixed(1)}–${f.xg[1].toStringAsFixed(1)}',
                  style: tt.bodyMedium!.copyWith(color: scheme.onSurfaceVariant)),
              const Spacer(),
              Text('Breakdown', style: tt.labelLarge!.copyWith(color: scheme.primary)),
              Icon(Icons.chevron_right_rounded, color: scheme.primary),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _EloDelta extends StatelessWidget {
  const _EloDelta(this.delta);
  final double delta;

  @override
  Widget build(BuildContext context) {
    final up = delta >= 0;
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Rating ${up ? 'up' : 'down'} ${delta.abs().round()} in 30 days',
      child: ExcludeSemantics(
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(up ? Icons.trending_up_rounded : Icons.trending_down_rounded, size: 18,
              color: up ? scheme.primary : scheme.tertiary),
          Text('${up ? '+' : '−'}${delta.abs().round()}',
              style: Theme.of(context).textTheme.labelLarge),
        ]),
      ),
    );
  }
}

class _BandLabel extends StatelessWidget {
  const _BandLabel(this.w);
  final Workload w;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      if (w.flag)
        Icon(Icons.warning_amber_rounded, size: 18, color: scheme.tertiary,
            semanticLabel: 'Unusual load'),
      const SizedBox(width: 4),
      Text('${w.band} · ${w.index}', style: tt.labelLarge),
    ]);
  }
}
```

- [ ] **Step 4: Run, expect PASS** — `/c/flutter/bin/flutter test && /c/flutter/bin/flutter analyze`. Overflow exceptions from the dark-mode 360dp test are real bugs: fix layout, not the test.

- [ ] **Step 5: Commit** — `git add app && git commit -m "feat(app): home dashboard with hero fixture scarf and match sheet"`

---

### Task 13: Clubs tab

**Files:**
- Create: `app/lib/screens/clubs_screen.dart`
- Test: `app/test/clubs_test.dart`

**Interfaces:**
- Consumes: `leagueTable`, `LeagueChips`, `Crest`, `openClub`
- Produces: `ClubsScreen`.

- [ ] **Step 1: Failing tests** — `app/test/clubs_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchline/data/bundle.dart';
import 'package:touchline/screens/clubs_screen.dart';
import 'package:touchline/state/app_state.dart';

import 'helpers.dart';

void main() {
  testWidgets('table then odds for the selected league', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 2400));
    await pumpApp(tester, const ClubsScreen());
    expect(find.text('Pts'), findsOneWidget);
    final pl = fixtureBundle().clubs.where((c) => c.league == 'GB1').length;
    expect(find.byType(InkWell), findsAtLeastNWidgets(pl));
    await tester.tap(find.text('Odds'));
    await tester.pump();
    expect(find.text('Title'), findsOneWidget);
    expect(find.text('Bottom 3'), findsOneWidget);
  });

  testWidgets('offline bundle without projections explains the missing odds', (tester) async {
    final s = AppState.preloaded(Bundle.fromJson(minimalBundleJson()));
    await pumpApp(tester, const ClubsScreen(), state: s);
    await tester.tap(find.text('Odds'));
    await tester.pump();
    expect(find.textContaining('Odds need the live season'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run, expect FAIL.**

- [ ] **Step 3: Implement** `app/lib/screens/clubs_screen.dart`:
```dart
import 'package:flutter/material.dart';

import '../data/bundle.dart';
import '../data/selectors.dart';
import '../format.dart';
import '../state/app_state.dart';
import '../theme/theme.dart';
import '../widgets/crest.dart';
import '../widgets/empty_note.dart';
import '../widgets/league_chips.dart';
import 'routes.dart';

class ClubsScreen extends StatefulWidget {
  const ClubsScreen({super.key});
  @override
  State<ClubsScreen> createState() => _ClubsScreenState();
}

class _ClubsScreenState extends State<ClubsScreen> {
  String? league;
  bool odds = false;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final b = s.bundle!;
    final lg = league ?? s.league ?? b.leagues.first.id;
    final rows = leagueTable(b, lg);
    final hasOdds = rows.any((c) => c.proj != null);
    final tt = Theme.of(context).textTheme;
    final muted = tt.labelMedium!.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);

    Widget num(String v, {bool strong = false}) => SizedBox(
        width: 56,
        child: Text(v, textAlign: TextAlign.end,
            style: tabular(strong ? tt.titleSmall! : tt.bodyMedium!)));
    Widget head(String v) => SizedBox(width: 56, child: Text(v, textAlign: TextAlign.end, style: muted));

    Widget row(Club c) {
      final p = c.proj;
      return InkWell(
        onTap: () => openClub(context, c.id),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              SizedBox(width: 28, child: Text('${c.table.pos}', style: tabular(tt.labelLarge!))),
              Crest(club: c, size: 28),
              const SizedBox(width: 10),
              Expanded(child: Text(c.name, style: tt.titleSmall, maxLines: 1,
                  overflow: TextOverflow.ellipsis)),
              if (!odds) ...[
                num('${c.table.played}'),
                num(c.table.gd > 0 ? '+${c.table.gd}' : '${c.table.gd}'),
                num('${c.table.points}', strong: true),
              ] else ...[
                num(p == null ? '–' : pct(p.pTitle), strong: true),
                num(p == null ? '–' : pct(p.pTop4)),
                num(p == null ? '–' : pct(p.pReleg)),
              ],
            ]),
          ),
        ),
      );
    }

    final n = rows.length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clubs'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: LeagueChips(allowAll: false, selected: lg,
              onSelected: (v) => setState(() => league = v)),
        ),
      ),
      body: ListView(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Table'),
                  icon: Icon(Icons.format_list_numbered_rounded)),
              ButtonSegment(value: true, label: Text('Odds'), icon: Icon(Icons.insights_rounded)),
            ],
            selected: {odds},
            onSelectionChanged: (v) => setState(() => odds = v.first),
          ),
        ),
        if (odds && !hasOdds)
          const Padding(padding: EdgeInsets.all(16),
              child: EmptyNote('Odds need the live season. Connect and refresh from Home.'))
        else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(children: [
              const SizedBox(width: 66),
              Expanded(child: Text('Club', style: muted)),
              ...odds ? [head('Title'), head('Top 4'), head('Bottom 3')]
                  : [head('P'), head('GD'), head('Pts')],
            ]),
          ),
          for (final (i, c) in rows.indexed) ...[
            row(c),
            if (i == 3 || i == n - 4) const Divider(thickness: 2) else const Divider(indent: 16),
          ],
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          child: Text(odds ? 'From 10,000 simulations of the rest of the season.'
              : 'Live table. Thick lines mark the top four and the bottom three.',
              style: tt.bodySmall),
        ),
      ]),
    );
  }
}
```

- [ ] **Step 4: Run, expect PASS.**

- [ ] **Step 5: Commit** — `git add app && git commit -m "feat(app): clubs tab with live table and season odds"`

---

### Task 14: Players tab

**Files:**
- Create: `app/lib/screens/players_screen.dart`
- Test: `app/test/players_test.dart`

**Interfaces:**
- Consumes: `searchPlayers`, `PlayerQuery`, `PlayerSort`, `LeagueChips`, `PlayerRow`, `openPlayer`
- Produces: `PlayersScreen`.

- [ ] **Step 1: Failing tests** — `app/test/players_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchline/screens/players_screen.dart';

import 'helpers.dart';

void main() {
  testWidgets('accent-free search finds the player', (tester) async {
    await pumpApp(tester, const PlayersScreen());
    await tester.enterText(find.byType(SearchBar), 'mbappe');
    await tester.pump();
    expect(find.text('Kylian Mbappé'), findsOneWidget);
  });

  testWidgets('position chip filters and no-results offers a reset', (tester) async {
    await pumpApp(tester, const PlayersScreen());
    await tester.tap(find.widgetWithText(ChoiceChip, 'Goalkeepers'));
    await tester.pump();
    await tester.enterText(find.byType(SearchBar), 'zzzzqqq');
    await tester.pump();
    expect(find.textContaining('Nobody matches'), findsOneWidget);
    await tester.tap(find.text('Clear filters'));
    await tester.pump();
    expect(find.textContaining('Nobody matches'), findsNothing);
  });
}
```

- [ ] **Step 2: Run, expect FAIL.**

- [ ] **Step 3: Implement** `app/lib/screens/players_screen.dart`:
```dart
import 'package:flutter/material.dart';

import '../data/bundle.dart';
import '../data/selectors.dart';
import '../format.dart';
import '../state/app_state.dart';
import '../widgets/empty_note.dart';
import '../widgets/league_chips.dart';
import '../widgets/rows.dart';
import 'routes.dart';

const _positions = {'Attack': 'Forwards', 'Midfield': 'Midfielders', 'Defender': 'Defenders',
    'Goalkeeper': 'Goalkeepers'};
const _sorts = {
  PlayerSort.trending: 'Trending',
  PlayerSort.valueGap: 'Biggest bargains',
  PlayerSort.forecast: 'Projected G/A',
  PlayerSort.marketValue: 'Market value',
  PlayerSort.name: 'Name',
};

class PlayersScreen extends StatefulWidget {
  const PlayersScreen({super.key});
  @override
  State<PlayersScreen> createState() => _PlayersScreenState();
}

class _PlayersScreenState extends State<PlayersScreen> {
  final _search = TextEditingController();
  String? pos;
  double? maxAge;
  int? maxPrice;
  PlayerSort sort = PlayerSort.trending;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _clear() => setState(() {
        _search.clear();
        pos = null;
        maxAge = null;
        maxPrice = null;
      });

  Widget _trailing(BuildContext context, Player p) {
    final tt = Theme.of(context).textTheme;
    final text = switch (sort) {
      PlayerSort.valueGap => p.fairValue == null || p.marketValue == null
          ? '–' : signedMoney(p.fairValue! - p.marketValue!),
      PlayerSort.forecast => p.forecastGa5 == null ? '–' : '${p.forecastGa5!.toStringAsFixed(1)} G/A',
      _ => money(p.marketValue),
    };
    return Text(text, style: tt.labelLarge);
  }

  Future<void> _moreFilters(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        builder: (context) => StatefulBuilder(builder: (context, set) {
          final tt = Theme.of(context).textTheme;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Max age ${maxAge?.round() ?? 'any'}', style: tt.titleSmall),
                Slider(min: 17, max: 40, divisions: 23, value: maxAge ?? 40,
                    label: '${(maxAge ?? 40).round()}',
                    onChanged: (v) { set(() {}); setState(() => maxAge = v >= 40 ? null : v); }),
                Text('Max price ${maxPrice == null ? 'any' : money(maxPrice)}', style: tt.titleSmall),
                Slider(min: 1, max: 200, divisions: 199, value: (maxPrice ?? 200000000) / 1e6,
                    label: '€${((maxPrice ?? 200000000) / 1e6).round()}M',
                    onChanged: (v) {
                      set(() {});
                      setState(() => maxPrice = v >= 200 ? null : (v * 1e6).round());
                    }),
              ]),
            ),
          );
        }),
      );

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final b = s.bundle!;
    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final results = searchPlayers(b, PlayerQuery(text: _search.text, league: s.league, pos: pos,
        maxAge: maxAge, maxPrice: maxPrice, sort: sort));
    final extra = (maxAge != null ? 1 : 0) + (maxPrice != null ? 1 : 0);
    return Scaffold(
      appBar: AppBar(title: const Text('Players')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: SearchBar(
            controller: _search,
            hintText: 'Search ${thousands(b.players.length)} players',
            leading: const Icon(Icons.search_rounded),
            elevation: const WidgetStatePropertyAll(0),
            backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainerHigh),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const LeagueChips(),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final MapEntry(key: k, value: label) in _positions.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(label: Text(label), selected: pos == k,
                      onSelected: (on) => setState(() => pos = on ? k : null)),
                ),
              ActionChip(
                avatar: const Icon(Icons.tune_rounded, size: 18),
                label: Text(extra == 0 ? 'Age & price' : 'Age & price · $extra'),
                onPressed: () => _moreFilters(context),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 4, 0),
          child: Row(children: [
            Text('${thousands(results.length)} players', style: tt.labelLarge),
            const Spacer(),
            PopupMenuButton<PlayerSort>(
              initialValue: sort,
              tooltip: 'Sort players',
              onSelected: (v) => setState(() => sort = v),
              itemBuilder: (_) => [
                for (final e in _sorts.entries) PopupMenuItem(value: e.key, child: Text(e.value)),
              ],
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  const Icon(Icons.sort_rounded, size: 18),
                  const SizedBox(width: 6),
                  Text(_sorts[sort]!, style: tt.labelLarge),
                ]),
              ),
            ),
          ]),
        ),
        Expanded(
          child: results.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const EmptyNote('Nobody matches. Loosen a filter.'),
                    TextButton(onPressed: _clear, child: const Text('Clear filters')),
                  ]),
                )
              : ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (context, i) {
                    final p = results[i];
                    return PlayerRow(
                      player: p,
                      subtitle: [p.clubName, p.subPos ?? p.pos].whereType<String>().join(' · '),
                      trailing: _trailing(context, p),
                      onTap: () => openPlayer(context, p.id),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}
```

- [ ] **Step 4: Run, expect PASS.**

- [ ] **Step 5: Commit** — `git add app && git commit -m "feat(app): players tab with folded search, filters and sorting"`

---

### Task 15: Scout tab (budget planner + cheaper lookalikes)

**Files:**
- Create: `app/lib/screens/scout_screen.dart`
- Test: `app/test/scout_test.dart`

**Interfaces:**
- Consumes: `planCandidates`, `planSignings`, `Plan`, `PlanItem` (Task 6); `similarCheaper`, `searchPlayers`; rows; `LeagueChips`
- Produces: `typedef Solver = Future<Plan?> Function(List<PlanItem> items, double budget, Map<String, int> needs)`; `Future<Plan?> isolateSolver(...)` (uses `compute`); `ScoutScreen{solver = isolateSolver}`.

- [ ] **Step 1: Failing tests** — `app/test/scout_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchline/data/planner.dart';
import 'package:touchline/screens/scout_screen.dart';

import 'helpers.dart';

Future<Plan?> syncSolver(List<PlanItem> i, double b, Map<String, int> n) async =>
    planSignings(i, b, n);

void main() {
  testWidgets('default window builds three signings within budget', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 2000));
    await pumpApp(tester, const ScoutScreen(solver: syncSolver));
    await tester.tap(find.text('Build my window'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Your window'), findsOneWidget);
    expect(find.textContaining('Spend'), findsOneWidget);
  });

  testWidgets('no positions asks for one; infeasible explains why', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 2000));
    await pumpApp(tester, ScoutScreen(solver: (i, b, n) async => null));
    await tester.tap(find.text('Build my window'));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('Nothing fits'), findsOneWidget);
    for (final t in ['One fewer forwards', 'One fewer midfielders', 'One fewer defenders']) {
      await tester.tap(find.byTooltip(t));
      await tester.pump();
    }
    await tester.tap(find.text('Build my window'));
    await tester.pump();
    expect(find.text('Pick at least one position.'), findsOneWidget);
  });

  testWidgets('cheaper lookalikes for a searched player', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 2400));
    final star = fixtureBundle().players
        .where((p) => p.qualified && (p.marketValue ?? 0) > 60000000).first;
    await pumpApp(tester, const ScoutScreen(solver: syncSolver));
    await tester.enterText(find.widgetWithText(TextField, 'Start with a player you like'),
        star.name);
    await tester.pump();
    await tester.tap(find.text(star.name).last);
    await tester.pump();
    expect(find.textContaining('Plays like ${star.name}'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run, expect FAIL.**

- [ ] **Step 3: Implement** `app/lib/screens/scout_screen.dart`:
```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/bundle.dart';
import '../data/planner.dart';
import '../data/selectors.dart';
import '../format.dart';
import '../state/app_state.dart';
import '../widgets/empty_note.dart';
import '../widgets/league_chips.dart';
import '../widgets/rows.dart';
import '../widgets/section.dart';
import 'routes.dart';

typedef Solver = Future<Plan?> Function(
    List<PlanItem> items, double budget, Map<String, int> needs);

Plan? _solve((List<PlanItem>, double, Map<String, int>) a) => planSignings(a.$1, a.$2, a.$3);

Future<Plan?> isolateSolver(List<PlanItem> items, double budget, Map<String, int> needs) =>
    compute(_solve, (items, budget, needs));

const _labels = {'Attack': 'forwards', 'Midfield': 'midfielders', 'Defender': 'defenders',
    'Goalkeeper': 'goalkeepers'};

class ScoutScreen extends StatefulWidget {
  const ScoutScreen({super.key, this.solver = isolateSolver});
  final Solver solver;
  @override
  State<ScoutScreen> createState() => _ScoutScreenState();
}

class _ScoutScreenState extends State<ScoutScreen> {
  double budget = 100;
  final needs = {'Attack': 1, 'Midfield': 1, 'Defender': 1, 'Goalkeeper': 0};
  double maxAge = 30;
  String? league;
  Plan? plan;
  String? message;
  bool busy = false;
  String find = '';
  int? target;

  Future<void> _build(Bundle b) async {
    if (needs.values.every((v) => v == 0)) {
      setState(() {
        plan = null;
        message = 'Pick at least one position.';
      });
      return;
    }
    setState(() => busy = true);
    final items = planCandidates(b, league: league, maxAge: maxAge);
    final result = await widget.solver(items, budget, Map.of(needs));
    if (!mounted) return;
    setState(() {
      busy = false;
      plan = result;
      message = result == null
          ? 'Nothing fits €${budget.round()}M with those positions. '
              'Raise the budget or drop a position.'
          : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final b = AppScope.of(context).bundle!;
    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final muted = tt.bodyMedium!.copyWith(color: scheme.onSurfaceVariant);
    final matches = find.trim().isEmpty
        ? const <Player>[]
        : searchPlayers(b, PlayerQuery(text: find)).where((p) => p.qualified).take(5).toList();
    final t = target == null ? null : b.playerById[target];
    final p = plan;
    return Scaffold(
      appBar: AppBar(title: const Text('Scout')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text('Build my window', style: tt.titleLarge),
          Text('The most player for your money, judged on ${b.playerSeason} numbers.',
              style: muted),
          const SizedBox(height: 16),
          Text('Budget €${budget.round()}M', style: tt.titleMedium),
          Slider(min: 10, max: 300, divisions: 58, value: budget, label: '€${budget.round()}M',
              onChanged: (v) => setState(() => budget = v)),
          for (final MapEntry(key: pos, value: label) in _labels.entries)
            Row(children: [
              Expanded(child: Text(label[0].toUpperCase() + label.substring(1),
                  style: tt.bodyLarge)),
              IconButton(
                tooltip: 'One fewer $label',
                icon: const Icon(Icons.remove_circle_outline_rounded),
                onPressed: needs[pos]! > 0 ? () => setState(() => needs[pos] = needs[pos]! - 1)
                    : null,
              ),
              SizedBox(width: 24, child: Text('${needs[pos]}', textAlign: TextAlign.center,
                  style: tt.titleMedium)),
              IconButton(
                tooltip: 'One more $label',
                icon: const Icon(Icons.add_circle_outline_rounded),
                onPressed: needs[pos]! < 3 ? () => setState(() => needs[pos] = needs[pos]! + 1)
                    : null,
              ),
            ]),
          const SizedBox(height: 8),
          Text('Max age ${maxAge.round()}', style: tt.titleMedium),
          Slider(min: 18, max: 36, divisions: 18, value: maxAge, label: '${maxAge.round()}',
              onChanged: (v) => setState(() => maxAge = v)),
          Transform.translate(
            offset: const Offset(-16, 0),
            child: SizedBox(width: MediaQuery.sizeOf(context).width,
                child: LeagueChips(selected: league,
                    onSelected: (v) => setState(() => league = v))),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: busy ? null : () => _build(b),
            icon: const Icon(Icons.playlist_add_check_rounded),
            label: const Text('Build my window'),
          ),
          if (busy) const Padding(padding: EdgeInsets.only(top: 12),
              child: LinearProgressIndicator()),
          if (message != null) EmptyNote(message!),
          if (p != null) ...[
            const SectionHeading('Your window', padded: false),
            Text('Spend ${money((p.cost * 1e6).round())} of €${budget.round()}M · '
                'fair value ${money((p.score * 1e6).round())}', style: tt.titleMedium),
            for (final id in p.ids)
              if (b.playerById[id] case final pl?)
                PlayerRow(
                  player: pl,
                  subtitle: [pl.clubName, pl.subPos ?? pl.pos].whereType<String>().join(' · '),
                  trailing: Column(mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(money(pl.marketValue), style: tt.labelLarge),
                    Text('worth ${money(pl.fairValue)}', style: tt.labelSmall!
                        .copyWith(color: scheme.primary)),
                  ]),
                  onTap: () => openPlayer(context, pl.id),
                ),
          ],
          const SectionHeading('Find a cheaper version', padded: false),
          TextField(
            decoration: const InputDecoration(
                hintText: 'Start with a player you like',
                prefixIcon: Icon(Icons.search_rounded), border: OutlineInputBorder()),
            onChanged: (v) => setState(() => find = v),
          ),
          for (final m in matches)
            PlayerRow(player: m, onTap: () => setState(() {
                  target = m.id;
                  find = '';
                })),
          if (t != null) ...[
            const SizedBox(height: 12),
            Text('Plays like ${t.name}, costs less:', style: tt.titleMedium),
            ...switch (similarCheaper(b, t)) {
              final list when list.isEmpty =>
                  [const EmptyNote('No cheaper lookalikes in the data.')],
              final list => [
                  for (final c in list)
                    PlayerRow(player: c,
                        trailing: Text(money(c.marketValue), style: tt.labelLarge),
                        onTap: () => openPlayer(context, c.id)),
                ],
            },
          ],
          const SectionHeading('Ask the Scout', padded: false),
          Text('Coming later: ask in plain words, like "a left-back under €15M".',
              style: muted),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run, expect PASS** — `/c/flutter/bin/flutter test && /c/flutter/bin/flutter analyze`.

- [ ] **Step 5: Commit** — `git add app && git commit -m "feat(app): scout tab with on-device budget planner and cheaper lookalikes"`

---

### Task 16: About sheet, shell, entry point

**Files:**
- Modify: `app/lib/screens/about_sheet.dart` (full body)
- Create: `app/lib/app.dart`; Replace: `app/lib/main.dart`
- Test: `app/test/shell_test.dart`

**Interfaces:**
- Consumes: all screens; `AppState`, `platformBundleIo`, `DevicePrefs`
- Produces: `TouchlineApp{state}`, `Shell`; `main()`.

- [ ] **Step 1: Failing tests** — `app/test/shell_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchline/app.dart';
import 'package:touchline/screens/about_sheet.dart';
import 'package:touchline/state/app_state.dart';

import 'helpers.dart';

void main() {
  testWidgets('bottom navigation switches tabs; Back returns Home first', (tester) async {
    final s = AppState.preloaded(fixtureBundle(), clock: () => fixtureNow);
    await tester.pumpWidget(TouchlineApp(state: s));
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.byType(NavigationBar), findsOneWidget);
    await tester.tap(find.text('Clubs').last);
    await tester.pump();
    expect(find.widgetWithText(AppBar, 'Clubs'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('TOUCHLINE'), findsOneWidget);
  });

  testWidgets('wide screens use a navigation rail', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    final s = AppState.preloaded(fixtureBundle(), clock: () => fixtureNow);
    await tester.pumpWidget(TouchlineApp(state: s));
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('about sheet states the honest numbers and switches theme', (tester) async {
    final s = await pumpApp(tester, const Scaffold(body: AboutSheet()));
    expect(find.text('How this works'), findsOneWidget);
    expect(find.text('Who wins'), findsOneWidget);
    expect(find.textContaining('Not an injury prediction'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Dark'), 200);
    await tester.tap(find.text('Dark'));
    await tester.pump();
    expect(s.themeMode, ThemeMode.dark);
  });
}
```

- [ ] **Step 2: Run, expect FAIL.**

- [ ] **Step 3: Implement**

`app/lib/screens/about_sheet.dart`:
```dart
import 'package:flutter/material.dart';

import '../format.dart';
import '../state/app_state.dart';
import '../widgets/section.dart';

Future<void> showAboutSheet(BuildContext context) => showModalBottomSheet<void>(
    context: context, isScrollControlled: true, builder: (_) => const AboutSheet());

class AboutSheet extends StatelessWidget {
  const AboutSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final b = s.bundle!;
    final tt = Theme.of(context).textTheme;
    final muted = tt.bodySmall!.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    num? at(String model, String key) => (b.models[model] as Map?)?[key] as num?;
    String f(num? v, int d) => v == null ? '–' : v.toStringAsFixed(d);
    final lines = <(String, String)>[
      if (at('club_elo', 'favourite_accuracy') case final acc?)
        ('Who wins', 'Picks the winner in ${pct(acc.toDouble())} of games that had one. '
            'Backing the home team every time gets '
            '${pct((at('club_elo', 'baseline_home_pick_accuracy') ?? 0).toDouble())}.'),
      if (at('match_model', 'rps') case final r?)
        ('Match odds', 'Probability score ${f(r, 3)} against '
            '${f(at('match_model', 'baseline_rps'), 3)} for a base-rate guess. Lower is better.'),
      if (at('valuator', 'mae_eur') case final e?)
        ('Fair value', 'Typically within ${money(e.round())} of the market. A simple '
            'age-and-position rule misses by ${money(at('valuator', 'baseline_mae_eur')?.round())}.'),
      if (at('form', 'gru_mae') case final g?)
        ('Next five games', "A neural network reads each player's last ten games. Average miss "
            '${f(g, 2)} goal involvements; a classic stats model ${f(at('form', 'glm_mae'), 2)}; '
            'recent averages ${f(at('form', 'naive_mae'), 2)}.'),
      ('Workload', 'A risk index from minutes, games on short rest and sudden load spikes. '
          'Not an injury prediction: the data has no injury records.'),
    ];
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          Text('How this works', style: tt.titleLarge),
          const SizedBox(height: 6),
          Text('Every number comes from a model tested on a season it never saw, and checked '
              'against a simple rule of thumb. Results below are from ${b.playerSeason}.',
              style: tt.bodyMedium),
          for (final (title, body) in lines)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: tt.titleSmall),
                const SizedBox(height: 2),
                Text(body, style: tt.bodyMedium),
              ]),
            ),
          const SectionHeading('Data', padded: false),
          Text('Clubs, tables and fixtures update weekly; this copy is from '
              '${shortDate(DateTime.parse(b.clubsThrough))}. Player stats are '
              '${b.playerSeason}, the latest complete season in the open dataset.',
              style: tt.bodyMedium),
          const SizedBox(height: 6),
          Text('Sources: Transfermarkt open dataset (CC0) and football-data.org. Market values '
              'are crowd estimates, not transfer fees. Not affiliated with any club or league.',
              style: muted),
          const SectionHeading('Appearance', padded: false),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.system, label: Text('System')),
              ButtonSegment(value: ThemeMode.light, label: Text('Light')),
              ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
            ],
            selected: {s.themeMode},
            onSelectionChanged: (v) => s.setThemeMode(v.first),
          ),
          const SizedBox(height: 24),
          Text('Lettering: Jersey by Sarah Cadigan-Fried, SIL Open Font License.', style: muted),
        ],
      ),
    );
  }
}
```

`app/lib/app.dart`:
```dart
import 'package:flutter/material.dart';

import 'screens/clubs_screen.dart';
import 'screens/home_screen.dart';
import 'screens/players_screen.dart';
import 'screens/scout_screen.dart';
import 'state/app_state.dart';
import 'theme/theme.dart';
import 'widgets/empty_note.dart';

class TouchlineApp extends StatelessWidget {
  const TouchlineApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) => AppScope(
        state: state,
        child: Builder(
          builder: (context) => MaterialApp(
            title: 'Touchline',
            debugShowCheckedModeBanner: false,
            theme: buildTheme(Brightness.light),
            darkTheme: buildTheme(Brightness.dark),
            themeMode: AppScope.of(context).themeMode,
            home: const Shell(),
          ),
        ),
      );
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int index = 0;

  static const _dest = [
    (Icons.stadium_outlined, Icons.stadium_rounded, 'Home'),
    (Icons.shield_outlined, Icons.shield_rounded, 'Clubs'),
    (Icons.person_search_outlined, Icons.person_search_rounded, 'Players'),
    (Icons.travel_explore_outlined, Icons.travel_explore_rounded, 'Scout'),
  ];

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    if (s.bundle == null) {
      return Scaffold(
        body: Center(
          child: s.loadError == null
              ? const CircularProgressIndicator()
              : const Padding(padding: EdgeInsets.all(24),
                  child: EmptyNote('The match data could not be opened. '
                      'Reinstall the app to restore it.')),
        ),
      );
    }
    final body = IndexedStack(index: index, children: const [
      HomeScreen(), ClubsScreen(), PlayersScreen(), ScoutScreen(),
    ]);
    final wide = MediaQuery.sizeOf(context).width >= 840;
    return PopScope(
      canPop: index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => index = 0);
      },
      child: wide
          ? Scaffold(
              body: Row(children: [
                NavigationRail(
                  selectedIndex: index,
                  onDestinationSelected: (i) => setState(() => index = i),
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    for (final (o, f, l) in _dest)
                      NavigationRailDestination(icon: Icon(o), selectedIcon: Icon(f),
                          label: Text(l)),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ]),
            )
          : Scaffold(
              body: body,
              bottomNavigationBar: NavigationBar(
                selectedIndex: index,
                onDestinationSelected: (i) => setState(() => index = i),
                destinations: [
                  for (final (o, f, l) in _dest)
                    NavigationDestination(icon: Icon(o), selectedIcon: Icon(f), label: l),
                ],
              ),
            ),
    );
  }
}
```

`app/lib/main.dart`:
```dart
import 'package:flutter/material.dart';

import 'app.dart';
import 'data/platform_io.dart';
import 'data/prefs.dart';
import 'state/app_state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState(io: platformBundleIo(), prefs: DevicePrefs())..start();
  runApp(TouchlineApp(state: state));
}
```

- [ ] **Step 4: Run, expect PASS** — `/c/flutter/bin/flutter test && /c/flutter/bin/flutter analyze`; then a web smoke run: `/c/flutter/bin/flutter build web --release` succeeds.

- [ ] **Step 5: Commit** — `git add app && git commit -m "feat(app): shell with adaptive navigation, about sheet, entry point"`

---

### Task 17: Android and web packaging

**Files:**
- Create: `app/tool/make_icons.py`, `app/android/key.properties` (git-ignored), `app/android/app/upload-keystore.jks` (git-ignored)
- Modify: `app/android/app/build.gradle.kts`, `app/android/app/src/main/AndroidManifest.xml`, `app/web/index.html`, `app/web/manifest.json`; generated icons under `app/android/app/src/main/res/mipmap-*/ic_launcher.png` and `app/web/{favicon.png,icons/*.png}`

**Interfaces:**
- Produces: `app/build/app/outputs/flutter-apk/app-release.apk` (application id `com.aryan.touchline`, label "Touchline"); `app/build/web/`.

- [ ] **Step 1: Icon generator** — `app/tool/make_icons.py` (pixel-stitch "T" between scarf stripes, drawn on a 16×16 stitch grid and scaled with nearest-neighbour, so every size stays crisp):
```python
"""Draw Touchline's launcher and web icons from a 16x16 stitch grid (run from app/)."""
from pathlib import Path

from PIL import Image

PITCH, PINK = (15, 61, 46, 255), (242, 167, 195, 255)
STRIPE = "PPGGPPGGPPGGPPGG"
GRID = [STRIPE, STRIPE, "G" * 16,
        "GGPPPPPPPPPPPPGG", "GGPPPPPPPPPPPPGG"] + ["GGGGGGGPPGGGGGGG"] * 8 + [
        "G" * 16, STRIPE, STRIPE]


def stitch(size: int, inset: float = 0.0) -> Image.Image:
    cell = 16
    img = Image.new("RGBA", (cell, cell), PITCH)
    for y, row in enumerate(GRID):
        for x, ch in enumerate(row):
            img.putpixel((x, y), PINK if ch == "P" else PITCH)
    if inset:
        inner = round(size * (1 - 2 * inset))
        canvas = Image.new("RGBA", (size, size), PITCH)
        canvas.paste(img.resize((inner, inner), Image.NEAREST), ((size - inner) // 2,) * 2)
        return canvas
    return img.resize((size, size), Image.NEAREST)


def main() -> None:
    res = Path("android/app/src/main/res")
    for folder, px in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
        stitch(px).save(res / f"mipmap-{folder}" / "ic_launcher.png")
    web = Path("web")
    stitch(64).save(web / "favicon.png")
    stitch(192).save(web / "icons" / "Icon-192.png")
    stitch(512).save(web / "icons" / "Icon-512.png")
    stitch(192, inset=0.1).save(web / "icons" / "Icon-maskable-192.png")
    stitch(512, inset=0.1).save(web / "icons" / "Icon-maskable-512.png")


if __name__ == "__main__":
    main()
```
Run: `cd app && ../pipeline/.venv/Scripts/python -m pip install -q pillow && ../pipeline/.venv/Scripts/python tool/make_icons.py`. Open `web/icons/Icon-512.png` and check it reads as a pink "T" between pink/green stripes.

- [ ] **Step 2: Android manifest** — in `app/android/app/src/main/AndroidManifest.xml` set `android:label="Touchline"` and add, as the first child of `<manifest>`:
```xml
    <uses-permission android:name="android.permission.INTERNET"/>
```

- [ ] **Step 3: Release signing** — generate a local upload key (never committed; root `.gitignore` already ignores `*.jks` and `key.properties`):
```bash
cd /c/Users/91750/touchline/app/android
PW=$(../../pipeline/.venv/Scripts/python -c "import secrets;print(secrets.token_urlsafe(24))")
"/c/Program Files/Android/Android Studio/jbr/bin/keytool" -genkeypair -v -keystore app/upload-keystore.jks -storepass "$PW" -keypass "$PW" -alias touchline -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Touchline"
printf 'storePassword=%s\nkeyPassword=%s\nkeyAlias=touchline\nstoreFile=upload-keystore.jks\n' "$PW" "$PW" > key.properties
git -C /c/Users/91750/touchline status --short | grep -E "jks|key.properties" && echo "LEAK" || echo "ignored ok"
```
If `keytool` is not at that path, locate it with `ls "/c/Program Files/Android/Android Studio/jbr/bin/"` or use `$JAVA_HOME/bin/keytool`.

In `app/android/app/build.gradle.kts` add at the top:
```kotlin
import java.io.FileInputStream
import java.util.Properties

val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) load(FileInputStream(f))
}
```
inside `android { ... }` add:
```kotlin
    signingConfigs {
        create("release") {
            if (keystoreProperties.isNotEmpty()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }
```
and in `buildTypes { release { ... } }` replace the signing line with:
```kotlin
            signingConfig = if (keystoreProperties.isNotEmpty())
                signingConfigs.getByName("release") else signingConfigs.getByName("debug")
```

- [ ] **Step 4: Web metadata** — in `app/web/index.html` set `<title>Touchline</title>`, the description meta to `Football, read in seconds: match odds, fair values and form from tested models.`, `apple-mobile-web-app-title` to `Touchline`, and add `<meta name="theme-color" content="#0F3D2E">`. In `app/web/manifest.json` set `"name": "Touchline"`, `"short_name": "Touchline"`, `"description"` (same sentence), `"background_color": "#EDEDE8"`, `"theme_color": "#0F3D2E"`.

- [ ] **Step 5: Build both targets**
```bash
cd /c/Users/91750/touchline/app
/c/flutter/bin/flutter build apk --release
/c/flutter/bin/flutter build web --release
ls -la build/app/outputs/flutter-apk/app-release.apk build/web/index.html
```
Expected: both exist; APK under ~30 MB. (`BUNDLE_URL` is added at build time once the GitHub repo exists; without it the APK runs on its seed data and never calls the network: say so in the README.)

- [ ] **Step 6: Commit** — `git add app && git commit -m "build(app): launcher/web icons, release signing config, web metadata"` (verify no keystore or key.properties is staged).

---

### Task 18: CI, GitHub Pages demo, root README

**Files:**
- Modify: `.github/workflows/ci.yml` (add `app` job)
- Create: `.github/workflows/pages.yml`, `README.md` (root)

**Interfaces:**
- Consumes: Task 17 builds; the `data-latest` release from Plan 1's refresh workflow.

- [ ] **Step 1: CI job** — append to `.github/workflows/ci.yml` under `jobs:`:
```yaml
  app:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: app
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: 3.44.8
          channel: stable
          cache: true
      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test
```

- [ ] **Step 2: Pages workflow** — `.github/workflows/pages.yml`:
```yaml
name: pages
on:
  push:
    branches: [main]
  workflow_run:
    workflows: [refresh-data]
    types: [completed]
  workflow_dispatch:
permissions:
  contents: read
  pages: write
  id-token: write
concurrency:
  group: pages
  cancel-in-progress: true
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: 3.44.8
          channel: stable
          cache: true
      - name: Build web demo
        working-directory: app
        run: flutter build web --release --base-href "/${{ github.event.repository.name }}/"
      - name: Put the latest data beside the app
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          mkdir -p app/build/web/data
          gh release download data-latest -p touchline-bundle.json.gz -D app/build/web/data \
            || cp app/assets/data/touchline-bundle.json.gz app/build/web/data/
      - uses: actions/upload-pages-artifact@v3
        with:
          path: app/build/web
  deploy:
    needs: build
    runs-on: ubuntu-latest
    environment:
      name: github-pages
      url: ${{ steps.deploy.outputs.page_url }}
    steps:
      - id: deploy
        uses: actions/deploy-pages@v4
```

- [ ] **Step 3: Root README** — `README.md` with these sections, using only real numbers from `pipeline/data/out/metrics.json` and no invented users, downloads or endorsements:
  1. `# Touchline` + one line: "Football, read in seconds: match odds, fair values and form, from models tested on a season they never saw."
  2. Screenshots row (`docs/screenshots/home.png`, `club.png`, `player.png`, `scout.png`: added in Task 19).
  3. **What it does**: the four tabs in one bullet each.
  4. **How it works**: a mermaid diagram:
     ```mermaid
     flowchart LR
       TM[Transfermarkt open data] --> P[pipeline/ · Python]
       FD[football-data.org] --> P
       P -->|8 models + baseline gate| B[(touchline-bundle.json.gz)]
       B -->|GitHub Release, weekly| A[app/ · Flutter APK]
       B -->|beside the web build| W[GitHub Pages demo]
     ```
  5. **Results**: the M1–M5 table copied from `pipeline/README.md` (held-out 2025/26), plus the honest M5 note.
  6. **Run it**: pipeline quick start (link to `pipeline/README.md`); app: `cd app && flutter run`; release build `flutter build apk --release --dart-define=BUNDLE_URL=https://github.com/<you>/<repo>/releases/download/data-latest/touchline-bundle.json.gz`; web demo goes live after enabling Pages (Settings → Pages → GitHub Actions) and adding the `FOOTBALL_API_KEY` secret.
  7. **Design**: the terrace-scarf idea in two sentences, link to `DESIGN.md`.
  8. **Data, licences, limits**: CC0 Transfermarkt, football-data.org terms, Jersey (OFL), MIT code; player stats lag to the latest complete season; workload is not injury prediction; market values are crowd estimates; not affiliated with any club or league.

- [ ] **Step 4: Verify** — `cd app && /c/flutter/bin/flutter analyze && /c/flutter/bin/flutter test` (all green), and check the YAML parses: `../pipeline/.venv/Scripts/python -c "import yaml,sys;[yaml.safe_load(open(f)) for f in sys.argv[1:]]" ../.github/workflows/ci.yml ../.github/workflows/pages.yml` (install `pyyaml` into the venv if missing).

- [ ] **Step 5: Commit** — `git add .github README.md && git commit -m "ci: flutter checks, GitHub Pages web demo; root README"`

---

### Task 19: Verify on device, finish review, DESIGN.md

This task follows impeccable `reference/new-work.md` §7 and `reference/android.md` "Verifying the build". Two inspection rounds at most.

- [ ] **Step 1: Emulator up and app installed**
```bash
"$LOCALAPPDATA/Android/sdk/emulator/emulator" -avd Medium_Phone_API_36.1 -no-snapshot-save &   # run in background
ADB="$LOCALAPPDATA/Android/sdk/platform-tools/adb"
"$ADB" wait-for-device; until [ "$("$ADB" shell getprop sys.boot_completed | tr -d '\r')" = "1" ]; do sleep 3; done
"$ADB" install -r /c/Users/91750/touchline/app/build/app/outputs/flutter-apk/app-release.apk
"$ADB" shell monkey -p com.aryan.touchline -c android.intent.category.LAUNCHER 1
```
(Foreground `sleep` is blocked in this harness: run the boot wait with `run_in_background` or as a Monitor until-loop.)

- [ ] **Step 2: Capture round 1** into `.impeccable/review/` (create it): `phone.png` (Home top), `phone-home-scrolled.png`, `phone-club.png`, `phone-player.png`, `phone-clubs-odds.png`, `phone-scout.png`. Use `"$ADB" exec-out screencap -p > <file>`. Navigate with `"$ADB" shell input tap X Y` / `input swipe`, reading coordinates off the previous capture. Then dark (`"$ADB" shell cmd uimode night yes` → `phone-dark.png`, then `no`) and font scale (`"$ADB" shell settings put system font_scale 1.3` → `phone-fontscale.png`, then restore `1.0`). Web: add `.claude/launch.json` entry `{"name":"web-demo","runtimeExecutable":"pipeline/.venv/Scripts/python","runtimeArgs":["-m","http.server","8765","-d","app/build/web"],"port":8765}`, copy the bundle to `app/build/web/data/`, `preview_start` it, and capture `web-desktop.png` at 1280×800 and `web-mobile.png` at 390×844. Open every file once and confirm it shows what its name claims.

- [ ] **Step 3: Self-critique against the direction contract** (`.impeccable/surfaces/app-lib-main-dart.md`): first viewport composition, scarf legibility (labels readable on club colours, white bands visible on the light ground), contrast, overflow at font scale 1.3, dark-mode finish. Fix material gaps in one batch, rerun `flutter test`, rebuild the APK, recapture the same files (round 2). Then stop polishing.

- [ ] **Step 4: Finish reviewer** — spawn `impeccable-finish-reviewer` fresh (no forked history) with: the original request (CV fan app, impeccable redesign, dashboard-first), confirmed answers (casual fan quick check; Android + web demo; sharp pundit voice; Terrace Scarf direction, code-led), artifact path `app/`, screenshot paths from Step 2 (all required), the direction contract path, `C:\Users\91750\.claude\skills\impeccable\reference\craft-floor.md`, `reference/android.md`, the QUALITY BAR: none (code-led, no comp), and the line "Native Flutter platform: no detector ran; judge in Material 3 / Android conventions." Act on the disposition (recapture / rebuild / fix / ship) exactly as new-work.md §7 prescribes; at most two fix rounds.

- [ ] **Step 5: Documenter** — spawn `impeccable-documenter` with the project root, artifact path `app/lib/`, the direction contract, `PRODUCT.md`, `reference/document.md`, and write boundary `DESIGN.md` + `.impeccable/design.json` only. Verify both files exist and carry tokens (colours, type roles at 56 / 37.333 / 18.667, spacing, scarf components).

- [ ] **Step 6: Raster provenance** — `C:/Users/91750/.claude/skills/impeccable/scripts/impeccable embed-prompt --scan app/android/app/src/main/res app/web` and embed the origin ("generated by app/tool/make_icons.py from a 16x16 stitch grid") for each file it lists.

- [ ] **Step 7: Screenshots for the README** — copy the final `phone.png`, `phone-club.png`, `phone-player.png`, `phone-scout.png` to `docs/screenshots/{home,club,player,scout}.png`.

- [ ] **Step 8: Commit** — `git add DESIGN.md .impeccable/design.json .impeccable/surfaces docs/screenshots app && git commit -m "docs: DESIGN.md from the built scarf world; screenshots; finish-review fixes"`. Then run the final whole-branch code review and the finishing-a-development-branch flow.
