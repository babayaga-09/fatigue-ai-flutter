import 'package:flutter/material.dart';

import '../data/bundle.dart';
import '../fpl/fpl_bundle.dart';
import '../fpl/fpl_optimiser.dart';
import '../state/app_state.dart';
import '../theme/theme.dart';
import '../theme/tokens.dart';

const _grass = Color(0xFF0E9F4D);
const _grassDark = Color(0xFF0B8F45);
const _keeper = ClubColors(0xFFF2C200, 0xFF111111);
const _unknown = ClubColors(0xFF9E9E9E, 0xFF616161);

/// Promoted clubs missing from the main bundle's colour table (traditional colours, approximated).
const _promoted = {
  'COV': ClubColors(0xFF6CB4E4, 0xFFFFFFFF),
  'HUL': ClubColors(0xFFF5A12D, 0xFF111111),
  'IPS': ClubColors(0xFF1B4F9C, 0xFFFFFFFF),
};

/// The XI on a pitch in formation, with the bench underneath, the way managers see their team.
class FplPitch extends StatelessWidget {
  const FplPitch({super.key, required this.bundle, required this.xi, required this.onTap});
  final FplBundle bundle;
  final XiResult xi;
  final void Function(FplPlayer) onTap;

  @override
  Widget build(BuildContext context) {
    // Club colours come from the main bundle when it is loaded; plain shirts otherwise.
    final clubs = context.dependOnInheritedWidgetOfExactType<AppScope>()?.notifier?.bundle;
    ClubColors kit(FplPlayer p) => p.pos == 'GK'
        ? _keeper
        : clubs?.clubById[bundle.teamById[p.team]?.clubId]?.colors ??
            _promoted[bundle.teamById[p.team]?.short] ?? _unknown;

    Widget card(int id, double w, {String? label}) {
      final p = bundle.byId[id]!;
      return _PlayerCard(
        player: p,
        kit: kit(p),
        fixture: bundle.teamById[p.team]?.fix.firstOrNull ?? '',
        points: p.next * (id == xi.captain ? 2 : 1),
        badge: id == xi.captain ? 'C' : id == xi.vice ? 'V' : null,
        width: w,
        label: label,
        onTap: () => onTap(p),
      );
    }

    return LayoutBuilder(builder: (context, c) {
      final w = ((c.maxWidth - 24) / 5 - 6).clamp(56.0, 88.0);
      Widget line(String pos) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              for (final id in xi.xi.where((i) => bundle.byId[i]!.pos == pos)) card(id, w),
            ]),
          );
      const benchLabels = ['GKP', '1.', '2.', '3.'];
      return Column(children: [
        ClipRect(child: CustomPaint(
          painter: _PitchPainter(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Column(children: [for (final pos in squadSlots.keys) line(pos)]),
          ),
        )),
        Container(
          color: _grassDark,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(6),
            ),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              for (final (i, id) in xi.bench.indexed) card(id, w, label: benchLabels[i]),
            ]),
          ),
        ),
      ]);
    });
  }
}

class _PlayerCard extends StatelessWidget {
  const _PlayerCard({required this.player, required this.kit, required this.fixture,
      required this.points, required this.badge, required this.width, required this.onTap,
      this.label});
  final FplPlayer player;
  final ClubColors kit;
  final String fixture;
  final double points;
  final String? badge, label;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final small = tt.labelSmall!.copyWith(color: TL.ink, height: 1.15);
    final flag = player.flagged;
    return Semantics(
      button: true,
      label: '${player.name}${badge == 'C' ? ', captain' : badge == 'V' ? ', vice-captain' : ''}'
          ', ${fixture.isEmpty ? 'no game' : fixture}, ${points.toStringAsFixed(1)} points',
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: width,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (label != null)
              Padding(padding: const EdgeInsets.only(bottom: 4),
                  child: Text(label!, style: small.copyWith(color: Colors.white,
                      fontWeight: FontWeight.w700))),
            Stack(clipBehavior: Clip.none, children: [
              SizedBox(width: width * 0.78, height: width * 0.78,
                  child: CustomPaint(painter: _ShirtPainter(kit))),
              if (badge != null)
                Positioned(left: -width * 0.14, top: 0, child: _Dot(badge!, TL.ink)),
              if (flag)
                Positioned(right: -width * 0.14, top: 0,
                    child: _Dot('!', player.status == 'd' ? TL.yellow : TL.red)),
            ]),
            const SizedBox(height: 2),
            Container(
              width: width,
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              child: Text(player.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: small.copyWith(fontWeight: FontWeight.w700)),
            ),
            Container(
              width: width,
              color: const Color(0xFFEDEDED),
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
              child: Text(fixture.isEmpty ? '—' : fixture, maxLines: 1,
                  overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: small),
            ),
            Container(
              width: width,
              color: TL.ink,
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Text(points.toStringAsFixed(1), textAlign: TextAlign.center,
                  style: tabular(small.copyWith(color: Colors.white,
                      fontWeight: FontWeight.w700))),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.text, this.color);
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 18,
        height: 18,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.5)),
        child: Text(text, textScaler: TextScaler.noScaling,
            style: TextStyle(color: onColor(color), fontSize: 10, fontWeight: FontWeight.w800)),
      );
}

/// A plain shirt: body in the club's first colour, sleeves and collar in its second.
class _ShirtPainter extends CustomPainter {
  _ShirtPainter(this.kit);
  final ClubColors kit;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100, size.height / 100);
    final body = Path()
      ..moveTo(36, 6)
      ..quadraticBezierTo(50, 18, 64, 6)
      ..lineTo(80, 12)
      ..lineTo(80, 98)
      ..lineTo(20, 98)
      ..lineTo(20, 12)
      ..close();
    Path sleeve(double s) => Path()
      ..moveTo(50 + 30 * s, 12)
      ..lineTo(50 + 48 * s, 34)
      ..lineTo(50 + 40 * s, 46)
      ..lineTo(50 + 30 * s, 38)
      ..close();
    final primary = Paint()..color = Color(kit.primary);
    final secondary = Paint()..color = Color(kit.secondary);
    final edge = Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final s in [-1.0, 1.0]) {
      canvas.drawPath(sleeve(s), secondary);
      canvas.drawPath(sleeve(s), edge);
    }
    canvas.drawPath(body, primary);
    canvas.drawPath(body, edge);
    canvas.drawPath(
        Path()
          ..moveTo(36, 6)
          ..quadraticBezierTo(50, 18, 64, 6),
        Paint()
          ..color = Color(kit.secondary)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4);
  }

  @override
  bool shouldRepaint(_ShirtPainter old) => old.kit != kit;
}

class _PitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    const bands = 8;
    for (var i = 0; i < bands; i++) {
      canvas.drawRect(Rect.fromLTWH(0, h * i / bands, w, h / bands + 1),
          Paint()..color = i.isEven ? _grass : _grassDark);
    }
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(Rect.fromLTWH(6, 0, w - 12, h + 10), line);
    canvas.drawRect(Rect.fromCenter(center: Offset(w / 2, 0), width: w * 0.56, height: h * 0.3),
        line);
    canvas.drawRect(Rect.fromCenter(center: Offset(w / 2, 0), width: w * 0.26, height: h * 0.12),
        line);
    canvas.drawLine(Offset(6, h * 0.82), Offset(w - 6, h * 0.82), line);
    canvas.drawCircle(Offset(w / 2, h * 0.82), h * 0.12, line);
  }

  @override
  bool shouldRepaint(_PitchPainter old) => false;
}
