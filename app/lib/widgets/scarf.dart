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
      if (x > body.left) {
        // One-stitch gap between bands so neighbouring results read as separate stitches.
        canvas.drawLine(Offset(x, body.top), Offset(x, body.bottom),
            Paint()..color = ground..strokeWidth = 1);
      }
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
      final padW = tp.width + (band.label!.length <= 2 ? 6 : 12);
      if (padW > r.width - 4 || tp.height > r.height) continue;
      final pr = Rect.fromCenter(center: r.center, width: padW, height: r.height);
      canvas.drawRect(pr, Paint()..color = panel); // ground-coloured panel on a dropped stitch keeps the letter clear
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
