import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/bundle.dart';
import '../state/app_state.dart';
import '../theme/theme.dart';
import '../theme/tokens.dart';
import 'crest.dart';
import 'halftone.dart';
import 'print.dart';

/// Ink and paper for a club's halftone: the darker colour prints on the lighter one; plain
/// stock when the pair is too close to read.
(Color, Color) portraitInks(Club? club) {
  final c = clubColors(club);
  final dark = c[0].computeLuminance() <= c[1].computeLuminance() ? c[0] : c[1];
  final light = dark == c[0] ? c[1] : c[0];
  final ratio = (light.computeLuminance() + 0.05) / (dark.computeLuminance() + 0.05);
  return (dark, ratio < 2.2 ? TL.stock : light);
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Ink for a portrait printed straight onto a club-coloured [field]: the club's other colour
/// when it reads on the field, otherwise black or white, whichever reads better.
Color inkOnField(Club? club, Color field) {
  final other = clubColors(club).firstWhere((c) => c != field, orElse: () => TL.ink);
  if (_contrast(other, field) >= 3) return other;
  return _contrast(TL.ink, field) >= _contrast(Colors.white, field) ? TL.ink : Colors.white;
}

/// A player's portrait printed as a halftone in his club's colours (3:4).
class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({super.key, required this.player, this.size = 56, this.club,
      this.field});

  final Player player;

  /// Width; height is 4:3 of it (Transfermarkt portraits are 3:4).
  final double size;

  /// The club whose colours print the portrait; looked up from the bundle when null.
  final Club? club;

  /// Print straight onto this colour (the cover's club field) instead of the club's paper.
  final Color? field;

  @override
  Widget build(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    final c = club ?? (player.club == null ? null
        : scope?.notifier?.bundle?.clubById[player.club]);
    final (ink, paper) = field == null ? portraitInks(c) : (inkOnField(c, field!), field!);
    return SizedBox(
      width: size,
      height: size * 4 / 3,
      child: HalftonePortrait(
        url: player.img,
        ink: ink,
        paper: paper,
        columns: (size / 3).round().clamp(14, 44),
        semanticLabel: player.name,
        fallback: Container(
          key: const ValueKey('initials'),
          color: paper,
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Text(initials(player.name), style: masthead(size * 0.42, ink)),
            ),
          ),
        ),
      ),
    );
  }
}
