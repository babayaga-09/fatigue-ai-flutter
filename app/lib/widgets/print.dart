import 'package:flutter/material.dart';

import '../data/bundle.dart';
import '../format.dart';
import '../theme/theme.dart';
import '../theme/tokens.dart';

/// A club's two printing colours, or the neutral pair when unknown.
List<Color> clubColors(Club? c) => c?.colors == null
    ? const [TL.neutralA, TL.neutralB]
    : [Color(c!.colors!.primary), Color(c.colors!.secondary)];

double _dist(Color a, Color b) =>
    (a.r - b.r).abs() + (a.g - b.g).abs() + (a.b - b.b).abs();

/// Home and away printing colours that can sit side by side: when both clubs print in
/// (nearly) the same colour, the away side uses its second colour.
(Color, Color) matchColors(Club? home, Club? away) {
  final h = clubColors(home), a = clubColors(away);
  return (h[0], _dist(h[0], a[0]) < 0.35 ? a[1] : a[0]);
}

/// Win / draw / loss as a printed three-part strip, each band as wide as its chance, with the
/// figure set inside it. Shapes, not only colours: the draw band is a plain stock band.
class ResultStrip extends StatelessWidget {
  const ResultStrip({super.key, required this.fixture, required this.home, required this.away,
      this.hero = false});

  final Fixture fixture;
  final Club? home, away;
  final bool hero;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = fixture.p;
    final (hc, ac) = matchColors(home, away);
    final dc = scheme.surfaceContainerHighest;
    final h = hero ? 56.0 : 30.0;
    final hn = home?.name ?? 'Home', an = away?.name ?? 'Away';
    // a band the same colour as the page gets a hairline so it doesn't vanish
    Border? edge(Color c) => _dist(c, scheme.surface) < 0.25
        ? Border.all(color: scheme.onSurface, width: 1) : null;
    Widget band(double v, Color c, String side) {
      final style = masthead(hero ? 30 : 15, onColor(c));
      return Expanded(
        flex: (v * 1000).round().clamp(1, 1000),
        child: Container(
          height: h,
          decoration: BoxDecoration(color: c, border: edge(c)),
          alignment: side == 'away' ? Alignment.centerRight
              : side == 'home' ? Alignment.centerLeft : Alignment.center,
          padding: EdgeInsets.symmetric(horizontal: hero ? 10 : 6),
          child: v >= (hero ? 0.12 : 0.16)
              ? FittedBox(fit: BoxFit.scaleDown, child: Text(pct(v), style: style))
              : null,
        ),
      );
    }

    final tt = Theme.of(context).textTheme;
    Widget label(double v, String text, TextAlign align) => Expanded(
          flex: (v * 1000).round().clamp(1, 1000),
          child: Text(text, textAlign: align, maxLines: 1, overflow: TextOverflow.clip,
              style: tt.labelMedium),
        );
    return Semantics(
      label: '$hn win ${pct(p[0])}, draw ${pct(p[1])}, $an win ${pct(p[2])}',
      container: true,
      child: ExcludeSemantics(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            band(p[0], hc, 'home'),
            SizedBox(width: 2, height: h),
            band(p[1], dc, 'draw'),
            SizedBox(width: 2, height: h),
            band(p[2], ac, 'away'),
          ]),
          if (hero) ...[
            const SizedBox(height: 6),
            Row(children: [
              label(p[0], hn, TextAlign.start),
              const SizedBox(width: 2),
              label(p[1], p[1] >= 0.12 ? 'Draw' : '', TextAlign.center),
              const SizedBox(width: 2),
              label(p[2], p[2] >= 0.12 ? an : '', TextAlign.end),
            ]),
          ],
        ]),
      ),
    );
  }
}

/// Last results as printed boxes with the letter in each: won solid ink, drew grey, lost an
/// open box.
class FormBoxes extends StatelessWidget {
  const FormBoxes({super.key, required this.form, this.cell = 22});

  final List<String> form;
  final double cell;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (form.isEmpty) {
      return Text('No games yet', style: Theme.of(context).textTheme.bodySmall);
    }
    const words = {'W': 'won', 'D': 'drew', 'L': 'lost'};
    return Semantics(
      label: 'Form: ${form.map((r) => words[r] ?? r).join(', ')}',
      child: ExcludeSemantics(
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (final (i, r) in form.indexed)
            Container(
              width: cell,
              height: cell,
              margin: EdgeInsets.only(left: i == 0 ? 0 : 2),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: r == 'W' ? scheme.onSurface
                    : r == 'D' ? scheme.surfaceContainerHighest : null,
                border: r == 'L' ? Border.all(color: scheme.onSurface, width: 1.5) : null,
              ),
              child: Text(r, style: masthead(cell * 0.62,
                  r == 'W' ? scheme.surface : scheme.onSurface)),
            ),
        ]),
      ),
    );
  }
}

/// A 0–1 share printed as a solid bar on a hairline track.
class ShareTrack extends StatelessWidget {
  const ShareTrack({super.key, required this.value, required this.color, this.height = 8});

  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0);
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: SizedBox(
        height: height,
        child: Stack(children: [
          Positioned.fill(
              child: Align(alignment: Alignment.center,
                  child: Container(height: 1, color: scheme.outline))),
          FractionallySizedBox(widthFactor: v == 0 ? 0.0 : v, heightFactor: 1,
              child: ColoredBox(color: color)),
        ]),
      ),
    );
  }
}

/// A numbered line of a team sheet: programme number, name, note, trailing figure.
class TeamSheetRow extends StatelessWidget {
  const TeamSheetRow({super.key, required this.number, required this.title, this.subtitle,
      this.trailing, this.onTap, this.leading});

  final int number;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? leading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: scheme.outlineVariant))),
        child: Row(children: [
          SizedBox(width: 32,
              child: Text('$number', style: masthead(26, scheme.primary))),
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: tt.titleSmall!.copyWith(letterSpacing: 0.4)),
              if (subtitle != null)
                Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: tt.bodySmall!.copyWith(color: scheme.onSurfaceVariant)),
            ]),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ]),
      ),
    );
  }
}

/// A club's printed band: its colour, its name in masthead caps.
class ClubBand extends StatelessWidget {
  const ClubBand({super.key, required this.club, this.height = 88});

  final Club club;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = clubColors(club);
    return Semantics(
      label: '${club.name} colours',
      child: ExcludeSemantics(
        child: Container(
          height: height,
          color: c[0],
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          alignment: Alignment.bottomLeft,
          child: Column(mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.bottomLeft,
                child: Text(club.name.toUpperCase(), style: masthead(44, onColor(c[0])))),
            const SizedBox(height: 6),
            Container(height: 4, color: c[1] == c[0] ? onColor(c[0]) : c[1]),
          ]),
        ),
      ),
    );
  }
}
