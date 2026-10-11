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
