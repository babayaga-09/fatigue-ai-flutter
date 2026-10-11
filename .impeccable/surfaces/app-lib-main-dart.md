---
version: 1
slug: "app-lib-main-dart"
primary_target: "app/lib/main.dart"
related_targets: []
---

Scope: the whole Touchline app (app/), Flutter, Android-first with a Flutter web demo built from the same code. Visitor mode: Operate.

Audience and job: a casual fan on a 1–2 minute glance (bus, halftime, pre-weekend) wanting plain verdicts: who wins this weekend, who's hot, is my club safe, who's a bargain, where a player's value is heading. Constraints: Material 3 shell and native controls; offline-first; null = friendly empty state; workload never shown as injury probability; colour never the only signal. v2 honesty rules: the Big Five list is ranked by the price-only model (the ML model lost to price) and says so; manager effect is labelled mostly luck; dependency is a descriptive with/without line, never a ranking.

## Direction contract

THESIS: Every screen is printed like the programme bought at the turnstile. Players appear as two-colour halftone portraits in their club's colours; line-ups, dependencies and managers read as numbered team sheets. Refuses the category default of dark navy cards, crests and a single neon-green accent.

OWN-WORLD: White coated programme stock (#FFFFFF) with ink #111111; Touchline's own programme colours are turnstile red #D7262D and royal blue #1D3C8F, with sponsor-strip yellow #F2C200 used only for printed strips and highlights. Dark theme is the programme's black back cover (#111111 ground, white type). Each screen takes its accent from the club in focus; neutral stock elsewhere. Headlines in Archivo at its narrowest width and heaviest weight, uppercase, like programme mastheads; text and numbers in Archivo at normal width, numbers tabular. Win/draw/loss is a printed three-part strip with the figures set in it, never colour alone. Square corners, hairline rules, no shadows except bottom sheets. A visible column grid: numbers right-aligned on one baseline grid.

STORY: A fan opens to the cover: the week's big match, both clubs' key players printed in their colours, who's favoured. They turn the inside pages: hot players, prospects in feeder leagues, sacking-bounce finding, career curves. Tapping a player or club opens their page, where the why lives. They leave with one opinion to argue about.

FIRST VIEWPORT (phone portrait): a top app bar with the masthead wordmark TOUCHLINE in condensed black caps and the data-freshness chip; the league chip row; the cover: a full-width block split into two vertical halves (home colour left, away colour right), each half holding that club's most valuable player as a halftone portrait filling the half, club names in condensed caps across the foot, the kickoff line; under it the printed three-part win/draw/loss strip with percentages set inside each band; a one-line pundit verdict; the top of the "Running hot" inside page; the 4-destination navigation bar.

FORM: The Matchday Programme, candidate 3 of 7 on the ordered list; seed key 37b0e2b4. Raised from Scoreboard Flaps: values change in place, rows never jump. Raised from Grid Specimen: a visible column grid for every number. Raised from Vertical Feed: one item owns the top of each screen (the cover); the rest are inside pages. Signature interaction: halftone portraits develop in on first view (dots grow from 0 to full radius over 500ms, ease-out-expo; complete instantly under reduced motion); tapping the cover opens the match sheet.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
