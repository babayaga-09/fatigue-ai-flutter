# Plan 4 — Touchline v2 app: The Matchday Programme

*Spec: `docs/superpowers/specs/2026-10-12-touchline-v2-design.md` §3. Direction contract:
`.impeccable/surfaces/app-lib-main-dart.md` (seed 37b0e2b4, code-led: no image generation on this
machine). Plan 3's honest results change the presentation of F1–F3 (see "Honesty rules").*

Task-level plan: each task is test-first (`flutter test`), committed on `feat/v2-app`, and
recorded in the ledger. Code lives in the commits, not duplicated here.

## Honesty rules (from Plan 3 results)

- **Big Five (F1):** the LightGBM model lost to price (pooled AUC 0.563 vs 0.599), so the list is
  ranked by the price-only model. The page says so in one line and shows translated G/A per 90
  (measured conversion factors) as the hero number. `why` is empty — no fake drivers.
- **Managers (F2):** split-half reliability −0.21 → every manager figure is labelled "mostly luck".
  No "best managers" ranking on Home; Home carries the sacking-bounce finding instead.
- **Dependency (F3):** stability −0.03 → a descriptive "with him / without him" line on player and
  club pages (team sheet sorted by games missed context), never a Home ranking.
- **Career (F4):** shipped; fan chart with the 80% band, "ahead / on / behind the usual curve".

## Tasks

1. **Bundle v2 keys.** Parse `prospects[]`, `managers[]`, `players[].dependency`,
   `players[].career`, and `models.{prospects,manager_effect,dependency,career}` (all optional —
   old bundles still load). Copy the new seed bundle to `assets/data/`. Tests: parse, nulls,
   old-bundle compatibility.
2. **Programme tokens and type.** Archivo variable font (OFL, from google/fonts) replaces Jersey:
   masthead role = narrowest width, weight 900, uppercase; text roles = normal width. Palette:
   stock white / ink, turnstile red, royal blue, strip yellow; black-cover dark theme. Square
   corners, hairline rules, no card shadows. Tests: theme roles, contrast of on-colours.
3. **Halftone portrait (signature).** Pure `halftone()` (RGBA → dot radii on a grid, unit-tested),
   `HalftonePortrait` widget: decodes the photo once, caches dots per url, paints dots in the club
   primary on the club secondary; develops in (dots grow, 500 ms ease-out-expo; instant under
   reduced motion). Fallbacks: duotone colour filter when pixels can't be read (web CORS), initials
   when there's no photo. `PlayerAvatar` keeps its API and uses it.
4. **Printed pieces.** Three-part W/D/L strip with figures set in each band (replaces the scarf),
   form squares with W/D/L letters, programme section heading (masthead caps + rule), numbered
   team-sheet row. Delete `scarf.dart` and the knit painter.
5. **Home.** Cover (two halves in club colours, each club's most valuable player as a halftone,
   names in masthead caps, kickoff, printed strip, verdict); inside pages: your players, running
   hot, Big Five top 5, the sacking-bounce finding, this week, clubs in form, power rankings,
   bargains, overworked watch.
6. **Clubs.** Managers view (luck-adjusted, labelled) beside table/odds; club page gains the manager
   card and the with/without team sheet; accent from the club in focus.
7. **Player page.** Career fan chart (p10–p90 band, p50 line, value history before it), peak
   and "vs usual curve" line; dependency line; halftone header in club colours.
8. **Scouting tab.** Rename; Big Five list with league/position filters and the honest note;
   budget planner and lookalikes restyled.
9. **Restyle the rest.** Players list, compare, match sheet, about sheet (v2 model notes with the
   failures stated), empty notes, chips, navigation.
10. **Verify and finish.** Emulator (cold boot, swiftshader) light/dark/font-scale 1.3, web build
    via `touchline-web`; impeccable finish reviewer → fix round → documenter replaces DESIGN.md
    and `.impeccable/design.json`; PRODUCT.md capabilities updated; final code review; merge.
