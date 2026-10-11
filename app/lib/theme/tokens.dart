import 'package:flutter/material.dart';

/// Touchline's programme stock: white coated paper, ink, and three printing colours.
abstract final class TL {
  static const stock = Color(0xFFFFFFFF);
  static const ink = Color(0xFF111111);

  /// Turnstile red: Touchline's own colour when no club is in focus.
  static const red = Color(0xFFD7262D);
  static const blue = Color(0xFF1D3C8F);

  /// Sponsor-strip yellow: printed strips and highlights only.
  static const yellow = Color(0xFFF2C200);

  /// Used when a club has no known colours.
  static const neutralA = Color(0xFF4A4A4A);
  static const neutralB = Color(0xFFE4E4E4);
}

/// Ink that reads on top of [c] (white on dark colours, near-black on light ones).
Color onColor(Color c) => c.computeLuminance() > 0.36 ? TL.ink : Colors.white;
