import 'package:flutter/material.dart';

import 'tokens.dart';

/// Font size at which one Jersey stitch is one logical pixel (cap height = 10 stitches).
const stitchUnit = 18.6667;

TextStyle tabular(TextStyle s) =>
    s.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final seeded = ColorScheme.fromSeed(
      seedColor: TL.pitch, brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity);
  final scheme = seeded.copyWith(
    primary: dark ? const Color(0xFF8FD6AE) : TL.pitch,
    onPrimary: dark ? const Color(0xFF003920) : Colors.white,
    primaryContainer: dark ? const Color(0xFF1C4A39) : const Color(0xFFCDE9D9),
    onPrimaryContainer: dark ? const Color(0xFFCDE9D9) : TL.pitch,
    tertiary: dark ? TL.pink : const Color(0xFF8E3B5E),
    onTertiary: dark ? TL.ink : Colors.white,
    tertiaryContainer: TL.pink,
    onTertiaryContainer: TL.ink,
    surface: dark ? TL.nightGround : TL.concrete,
    onSurface: dark ? const Color(0xFFE6E8E3) : TL.ink,
    onSurfaceVariant: dark ? const Color(0xFFA9B1AC) : const Color(0xFF4A4F57),
    surfaceContainerLowest: dark ? const Color(0xFF0A0F0D) : const Color(0xFFFAFAF7),
    surfaceContainerLow: dark ? const Color(0xFF141B18) : const Color(0xFFF6F6F2),
    surfaceContainer: dark ? const Color(0xFF18201C) : const Color(0xFFE6E6E0),
    surfaceContainerHigh: dark ? const Color(0xFF1F2824) : const Color(0xFFDEDED8),
    surfaceContainerHighest: dark ? const Color(0xFF27312C) : const Color(0xFFD6D6D0),
    outline: dark ? const Color(0xFF8A918C) : const Color(0xFF767C85),
    outlineVariant: dark ? const Color(0xFF2E3833) : const Color(0xFFC9CBC6),
  );
  final base = ThemeData(colorScheme: scheme, useMaterial3: true);
  final tt = base.textTheme;

  TextStyle stitch(double size) => TextStyle(
      fontFamily: 'Jersey', fontSize: size, height: 1.0, letterSpacing: 0,
      color: scheme.onSurface, fontFeatures: const [FontFeature.tabularFigures()]);

  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    textTheme: tt.copyWith(
      displayLarge: stitch(stitchUnit * 3),
      displaySmall: stitch(stitchUnit * 2),
      headlineSmall: stitch(stitchUnit),
      titleLarge: tt.titleLarge!.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.2),
      titleMedium: tt.titleMedium!.copyWith(fontWeight: FontWeight.w600),
      labelLarge: tabular(tt.labelLarge!),
      labelMedium: tabular(tt.labelMedium!),
      bodyMedium: tt.bodyMedium!.copyWith(height: 1.4),
    ),
    appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface, foregroundColor: scheme.onSurface, elevation: 0,
        scrolledUnderElevation: 0, centerTitle: false),
    cardTheme: CardThemeData(
        elevation: 0, color: scheme.surfaceContainerLow, margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
    navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainer, indicatorColor: scheme.tertiaryContainer,
        elevation: 0),
    navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surfaceContainer, indicatorColor: scheme.tertiaryContainer),
    chipTheme: ChipThemeData(
        selectedColor: scheme.primary,
        secondaryLabelStyle: TextStyle(color: scheme.onPrimary, fontWeight: FontWeight.w600),
        side: BorderSide(color: scheme.outlineVariant),
        showCheckmark: false),
    bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow, showDragHandle: true, elevation: 1),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1, thickness: 1),
    textSelectionTheme: TextSelectionThemeData(
        selectionColor: TL.pink.withValues(alpha: 0.55), cursorColor: scheme.primary,
        selectionHandleColor: scheme.primary),
    scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(scheme.outline.withValues(alpha: 0.6)),
        thickness: const WidgetStatePropertyAll(6), radius: const Radius.circular(8)),
  );
}
