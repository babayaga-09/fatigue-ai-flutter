import 'package:flutter/material.dart';

/// Touchline's scarf: pitch green and paper pink, on terrace concrete.
abstract final class TL {
  static const pitch = Color(0xFF0F3D2E);
  static const pink = Color(0xFFF2A7C3);
  static const concrete = Color(0xFFEDEDE8);
  static const nightGround = Color(0xFF0D1311);
  static const ink = Color(0xFF16181D);
  static const win = Color(0xFF1E7A46);
  static const draw = Color(0xFF7D838C);
  static const loss = Color(0xFFC8102E);

  /// Used when a club has no known colours.
  static const neutralA = Color(0xFF5C6670);
  static const neutralB = Color(0xFFD9DCE0);
}

/// Ink that reads on top of [c] (white on dark colours, near-black on light ones).
Color onColor(Color c) => c.computeLuminance() > 0.36 ? TL.ink : Colors.white;
