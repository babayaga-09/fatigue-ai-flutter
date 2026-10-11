---
version: 1
slug: "app-lib-main-dart"
primary_target: "app/lib/main.dart"
related_targets: []
---

Scope: the whole Touchline app (app/), Flutter, Android-first with a Flutter web demo. Visitor mode: Operate.

Audience and job: a casual fan on a 1–2 minute glance (bus, halftime, pre-weekend) wanting plain verdicts: who wins this weekend, who's hot, is my club safe, who's a bargain. Constraints: Material 3 shell and native controls; offline-first; null = friendly empty state; workload never shown as injury probability; colour never the only signal.

## Direction contract

THESIS: Every prediction is knitted into a terrace scarf. A fixture is a half-and-half scarf whose seam sits at the win split; a club's form is a bar scarf of its results. Refuses the category default of dark navy cards with a green accent and percentage text rows.

OWN-WORLD: Touchline's own scarf colours, pitch green #0F3D2E and paper pink #F2A7C3, on a cool terrace-concrete ground (#EDEDE8 light; deep green-black in dark). Each club appears in its own two-tone colour pair. Knit material appears only inside scarf bars, as a faint V-stitch texture. Results carry shape as well as colour: a win is a solid knit, a draw a cross-stitch, a loss a dropped-stitch gap. Stitch-grid display lettering (Jersey family) appears at whole-grid sizes for club names and hero numbers only. Body and UI text use Roboto. Elevation discipline: only bottom sheets float.

STORY: A fan sees the weekend's headline match and who is favoured, then scrolls: who's running hot, which clubs are rising, bargains, overworked players. Tapping opens the club or player view, where the "why" lives. They leave with one opinion to argue about.

FIRST VIEWPORT (phone portrait): a top app bar with a thin brand-scarf band and the stitch wordmark "TOUCHLINE", plus a data-freshness chip; a league chip row; a full-width hero fixture card holding a 72dp half-and-half scarf (tall enough for the 56px stitch %) (home colours left, neutral draw band, away colours right, widths equal to probabilities, crests at both ends), the favourite's % monumental in stitch type, and a one-line pundit verdict; the top of the "Running hot" player carousel; the 4-destination navigation bar.

FORM: The Terrace Scarf, candidate 4 of 7 on the ordered list; seed key da53bc87. Signature interaction: scarves knit in row by row on first view (instant under reduced motion); tapping the hero scarf opens the match sheet.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
