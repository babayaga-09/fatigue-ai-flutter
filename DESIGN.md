---
name: Touchline
description: Football predictions knitted into terrace scarves; plain verdicts for a two-minute glance.
colors:
  pitch: "#0F3D2E"
  paper-pink: "#F2A7C3"
  terrace-concrete: "#EDEDE8"
  night-ground: "#0D1311"
  ink: "#16181D"
  win: "#1E7A46"
  draw: "#7D838C"
  loss: "#C8102E"
  neutral-club-a: "#5C6670"
  neutral-club-b: "#D9DCE0"
  primary: "#0F3D2E"
  on-primary: "#FFFFFF"
  primary-container: "#CDE9D9"
  on-primary-container: "#0F3D2E"
  tertiary: "#8E3B5E"
  on-tertiary: "#FFFFFF"
  tertiary-container: "#F2A7C3"
  on-tertiary-container: "#16181D"
  surface: "#EDEDE8"
  on-surface: "#16181D"
  on-surface-variant: "#4A4F57"
  surface-container-lowest: "#FAFAF7"
  surface-container-low: "#F6F6F2"
  surface-container: "#E6E6E0"
  surface-container-high: "#DEDED8"
  surface-container-highest: "#D6D6D0"
  outline: "#767C85"
  outline-variant: "#C9CBC6"
  primary-dark: "#8FD6AE"
  on-primary-dark: "#003920"
  primary-container-dark: "#1C4A39"
  on-primary-container-dark: "#CDE9D9"
  tertiary-dark: "#F2A7C3"
  on-tertiary-dark: "#16181D"
  surface-dark: "#0D1311"
  on-surface-dark: "#E6E8E3"
  on-surface-variant-dark: "#A9B1AC"
  surface-container-lowest-dark: "#0A0F0D"
  surface-container-low-dark: "#141B18"
  surface-container-dark: "#18201C"
  surface-container-high-dark: "#1F2824"
  surface-container-highest-dark: "#27312C"
  outline-dark: "#8A918C"
  outline-variant-dark: "#2E3833"
typography:
  display-large:
    fontFamily: "Jersey 10"
    fontSize: "56px"
    fontWeight: 400
    lineHeight: 1
    letterSpacing: "0"
    fontFeature: "tnum"
  display-small:
    fontFamily: "Jersey 10"
    fontSize: "37.333px"
    fontWeight: 400
    lineHeight: 1
    letterSpacing: "0"
    fontFeature: "tnum"
  headline-small:
    fontFamily: "Jersey 10"
    fontSize: "18.667px"
    fontWeight: 400
    lineHeight: 1
    letterSpacing: "0"
    fontFeature: "tnum"
  title-large:
    fontFamily: "Roboto, sans-serif"
    fontSize: "22px"
    fontWeight: 700
    lineHeight: "28px"
    letterSpacing: "-0.2px"
  title-medium:
    fontFamily: "Roboto, sans-serif"
    fontSize: "16px"
    fontWeight: 600
    lineHeight: "24px"
  body-medium:
    fontFamily: "Roboto, sans-serif"
    fontSize: "14px"
    fontWeight: 400
    lineHeight: 1.4
  label-large:
    fontFamily: "Roboto, sans-serif"
    fontSize: "14px"
    fontWeight: 500
    lineHeight: "20px"
    fontFeature: "tnum"
  label-medium:
    fontFamily: "Roboto, sans-serif"
    fontSize: "12px"
    fontWeight: 500
    lineHeight: "16px"
    fontFeature: "tnum"
rounded:
  scarf: "3px"
  bar: "2px"
  portrait: "10px"
  card: "16px"
spacing:
  gutter: "16px"
  section-above: "28px"
  section-below: "8px"
  row-min-height: "64px"
  tile-padding: "12px"
components:
  card:
    backgroundColor: "{colors.surface-container-low}"
    rounded: "{rounded.card}"
    padding: "16px"
  player-tile:
    backgroundColor: "{colors.surface-container-low}"
    rounded: "{rounded.card}"
    padding: "12px"
    width: "156px"
  fixture-scarf-hero:
    typography: "{typography.display-large}"
    rounded: "{rounded.scarf}"
    height: "72px"
  fixture-scarf-row:
    typography: "{typography.headline-small}"
    rounded: "{rounded.scarf}"
    height: "24px"
  club-scarf:
    typography: "{typography.display-small}"
    rounded: "{rounded.scarf}"
    height: "72px"
  brand-band:
    rounded: "{rounded.scarf}"
    height: "8px"
  nav-bar:
    backgroundColor: "{colors.surface-container}"
    textColor: "{colors.on-surface-variant}"
  nav-indicator:
    backgroundColor: "{colors.tertiary-container}"
    textColor: "{colors.ink}"
  chip-selected:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.on-primary}"
  row:
    padding: "8px 16px"
    height: "64px"
---

# Design System: Touchline

## Overview

**Creative North Star: "The Terrace Scarf"**

Every prediction is knitted into a supporter's scarf. A fixture is a half-and-half matchday scarf whose seams sit at the win, draw, and loss split; a club's form is a short bar scarf of its last results; a season probability is a scarf with the remainder dropped. The scarf is the chart, so numbers arrive as something a fan already owns rather than as percentage rows on dark cards.

Around the scarves the app is plain Material 3 on cool terrace concrete: flat tonal cards, Roboto for everything that is read, one green and one pink as Touchline's own colours, and every club in its own two-tone pair taken from the data. Stitch-grid lettering (Jersey 10) is reserved for the knit: hero percentages, club names on scarves, the wordmark, scores, and monograms. Density is a two-minute glance: one hero fixture, then short sections with generous air above each heading.

**Key Characteristics:**
- Probabilities are drawn as knitted scarves whose band widths equal the numbers.
- Touchline's scarf is pitch green and paper pink; clubs wear their own colours.
- Stitch type only at whole-stitch sizes, Roboto for body and UI.
- Results carry shape as well as colour: solid knit, cross-stitch, dropped stitch.
- Flat tonal surfaces; only bottom sheets float.

## Colors

Two club-scarf colours on pale concrete, with club colours supplied by the data and a fixed result triad.

### Primary
- **Pitch Green** (pitch): the brand's first scarf colour. Light-mode primary: wordmark, selected league chip, "Breakdown" links, positive effect bars, rising trends, bargain deltas. Lifts to Floodlit Mint (primary-dark) on the night ground.

### Tertiary
- **Paper Pink** (paper-pink): the brand's second scarf colour. Tertiary container everywhere: the navigation indicator behind the selected destination (with ink icons), text selection at 55% alpha. In dark mode it is the tertiary itself.
- **Deep Plum** (tertiary, light only): pink's legible partner on concrete; negative effect bars, falling trend arrows, the unusual-load warning icon.

### Result colours
- **Win Green** (win), **Draw Slate** (draw), **Loss Red** (loss): used only for results and the draw band of a fixture scarf, always paired with a knit shape (see Components).

### Neutral
- **Terrace Concrete** (terrace-concrete): the light ground and scaffold. The 1px stitch gap between scarf bands is painted in the ground colour.
- **Night Ground** (night-ground): the dark ground, a deep green-black rather than navy.
- **Ink** (ink): body text on light; ink-on-colour for light club colours and pink.
- **Surface container family**: tonal steps from lowest to highest carry cards (low), the navigation bar and rail (container), and portrait fallbacks (highest). Outline-variant draws dividers, chip borders, and scarf edges.
- **Neutral club pair** (neutral-club-a / neutral-club-b): the scarf and monogram colours for any club the data has no colours for.

### Named Rules
**The Club's Own Colours Rule.** Club colours come from the data bundle (`clubs[].colors.primary/secondary`), never from a hand-kept table; a missing pair falls back to the neutral club pair, never to brand green.

**The Ink-On-Colour Rule.** Text on any colour uses ink when the colour's luminance exceeds 0.36, white otherwise.

**The Shape-Before-Colour Rule.** Colour is never the only signal: every result and probability band also differs by knit, label, or semantic description.

## Typography

**Display Font:** Jersey 10 (OFL, self-hosted at `assets/fonts/Jersey10-Regular.ttf`)
**Body Font:** Roboto (Material default)

**Character:** A knitted stitch grid for the few numbers and names that should feel worn on a scarf, set against neutral Roboto that does all the reading.

### Hierarchy
- **Display Large** (Jersey, 56px = 3 stitches, line-height 1, tabular): the favourite's percentage on the hero fixture scarf.
- **Display Small** (Jersey, 37.333px = 2 stitches): the TOUCHLINE wordmark, club names on club scarves, the hero's fallback label size.
- **Headline Small** (Jersey, 18.667px = 1 stitch): percentages on row scarves, form letters, scores, crest and portrait monograms.
- **Title Large** (Roboto 700, 22px, -0.2 tracking): section headings, hero fixture title.
- **Title Medium** (Roboto 600, 16px): row titles, pundit verdicts.
- **Body Medium** (Roboto 400, 14px, line-height 1.4): explanations, metadata, empty notes.
- **Label Large / Medium** (Roboto 500, 14 / 12px, tabular figures): numbers in bars, kickoff times, trend notes.

### Named Rules
**The Whole-Stitch Rule.** Jersey is set only at multiples of one stitch, where 1 stitch = 75/1400 em, so the 18.667px size makes one stitch one logical pixel. Use 18.667, 37.333, or 56; never an in-between size, never letter-spacing.

**The Stitch Is For The Knit Rule.** Jersey appears on scarves, the wordmark, scores, and monograms. Headings, verdicts, and body copy stay in Roboto.

**The Tabular Rule.** Every number that sits in a column or updates (percentages, points, money, minutes) uses tabular figures.

## Layout

Single-column phone layout on a 16px gutter. A pinned 64px app bar carries the wordmark, freshness chip, and info action; beneath it an 8px brand band and the league chip row. Sections stack with a SectionHeading: 28px above, 8px below, so the gap groups content with its heading. List rows have a 64px minimum height with 16px horizontal / 8px vertical padding and 12px gaps. Horizontal player strips use 156px tiles with 10px separators, and their height grows with the text scale. Navigation switches at 840dp: NavigationBar below, NavigationRail (labels always shown, 1px vertical divider) at and above. Destinations live in an IndexedStack; system back from any tab returns to Home before leaving the app.

## Elevation & Depth

Flat. Cards, the app bar (including scrolled-under), the navigation bar, and chips all sit at elevation 0; depth comes from the tonal surface-container steps against concrete or night ground. The only floating layer is the modal bottom sheet (elevation 1, drag handle, surface-container-low), used for the match breakdown, filters, and "How this works".

### Named Rules
**The Only Sheets Float Rule.** No shadows on cards, bars, chips, or scarves. If something needs to float, it is a bottom sheet.

## Shapes

Soft, small corners. Cards round at 16px; player portraits clip at 10px in a 3:4 frame; monograms round at a quarter of their size; scarves are near-square at 3px with a 1px outline-variant edge; signed effect bars at 2px. Hero and club scarves add a short fringe at both ends in their end colours. Table zones use a 2px divider for the top-four and bottom-three lines, 1px indented dividers between other rows.

## Components

### Scarf (signature)
The painter behind every chart. A scarf is a row of bands; each band has a relative width, a list of stripe colours cycled across it, a knit, and an optional label.
- **Knit:** solid (stripes plus a faint V-stitch texture at 10% alpha), cross (solid plus cross-stitches in ink-on-colour at 35%), dropped (ground colour with ladder lines in the band colour).
- **Seams:** a 1px line of the ground colour between bands, so neighbouring results read as separate stitches.
- **Labels:** knitted onto a solid name panel in the band's first colour, centred; label styles are tried largest-first and the first that fits wins; no label if none fit.
- **Motion:** knits in row by row from the top (4px rows) over 650ms on easeOutExpo, once on first view; instant when the platform asks to reduce motion.
- **Semantics:** one container label describing the whole scarf in words; the painting is excluded.

### FixtureScarf
Home colours, a draw-slate cross-stitched band, away colours, each as wide as its probability. Bands of 12% or more carry their percentage. Hero: 72dp tall, fringed, 14px stripes, labels try 56 / 37.333 / 18.667, crests (36dp) at both ends, tapping opens the match sheet. Rows: 24dp, 10px stripes, 1-stitch labels.

### FormScarf
Last results as square cells (22dp default, 16dp in rows): win solid, draw cross, loss dropped, each lettered W / D / L. Empty form reads "No games yet".

### ClubScarf
The club's own pair, 72dp, fringed, 16px stripes, the club name upper-cased on a 2-stitch panel.

### ShareScarf / ShareBar
A probability as a scarf: the share knitted in the club or primary colours, the remainder a dropped stitch in outline-variant. In ShareBar it sits at 14dp between a 96px label and a 52px tabular percentage.

### BrandBand
Touchline's own scarf (pitch and pink stripes) as an 8dp band under the app bar; decorative and hidden from assistive tech.

### Cards / Containers
- **Corner Style:** 16px.
- **Background:** surface-container-low.
- **Shadow Strategy:** none (see Elevation & Depth).
- **Internal Padding:** 16px hero, 12px player tile.

### Chips
League chips are filter chips without checkmarks: outline-variant border unselected, pitch fill with on-primary 600 text selected. The freshness chip is an action chip whose icon states built-in, updating, up-to-date, or offline, with the full meaning in its tooltip and label.

### Rows
Club, player, and fixture rows share one shell: leading crest or portrait, title (title medium) and one-line muted subtitle, optional trailing element, ink ripple, 64px minimum.

### Navigation
Four destinations (Home, Clubs, Players, Scout) with outlined icons that fill when selected. Bar and rail sit on surface-container; the selected indicator is paper pink with ink icons.

### Empty Note
Null data is never a blank or an error: an hourglass icon and a short, friendly line in on-surface-variant ("Nothing else on this week.").

## Do's and Don'ts

### Do:
- **Do** draw any win/draw/loss split or 0-1 share as a scarf whose band widths equal the values.
- **Do** put scarf labels on a solid name panel and separate bands with a 1px ground-colour seam.
- **Do** knit scarves in row by row (650ms, easeOutExpo) and show them complete under reduced motion.
- **Do** set Jersey only at 18.667, 37.333, or 56px.
- **Do** take club colours from the bundle and fall back to the neutral pair.
- **Do** write in a pundit's voice: one plain verdict per item ("Bayern should handle this.").
- **Do** present workload as a risk index with a band ("Heavy · 82"), and keep trend reasons to 14 characters or fewer.
- **Do** keep 28px above and 8px below every section heading.

### Don't:
- **Don't** add shadows to cards, chips, or bars; only bottom sheets float.
- **Don't** show workload as an injury probability.
- **Don't** let colour be the only difference between results; keep the knit shapes.
- **Don't** set headings, verdicts, or body text in Jersey.
- **Don't** apply the knit texture outside scarf bands.
- **Don't** fall back to dark navy cards with a green accent and rows of percentages.
