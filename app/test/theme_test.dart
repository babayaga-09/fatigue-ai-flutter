import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchline/theme/theme.dart';
import 'package:touchline/theme/tokens.dart';

double contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  for (final b in Brightness.values) {
    test('$b: masthead roles are condensed black Archivo; text roles are not', () {
      final t = buildTheme(b).textTheme;
      for (final r in [t.displayLarge!, t.displaySmall!, t.headlineSmall!]) {
        expect(r.fontFamily, 'Archivo');
        expect(r.fontVariations, contains(const FontVariation('wdth', 62)));
        expect(r.fontWeight, FontWeight.w900);
      }
      expect(t.bodyMedium!.fontFamily, 'Archivo');
      expect(t.bodyMedium!.fontVariations, isNull);
    });

    test('$b: text contrast on the ground and on containers', () {
      final s = buildTheme(b).colorScheme;
      expect(contrast(s.onSurface, s.surface), greaterThanOrEqualTo(7));
      expect(contrast(s.onSurfaceVariant, s.surface), greaterThanOrEqualTo(4.5));
      expect(contrast(s.onSurfaceVariant, s.surfaceContainerLow), greaterThanOrEqualTo(4.5));
      expect(contrast(s.onPrimary, s.primary), greaterThanOrEqualTo(4.5));
      expect(contrast(s.onTertiaryContainer, s.tertiaryContainer), greaterThanOrEqualTo(4.5));
    });
  }

  for (final b in Brightness.values) {
    test('$b: selected nav icon is readable on the ink indicator', () {
      final t = buildTheme(b);
      final icon = t.navigationBarTheme.iconTheme!.resolve({WidgetState.selected})!.color!;
      expect(contrast(icon, t.navigationBarTheme.indicatorColor!), greaterThanOrEqualTo(4.5));
    });
  }

  test('onColor picks a readable ink for any club colour', () {
    for (final c in [Colors.white, const Color(0xFFFDE100), TL.red, TL.blue, TL.yellow, const Color(0xFF6CABDD),
        const Color(0xFFDB0007), Colors.black]) {
      expect(contrast(onColor(c), c), greaterThanOrEqualTo(3), reason: '$c');
    }
  });
}
