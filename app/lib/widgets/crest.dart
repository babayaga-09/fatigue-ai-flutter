import 'package:flutter/material.dart';

import '../data/bundle.dart';
import '../theme/theme.dart';
import '../theme/tokens.dart';
import 'print.dart';

/// First letters of up to two capitalised words: "Borussia Dortmund" -> "BD".
String initials(String name) {
  final words = name.split(RegExp(r'[\s.\-]+')).where((w) => w.isNotEmpty).toList();
  final caps = words.where((w) => w[0] != w[0].toLowerCase()).toList();
  final pick = (caps.isEmpty ? words : caps).take(2);
  return pick.isEmpty ? '?' : pick.map((w) => w[0]).join().toUpperCase();
}

class Crest extends StatelessWidget {
  const Crest({super.key, required this.club, this.size = 32});

  final Club? club;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = club;
    final fallback = _Monogram(club: c, size: size);
    if (c?.crest == null) return fallback;
    return Image.network(
      c!.crest!,
      width: size,
      height: size,
      fit: BoxFit.contain,
      semanticLabel: '${c.name} crest',
      webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
      errorBuilder: (context, error, stack) => fallback,
    );
  }
}

class _Monogram extends StatelessWidget {
  const _Monogram({required this.club, required this.size});

  final Club? club;
  final double size;

  @override
  Widget build(BuildContext context) {
    final bg = clubColors(club).first;
    return Container(
      key: const ValueKey('monogram'),
      width: size,
      height: size,
      alignment: Alignment.center,
      color: bg,
      child: Text(initials(club?.name ?? '?'), style: masthead(size * 0.5, onColor(bg))),
    );
  }
}
