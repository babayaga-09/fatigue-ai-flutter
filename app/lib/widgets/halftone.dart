import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// One printed dot: centre in source-image pixels, radius in source pixels.
typedef Dot = ({double x, double y, double r});

/// Two-colour halftone screen of an RGBA image: one dot per [cell]-pixel square, its area
/// proportional to how much ink the square needs. Tones are stretched so the photo's darkest
/// and lightest areas use the full dot range (studio portraits are low-contrast). With [invert]
/// the dots carry the light tones instead, for light ink on a dark paper. Transparent squares
/// print nothing.
List<Dot> halftone(Uint8List rgba, int w, int h, double cell, {bool invert = false}) {
  final cells = <(double, double, double)>[]; // centre x, centre y, ink 0..1
  for (var j = 0; j * cell < h - 1e-6; j++) {
    final cy = j * cell;
    for (var k = 0; k * cell < w - 1e-6; k++) {
      final cx = k * cell;
      var dark = 0.0, light = 0.0, n = 0;
      final y1 = math.min(h, (cy + cell).ceil()), x1 = math.min(w, (cx + cell).ceil());
      for (var y = cy.floor(); y < y1; y++) {
        for (var x = cx.floor(); x < x1; x++) {
          final i = (y * w + x) * 4;
          final a = rgba[i + 3] / 255;
          final lum = (0.2126 * rgba[i] + 0.7152 * rgba[i + 1] + 0.0722 * rgba[i + 2]) / 255;
          dark += a * (1 - lum);
          light += a * lum;
          n++;
        }
      }
      if (n > 0) cells.add((cx + cell / 2, cy + cell / 2, (invert ? light : dark) / n));
    }
  }
  if (cells.isEmpty) return const [];
  final sorted = cells.map((c) => c.$3).toList()..sort();
  final lo = sorted[(sorted.length * 0.05).floor()];
  final hi = sorted[math.min(sorted.length - 1, (sorted.length * 0.98).floor())];
  final stretch = hi - lo >= 0.15;
  final maxR = cell * 0.52; // dots just touch: solids keep a sliver of paper and texture
  final dots = <Dot>[];
  for (final (x, y, v) in cells) {
    final t = stretch ? ((v - lo) / (hi - lo)).clamp(0.0, 1.0) : v;
    final r = maxR * math.sqrt(t);
    if (r >= cell * 0.08) dots.add((x: x, y: y, r: r));
  }
  return dots;
}

class _Screen {
  const _Screen(this.dots, this.width, this.height);
  final List<Dot> dots;
  final double width, height;
}

final _cache = <String, _Screen>{};
final _developed = <String>{};

/// A player photo printed as a two-colour halftone: [ink] dots on [paper], like a programme
/// cover. Falls back to the plain photo when its pixels can't be read (web without CORS), and to
/// [fallback] when there is no photo at all.
class HalftonePortrait extends StatefulWidget {
  const HalftonePortrait({super.key, required this.url, required this.ink,
      required this.paper, required this.fallback, this.columns = 30, this.semanticLabel});

  final String? url;
  final Color ink, paper;
  final Widget fallback;

  /// Dots across the image's width; fewer for small portraits so the dots stay printable.
  final int columns;
  final String? semanticLabel;

  @override
  State<HalftonePortrait> createState() => _HalftonePortraitState();
}

class _HalftonePortraitState extends State<HalftonePortrait>
    with SingleTickerProviderStateMixin {
  late final AnimationController _develop;
  _Screen? _screen;
  bool _plain = false, _failed = false;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  bool get _invert => widget.ink.computeLuminance() > widget.paper.computeLuminance();

  String get _key => '${widget.url}@${widget.columns}@$_invert';

  @override
  void initState() {
    super.initState();
    _develop = AnimationController(vsync: this, duration: const Duration(milliseconds: 500),
        value: 1);
    _load();
  }

  @override
  void didUpdateWidget(HalftonePortrait old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url || old.columns != widget.columns ||
        old.ink != widget.ink || old.paper != widget.paper) {
      _screen = null;
      _plain = _failed = false;
      _load();
    }
  }

  void _load() {
    _unlisten();
    final url = widget.url;
    if (url == null) return;
    final cached = _cache[_key];
    if (cached != null) {
      _screen = cached;
      return;
    }
    // a few pixels per dot is plenty; decoding smaller keeps the browser build quick
    _stream = ResizeImage(NetworkImage(url), width: widget.columns * 4,
            policy: ResizeImagePolicy.fit)
        .resolve(ImageConfiguration.empty);
    _listener = ImageStreamListener((info, _) {
      _onImage(info.image.clone()); // the listener owns info; keep our own handle
      info.dispose();
    },
        // the fetch itself failed (e.g. no CORS on web): let Image.network try, it falls
        // back to the initials when the photo really is missing
        onError: (_, _) => mounted ? setState(() => _plain = true) : null);
    _stream!.addListener(_listener!);
  }

  Future<void> _onImage(ui.Image image) async {
    final key = _key, columns = widget.columns, invert = _invert;
    try {
      final w = image.width, h = image.height;
      final ByteData? bytes;
      try {
        bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      } finally {
        image.dispose();
      }
      if (bytes == null) throw StateError('no pixels');
      final dots = await compute(_screenOf,
          (bytes.buffer.asUint8List(), w, h, w / columns, invert));
      final screen = _Screen(dots, w.toDouble(), h.toDouble());
      _cache[key] = screen;
      if (!mounted || key != _key) return;
      final animate = !_developed.contains(key) && !MediaQuery.disableAnimationsOf(context);
      _developed.add(key);
      setState(() => _screen = screen);
      if (animate) _develop.forward(from: 0);
    } catch (_) {
      if (mounted) setState(() => _plain = true); // pixels unreadable: show the photo itself
    }
  }

  void _unlisten() {
    if (_listener != null) _stream?.removeListener(_listener!);
    _stream = null;
    _listener = null;
  }

  @override
  void dispose() {
    _unlisten();
    _develop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.url;
    if (url == null || _failed) return widget.fallback;
    final Widget child;
    if (_screen != null) {
      child = AnimatedBuilder(
        animation: _develop,
        builder: (context, _) => CustomPaint(
          painter: _HalftonePainter(_screen!, widget.ink, widget.paper,
              Curves.easeOutExpo.transform(_develop.value)),
          size: Size.infinite,
        ),
      );
    } else if (_plain) {
      child = Image.network(url, fit: BoxFit.cover, alignment: Alignment.topCenter,
          webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
          errorBuilder: (context, error, stack) => widget.fallback);
    } else {
      child = ColoredBox(color: widget.paper);
    }
    return Semantics(image: true, label: widget.semanticLabel,
        child: ExcludeSemantics(child: child));
  }
}

List<Dot> _screenOf((Uint8List, int, int, double, bool) a) =>
    halftone(a.$1, a.$2, a.$3, a.$4, invert: a.$5);

class _HalftonePainter extends CustomPainter {
  _HalftonePainter(this.screen, this.ink, this.paper, this.t);
  final _Screen screen;
  final Color ink, paper;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = paper);
    // cover-fit, anchored to the top so faces stay in frame
    final s = math.max(size.width / screen.width, size.height / screen.height);
    final dx = (size.width - screen.width * s) / 2;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final p = Paint()..color = ink..isAntiAlias = true;
    for (final d in screen.dots) {
      canvas.drawCircle(Offset(dx + d.x * s, d.y * s), d.r * s * t, p);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HalftonePainter old) =>
      old.t != t || old.screen != screen || old.ink != ink || old.paper != paper;
}
