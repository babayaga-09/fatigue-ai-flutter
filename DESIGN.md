---
name: Touchline
description: Football predictions printed like the matchday programme bought at the turnstile.
colors:
  stock: "#FFFFFF"
  ink: "#111111"
  turnstile-red: "#D7262D"
  royal-blue: "#1D3C8F"
  sponsor-yellow: "#F2C200"
  neutral-club-a: "#4A4A4A"
  neutral-club-b: "#E4E4E4"
  primary: "#D7262D"
  on-primary: "#FFFFFF"
  primary-container: "#FBE3E4"
  on-primary-container: "#5C1013"
  secondary: "#1D3C8F"
  on-secondary: "#FFFFFF"
  secondary-container: "#E2E8F8"
  on-secondary-container: "#0E1E4A"
  tertiary: "#6B5500"
  on-tertiary: "#111111"
  tertiary-container: "#F2C200"
  on-tertiary-container: "#111111"
  error: "#B3261E"
  surface: "#FFFFFF"
  on-surface: "#111111"
  on-surface-variant: "#4D4D4D"
  surface-container-lowest: "#FFFFFF"
  surface-container-low: "#F4F4F3"
  surface-container: "#EDEDEC"
  surface-container-high: "#E5E5E4"
  surface-container-highest: "#DCDCDB"
  outline: "#6E6E6E"
  outline-variant: "#D4D4D3"
  primary-dark: "#FF8A84"
  on-primary-dark: "#111111"
  primary-container-dark: "#5C1013"
  on-primary-container-dark: "#FFDAD8"
  secondary-dark: "#A9BDFF"
  on-secondary-dark: "#111111"
  secondary-container-dark: "#1D3C8F"
  tertiary-dark: "#F2C200"
  error-dark: "#FF8A84"
  surface-dark: "#111111"
  on-surface-dark: "#F2F2F2"
  on-surface-variant-dark: "#B8B8B8"
  surface-container-lowest-dark: "#0A0A0A"
  surface-container-low-dark: "#1A1A1A"
  surface-container-dark: "#202020"
  surface-container-high-dark: "#292929"
  surface-container-highest-dark: "#333333"
  outline-dark: "#8C8C8C"
  outline-variant-dark: "#3A3A3A"
typography:
  display-large:
    fontFamily: "Archivo"
    fontSize: "56px"
    fontWeight: 900
    lineHeight: 0.92
    letterSpacing: "0"
    fontVariation: "'wdth' 62, 'wght' 900"
    fontFeature: "'tnum'"
  display-medium:
    fontFamily: "Archivo"
    fontSize: "44px"
    fontWeight: 900
    lineHeight: 0.92
    letterSpacing: "0"
    fontVariation: "'wdth' 62, 'wght' 900"
    fontFeature: "'tnum'"
  display-small:
    fontFamily: "Archivo"
    fontSize: "34px"
    fontWeight: 900
    lineHeight: 0.92
    letterSpacing: "0"
    fontVariation: "'wdth' 62, 'wght' 900"
    fontFeature: "'tnum'"
  headline-small:
    fontFamily: "Archivo"
    fontSize: "24px"
    fontWeight: 900
    lineHeight: 0.92
    letterSpacing: "0"
    fontVariation: "'wdth' 62, 'wght' 900"
    fontFeature: "'tnum'"
  title-large:
    fontFamily: "Archivo"
    fontSize: "22px"
    fontWeight: 800
    lineHeight: 1.27
    letterSpacing: "-0.2px"
  title-medium:
    fontFamily: "Archivo"
    fontSize: "16px"
    fontWeight: 700
    lineHeight: 1.5
    letterSpacing: "0.15px"
  title-small:
    fontFamily: "Archivo"
    fontSize: "14px"
    fontWeight: 700
    lineHeight: 1.43
    letterSpacing: "0.1px"
    fontFeature: "'tnum'"
  body-medium:
    fontFamily: "Archivo"
    fontSize: "14px"
    fontWeight: 400
    lineHeight: 1.4
    letterSpacing: "0.25px"
  body-small:
    fontFamily: "Archivo"
    fontSize: "12px"
    fontWeight: 400
    lineHeight: 1.33
    letterSpacing: "0.4px"
  label-large:
    fontFamily: "Archivo"
    fontSize: "14px"
    fontWeight: 700
    lineHeight: 1.43
    letterSpacing: "0.1px"
    fontFeature: "'tnum'"
  label-medium:
    fontFamily: "Archivo"
    fontSize: "12px"
    fontWeight: 500
    lineHeight: 1.33
    letterSpacing: "0.5px"
    fontFeature: "'tnum'"
  label-small:
    fontFamily: "Archivo"
    fontSize: "11px"
    fontWeight: 600
    lineHeight: 1.45
    letterSpacing: "0.5px"
    fontFeature: "'tnum'"
rounded:
  none: "0px"
  sharp: "2px"
  sheet: "4px"
spacing:
  hairline: "2px"
  xs: "4px"
  sm: "8px"
  md: "12px"
  gutter: "16px"
  section: "32px"
components:
  button-filled:
    backgroundColor: "{colors.on-surface}"
    textColor: "{colors.surface}"
    typography: "{typography.label-large}"
    rounded: "{rounded.sharp}"
  button-outlined:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.primary}"
    typography: "{typography.label-large}"
    rounded: "{rounded.sharp}"
  button-text:
    textColor: "{colors.primary}"
    typography: "{typography.label-large}"
  chip-league:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.on-surface}"
    typography: "{typography.label-large}"
    rounded: "{rounded.sharp}"
    height: "48px"
  chip-league-selected:
    backgroundColor: "{colors.on-surface}"
    textColor: "{colors.surface}"
    rounded: "{rounded.sharp}"
  nav-bar:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.on-surface-variant}"
    typography: "{typography.label-medium}"
  nav-bar-indicator:
    backgroundColor: "{colors.on-surface}"
    textColor: "{colors.surface}"
    rounded: "{rounded.sharp}"
  app-bar:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.on-surface}"
    height: "60px"
  section-heading:
    textColor: "{colors.on-surface}"
    typography: "{typography.headline-small}"
    padding: "32px 16px 10px"
  team-sheet-row:
    textColor: "{colors.on-surface}"
    typography: "{typography.title-small}"
    padding: "8px 0"
    height: "56px"
  team-sheet-number:
    textColor: "{colors.primary}"
    width: "44px"
  result-strip:
    textColor: "{colors.on-surface}"
    rounded: "{rounded.none}"
    height: "30px"
  result-strip-hero:
    rounded: "{rounded.none}"
    height: "56px"
  result-strip-draw:
    backgroundColor: "{colors.surface-container-highest}"
    textColor: "{colors.on-surface}"
  form-box-won:
    backgroundColor: "{colors.on-surface}"
    textColor: "{colors.surface}"
    rounded: "{rounded.none}"
    size: "22px"
  form-box-drew:
    backgroundColor: "{colors.surface-container-highest}"
    textColor: "{colors.on-surface}"
    rounded: "{rounded.none}"
    size: "22px"
  form-box-lost:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.on-surface}"
    rounded: "{rounded.none}"
    size: "22px"
  match-cover-strip:
    backgroundColor: "{colors.sponsor-yellow}"
    textColor: "{colors.ink}"
    typography: "{typography.label-large}"
    padding: "6px 16px"
  club-band:
    typography: "{typography.display-medium}"
    padding: "0 16px 10px"
    height: "88px"
  bottom-sheet:
    backgroundColor: "{colors.surface}"
    rounded: "{rounded.sheet}"
---

# Design System: Touchline

## Overview

**Creative North Star: "The Matchday Programme"**

Every screen is printed like the programme bought at the turnstile. The ground is white coated stock with black ink. Touchline's own printing colours are turnstile red and royal blue, and sponsor-strip yellow appears only on printed strips and highlights. Whenever a club is in focus, its two printing colours take over: the cover halves, the club band, the halftone portraits, and the share bars all print in that club's colours. Everywhere else the page stays neutral stock. The dark theme is the programme's black back cover: an #111111 ground with white type, and the same printing colours.

Mastheads are condensed black capitals. Lists read as numbered team sheets. Players appear as two-colour halftone portraits, never as photos in rounded frames. Probabilities are printed bands with the figure set inside, so meaning never depends on colour alone. Corners are square, rules are either hairline or heavy, and nothing floats. One item owns the top of each screen (the cover or a club band) and the rest reads as inside pages under heavy section rules. The system rejects the category default of dark navy cards, crests as decoration, and a single neon-green accent.

**Key Characteristics:**
- White stock and #111111 ink; red, blue and yellow as printing colours, not UI tints.
- Club colours replace the house accent whenever a club is in focus.
- Archivo throughout: condensed black caps for mastheads, normal width for text, tabular figures for numbers.
- Square (2px) corners, hairline and 3px rules, no shadows except the bottom sheet.
- Halftone portraits that develop in on first view.

## Colors

A printer's palette: one stock, one ink, and three spot colours, with club colours taking over when a club is in focus.

### Primary
- **Turnstile Red** (`turnstile-red` / `primary`): Touchline's own colour when no club is in focus. Used for the TOUCHLINE wordmark, team-sheet numbers, text actions ("Breakdown", "All"), the career-chart band when the club colour is too pale, negative effect bars, and the lower half of the sacking-bounce bars. In dark theme it lightens to Coral Red (`primary-dark`) so text actions stay legible on the black cover, while the wordmark keeps the full turnstile red.

### Secondary
- **Royal Blue** (`royal-blue` / `secondary`): the second house printing colour. Used for positive effect bars and bargain figures (fair value above price). In dark theme it becomes Pale Royal (`secondary-dark`).

### Tertiary
- **Sponsor-Strip Yellow** (`sponsor-yellow`): printed strips and highlights only. It fills the kickoff strip under the match cover and the text-selection highlight (at 60% alpha). It always takes ink-black text. Its dark-gold text form (`tertiary`, #6B5500) exists in the scheme for legibility on white.

### Neutral
- **Programme Stock** (`stock`): the light page ground and the gap between cover halves.
- **Programme Ink** (`ink`): body type, heavy rules, the selected chip and nav indicator fill, and won form boxes. It is also the dark theme's ground (the black back cover).
- **Stock Greys** (`surface-container-low` to `surface-container-highest`): tonal steps for cards and the draw band of the result strip (`surface-container-highest`).
- **Rule Greys** (`outline`, `outline-variant`): `outline` for chip borders and the hairline under share tracks; `outline-variant` for team-sheet and divider hairlines.
- **Unknown-Club Pair** (`neutral-club-a`, `neutral-club-b`): substitutes for club colours when a club has none on record.

### Named Rules
**The Club-In-Focus Rule.** When a screen is about a club or a club's player, that club's printing colours carry the accent: cover halves, club band, halftone ink and paper, share bars, and career band. Turnstile red is the fallback when no club is in focus or the club colour is too pale to read (luminance above 0.6 to 0.7).

**The Yellow-Is-Print Rule.** Sponsor-strip yellow appears only as a printed strip or highlight. It never serves as a button, a chip, or text on stock.

**The Ink-On-Colour Rule.** Text on any printed colour uses ink (#111111) when the colour's luminance is above 0.36, and white otherwise. A halftone's ink must reach 3:1 contrast on its field, or else it falls back to black or white.

## Typography

**Display Font:** Archivo (variable; bundled at `assets/fonts/Archivo.ttf`) at width 62, weight 900
**Body Font:** Archivo at normal width
**Label/Mono Font:** Archivo with tabular figures

**Character:** a single variable family split into two voices. Squeezed, heavy capitals do the shouting like a programme masthead, and the normal-width text underneath reads plainly. Every number is set in tabular figures, so columns line up.

### Hierarchy
- **Masthead / Display** (900, `wdth` 62, 56 / 44 / 34px, line-height 0.92, uppercase): the TOUCHLINE wordmark (36px, red), screen titles (32px), cover club names (34px), the club band name (44px), player and manager names on detail pages (30 to 34px), the scoreline in fixture rows (26px), and percentages inside result bands (30px hero, 15px inline). Always set in upper case.
- **Headline** (masthead at 24px): section headings under the heavy rule.
- **Title** (800, 22px): pundit verdicts such as the cover's one-line verdict. **Title Medium / Small** (700, 16 / 14px) are for row names; team-sheet names are uppercase with 0.4px tracking.
- **Body** (400, 14px, line-height 1.4): findings and explanations. **Body Small** (12px, on-surface-variant) is for row subtitles and section notes.
- **Label** (700 / 500 / 600, 14 / 12 / 11px, tabular): figures in columns, chip text, and nav labels. The cover's player name and kickoff strip use uppercase labels with 0.6 to 0.8px tracking.

### Named Rules
**The Masthead Rule.** Condensed black caps (`wdth` 62, `wght` 900) are reserved for mastheads, club names, section heads, and headline figures. Running text never uses them.

**The Tabular Rule.** Every figure that can sit in a column uses tabular figures and is right-aligned in a fixed-width cell (44px numbers, 52 to 56px percentages), so a column of numbers shares one edge.

## Layout

The page is a single column with a 16px gutter. Rules and team-sheet hairlines span the page measure, not the full bleed. The cover and the club band run edge to edge. A section opens with 32px above a 3px ink rule, then the heading, then 10px before its content. Rows have a minimum height of 56 to 64px with 8px vertical padding. Gaps inside a row are 12px, and printed elements are separated by 2px (between result bands and between form boxes). Horizontal player strips use 132px tiles with 3:4 portraits and 12px separation.

On phones (below 840px) there is a 4-destination bottom navigation bar (Home, Clubs, Players, Scouting). At 840px and above it is replaced by a navigation rail with labels and a 1px divider, and the content keeps a printed page width of at most 960px, centred on stock. The home screen leads with the match cover, sized at 62% of the screen width (clamped to 220 to 360px). Below the cover come the inside pages: Running hot, Ready for the Big Five, the sacking-bounce finding, This week, Clubs in form, Power rankings, Bargains, and Overworked watch. A colophon (3px rule plus a data-freshness line) closes the page.

## Elevation & Depth

The system is flat. App bars, cards, navigation, chips, and buttons all sit at elevation 0, with no scroll-under tint. Depth comes from print devices instead: the 2px ink rule under the app bar, 3px heavy section rules, 1px hairlines, solid colour fields, and a 2 to 3px stock gap between adjacent printed areas. The single exception is the bottom sheet (elevation 1), the one piece of paper laid on top of the page.

### Named Rules
**The Flat-Stock Rule.** Nothing casts a shadow except the bottom sheet. Separation comes from rules, gaps, and printed colour.

## Shapes

Corners are square. Buttons, chips, segmented buttons, inputs, cards, and the navigation indicator share a 2px corner (`sharp`), only enough to keep anti-aliasing clean. Printed elements are fully square: result bands, form boxes, the club band, cover halves, share tracks, and the scrollbar. The bottom sheet's top corners are the only softer form, at 4px. Rules come in three weights: a 1px hairline, a 1.5px outline (outlined buttons, lost form boxes), and heavy 2 to 3px ink (app-bar foot, section rules). Portraits are 3:4 rectangles printed as halftone dot screens, never circles.

## Components

### Buttons
- **Shape:** square (2px).
- **Filled:** an ink block with stock text. In dark theme the colours invert, giving a white block with black text.
- **Outlined:** a 1.5px ink border on stock.
- **Text:** turnstile red label, used for section actions ("All") and "How the numbers are made".

### Chips
- **League chips:** a horizontal row 48px tall with 8px between chips, starting at the 16px gutter. Unselected chips have a 1px `outline` border on stock. The selected chip is an ink fill with stock text. Chips have no checkmarks.
- **Freshness chip:** an action chip in the app bar showing an icon and the data date. Its tooltip and semantics spell out freshness (up to date, offline, built-in, updating).

### Navigation
- **Bottom bar:** stock background at elevation 0. The selected destination sits inside a square ink indicator with a stock-coloured icon. Unselected icons use on-surface-variant, and all labels are bold 12px.
- **Rail (840px and up):** same treatment, labels always visible.
- **App bar:** a 60px toolbar on stock with a 2px ink rule along its foot. On the home screen it holds the TOUCHLINE wordmark, the freshness chip, and an info action, with league chips pinned below.

### Cards / Containers
- **Corner Style:** 2px.
- **Background:** `surface-container-low`, elevation 0, no margin.
- **Usage:** rare. Most content sits directly on stock between section rules.

### Inputs / Fields
- **Style:** outlined, 2px corners, Material default stroke on stock. The cursor and selection handles use primary, and the selection fill is sponsor yellow at 60%.

### Section Heading
A 3px ink rule across the page measure, 8px of space, then the title in uppercase masthead at 24px. An optional red text action sits right-aligned. An optional one-line note in body-small grey gives the figure's meaning or its honesty caveat. Spacing is 32px above and 10px below.

### Team Sheet Row
A numbered line of a team sheet. The programme number is set in 26px red masthead inside a 44px column. The name follows in uppercase title-small with 0.4px tracking, then an optional grey subtitle, then a trailing tabular figure. The row has a 56px minimum height and a 1px `outline-variant` hairline below that spans the page measure. Number-less rows are allowed for lines that are not rankings.

### Result Strip
Win / draw / loss printed as three bands with 2px gaps. Each band's width matches its probability, and every band carries its percentage in masthead caps, scaled down rather than dropped when the band is narrow. The home band prints in the home club's colour and the away band in the away club's colour (when the two are too close, the away side switches to its second colour). The draw band is the plain stock grey `surface-container-highest`. A band that matches the page colour gets a 1px ink border. The strip is 30px inline and 56px on the hero, where club and "Draw" labels sit underneath. Screen readers announce all three chances as one sentence.

### Form Boxes
The last results as square boxes (22px default, 16px in rows) with 2px gaps and the letter set in masthead. A win is a solid ink box with a stock letter, a draw is a grey box, and a loss is an open box with a 1.5px ink border. Shape and fill carry the meaning, so colour is never the only signal.

### Share Track
A 0 to 1 share drawn as a solid bar on a 1px `outline` hairline track (6 to 12px high). It prints in the club colour when a club is in focus and in primary otherwise. Inside ShareBar it is flanked by a 96px label and a 52px tabular percentage.

### Club Band
The masthead of a club page: an 88px full-bleed field in the club's first colour. The club name is set in 44px masthead caps at the bottom left (ink or white per the Ink-On-Colour Rule), above a 4px stripe in the club's second colour.

### Halftone Portrait
A player photo printed as a two-colour dot screen, with one dot per cell and dot area proportional to ink. Tones are stretched to the full range, and the maximum dot radius is 0.52 of a cell, so solid areas keep a sliver of paper. The darker club colour prints on the lighter one, and plain stock becomes the paper when the pair's contrast falls below 2.2. Dot density scales with size (14 to 44 columns). The portrait is 3:4, cover-fit, and anchored to the top. **Motion:** on first view the dots grow from 0 to full radius over 500ms (ease-out-expo). The portrait appears complete under reduced motion and on any later view. It falls back to the plain photo when pixels can't be read (web without CORS) and to masthead initials on the paper colour when there is no photo.

### Match Cover
The home screen's cover. A full-width block is split into home and away halves by a 3px stock gap. Each half is printed in its club's colour with that club's most valuable player as an edge-to-edge halftone. Each half carries the player's name in an uppercase label and the club name in 34px masthead caps across the foot. Under the halves runs a sponsor-yellow kickoff strip ("SAT 22:00 · BUNDESLIGA"), then the hero result strip, then the pundit verdict in title-large with a red "Breakdown" action. The whole cover is one tap target that opens the match sheet.

### Career Chart
A 168px fan chart. Value history is drawn as a 2.5px ink line ending in a 4.5px ink "now" dot. The forecast follows as a dashed (5 on / 4 off) likely path with 3.5px season dots, inside a band where 80% of outcomes should land, filled with the accent at 28% alpha. The accent is the club colour, or primary when the club colour is too pale. A 1px baseline hairline runs underneath. Below the chart are tabular labels for the start year, "Now €X", and the final season value.

## Do's and Don'ts

### Do:
- **Do** set mastheads, club names, and section heads in Archivo at `wdth` 62, `wght` 900, upper case, line-height 0.92.
- **Do** print the club in focus in its own two colours, and use `onColor` (luminance threshold 0.36) for any type laid on them.
- **Do** set the figure inside every probability band and every form box so meaning never rests on colour alone.
- **Do** open each inside page with the 3px ink rule and 32px above it.
- **Do** right-align figures in fixed-width tabular cells.
- **Do** render missing data as a plain-language EmptyNote, never as 0.

### Don't:
- **Don't** round corners beyond 2px (4px for the bottom sheet's top edge only).
- **Don't** add shadows or elevation to anything but the bottom sheet.
- **Don't** use sponsor yellow for buttons, chips, or text on stock.
- **Don't** show player photos as circular avatars or in full colour where a halftone can print. Plain photos are only the fallback when pixels can't be read.
- **Don't** fall back to dark navy cards or a single neon-green accent.
