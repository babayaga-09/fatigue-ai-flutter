import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/bundle.dart';
import '../format.dart';
import 'empty_note.dart';

/// "2026/27" -> the end of that season.
DateTime seasonEnd(String label) => DateTime(int.parse(label.substring(0, 4)) + 1, 6, 30);

/// Market value so far (solid), then the forecast: the likely path (dashed) inside the band
/// where 80% of outcomes should land.
class CareerChart extends StatelessWidget {
  const CareerChart({super.key, required this.history, required this.career, this.accent});

  final List<ValuePoint> history;
  final Career career;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) return const EmptyNote('No valuations on record yet.');
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final c = career;
    final last = history.last;
    final colour = accent ?? scheme.primary;
    return Semantics(
      label: 'Market value ${money(last.value)} now. Likely ${money(c.p50.last)} by '
          '${c.seasons.last}, with an 80% range of ${money(c.p10.last)} to ${money(c.p90.last)}.',
      child: ExcludeSemantics(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            height: 168,
            child: CustomPaint(
              size: Size.infinite,
              painter: _FanPainter(history, c, colour, scheme.onSurface, scheme.outlineVariant),
            ),
          ),
          const SizedBox(height: 6),
          // the "now" label sits under the now point, the same x the painter uses
          LayoutBuilder(builder: (context, box) {
            final t0 = history.first.date.millisecondsSinceEpoch;
            final t1 = seasonEnd(c.seasons.last).millisecondsSinceEpoch;
            final f = t1 == t0 ? 1.0 : (last.date.millisecondsSinceEpoch - t0) / (t1 - t0);
            final x = (f * (box.maxWidth - 6)).clamp(0.0, box.maxWidth);
            return SizedBox(
              height: 20,
              child: Stack(clipBehavior: Clip.none, children: [
                Positioned(left: 0,
                    child: Text('${history.first.date.year}', style: tt.labelMedium)),
                Positioned(right: 0,
                    child: Text('${c.seasons.last} · ${money(c.p50.last)}',
                        style: tt.labelMedium)),
                Positioned(
                  left: (x - 80).clamp(44.0, box.maxWidth - 260), width: 160,
                  child: Text('Now ${money(last.value)}', textAlign: TextAlign.center,
                      style: tt.labelMedium),
                ),
              ]),
            );
          }),
        ]),
      ),
    );
  }
}

class _FanPainter extends CustomPainter {
  _FanPainter(this.history, this.c, this.band, this.ink, this.grid);

  final List<ValuePoint> history;
  final Career c;
  final Color band, ink, grid;

  @override
  void paint(Canvas canvas, Size size) {
    final ends = [for (final s in c.seasons) seasonEnd(s)];
    final t0 = history.first.date.millisecondsSinceEpoch.toDouble();
    final t1 = ends.last.millisecondsSinceEpoch.toDouble();
    final vmax = math.max(history.map((p) => p.value).reduce(math.max), c.p90.reduce(math.max))
        .toDouble();
    double x(DateTime d) => (d.millisecondsSinceEpoch - t0) / (t1 - t0 == 0 ? 1 : t1 - t0)
        * (size.width - 6);
    double y(num v) => size.height - 2 - v / (vmax == 0 ? 1 : vmax) * (size.height - 10);
    final now = history.last;

    canvas.drawLine(Offset(0, size.height - 2), Offset(size.width, size.height - 2),
        Paint()..color = grid..strokeWidth = 1);

    // 80% band
    final bandPath = Path()..moveTo(x(now.date), y(now.value));
    for (var i = 0; i < ends.length; i++) {
      bandPath.lineTo(x(ends[i]), y(c.p90[i]));
    }
    for (var i = ends.length - 1; i >= 0; i--) {
      bandPath.lineTo(x(ends[i]), y(c.p10[i]));
    }
    bandPath.close();
    canvas.drawPath(bandPath, Paint()..color = band.withValues(alpha: 0.28));

    // history
    final h = Path()..moveTo(x(history.first.date), y(history.first.value));
    for (final p in history.skip(1)) {
      h.lineTo(x(p.date), y(p.value));
    }
    final stroke = Paint()
      ..color = ink
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(h, stroke);

    // likely path, dashed
    var from = Offset(x(now.date), y(now.value));
    final dash = Paint()
      ..color = band
      ..strokeWidth = 2.5;
    for (var i = 0; i < ends.length; i++) {
      final to = Offset(x(ends[i]), y(c.p50[i]));
      final len = (to - from).distance;
      for (double d = 0; d < len; d += 9) {
        canvas.drawLine(Offset.lerp(from, to, d / len)!,
            Offset.lerp(from, to, math.min(1, (d + 5) / len))!, dash);
      }
      canvas.drawCircle(to, 3.5, Paint()..color = band);
      from = to;
    }
    canvas.drawCircle(Offset(x(now.date), y(now.value)), 4.5, Paint()..color = ink);
  }

  @override
  bool shouldRepaint(_FanPainter old) =>
      old.history != history || old.c != c || old.band != band || old.ink != ink;
}
