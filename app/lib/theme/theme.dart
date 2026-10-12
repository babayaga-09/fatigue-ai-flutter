import 'package:flutter/material.dart';

import 'tokens.dart';

TextStyle tabular(TextStyle s) =>
    s.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

/// Programme masthead lettering: Archivo at its narrowest width and heaviest weight.
/// Set it on upper-case strings (see [Masthead]).
TextStyle masthead(double size, Color color) => TextStyle(
    fontFamily: 'Archivo', fontSize: size, height: 0.92, fontWeight: FontWeight.w900,
    letterSpacing: 0, color: color,
    fontVariations: const [FontVariation('wdth', 62), FontVariation('wght', 900)],
    fontFeatures: const [FontFeature.tabularFigures()]);

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final ground = dark ? TL.ink : TL.stock;
  final onGround = dark ? const Color(0xFFF2F2F2) : TL.ink;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: dark ? const Color(0xFFFF8A84) : TL.red,
    onPrimary: dark ? TL.ink : Colors.white,
    primaryContainer: dark ? const Color(0xFF5C1013) : const Color(0xFFFBE3E4),
    onPrimaryContainer: dark ? const Color(0xFFFFDAD8) : const Color(0xFF5C1013),
    secondary: dark ? const Color(0xFFA9BDFF) : TL.blue,
    onSecondary: dark ? TL.ink : Colors.white,
    secondaryContainer: dark ? const Color(0xFF1D3C8F) : const Color(0xFFE2E8F8),
    onSecondaryContainer: dark ? Colors.white : const Color(0xFF0E1E4A),
    tertiary: dark ? TL.yellow : const Color(0xFF6B5500),
    onTertiary: TL.ink,
    tertiaryContainer: TL.yellow,
    onTertiaryContainer: TL.ink,
    error: dark ? const Color(0xFFFF8A84) : const Color(0xFFB3261E),
    onError: dark ? TL.ink : Colors.white,
    surface: ground,
    onSurface: onGround,
    onSurfaceVariant: dark ? const Color(0xFFB8B8B8) : const Color(0xFF4D4D4D),
    surfaceContainerLowest: dark ? const Color(0xFF0A0A0A) : Colors.white,
    surfaceContainerLow: dark ? const Color(0xFF1A1A1A) : const Color(0xFFF4F4F3),
    surfaceContainer: dark ? const Color(0xFF202020) : const Color(0xFFEDEDEC),
    surfaceContainerHigh: dark ? const Color(0xFF292929) : const Color(0xFFE5E5E4),
    surfaceContainerHighest: dark ? const Color(0xFF333333) : const Color(0xFFDCDCDB),
    outline: dark ? const Color(0xFF8C8C8C) : const Color(0xFF6E6E6E),
    outlineVariant: dark ? const Color(0xFF3A3A3A) : const Color(0xFFD4D4D3),
    inverseSurface: onGround,
    onInverseSurface: ground,
  );
  final base = ThemeData(colorScheme: scheme, useMaterial3: true, fontFamily: 'Archivo');
  final tt = base.textTheme;
  final sharp = RoundedRectangleBorder(borderRadius: BorderRadius.circular(2));

  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    textTheme: tt.copyWith(
      displayLarge: masthead(56, scheme.onSurface),
      displayMedium: masthead(44, scheme.onSurface),
      displaySmall: masthead(34, scheme.onSurface),
      headlineSmall: masthead(24, scheme.onSurface),
      titleLarge: tt.titleLarge!.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.2),
      titleMedium: tt.titleMedium!.copyWith(fontWeight: FontWeight.w700),
      titleSmall: tabular(tt.titleSmall!.copyWith(fontWeight: FontWeight.w700)),
      labelLarge: tabular(tt.labelLarge!.copyWith(fontWeight: FontWeight.w700)),
      labelMedium: tabular(tt.labelMedium!),
      labelSmall: tabular(tt.labelSmall!.copyWith(fontWeight: FontWeight.w600)),
      bodyMedium: tt.bodyMedium!.copyWith(height: 1.4),
    ),
    appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface, foregroundColor: scheme.onSurface, elevation: 0,
        scrolledUnderElevation: 0, centerTitle: false,
        shape: Border(bottom: BorderSide(color: scheme.onSurface, width: 2))),
    cardTheme: CardThemeData(
        elevation: 0, color: scheme.surfaceContainerLow, margin: EdgeInsets.zero, shape: sharp),
    navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface, indicatorColor: scheme.onSurface, elevation: 0,
        indicatorShape: sharp,
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.surface : scheme.onSurfaceVariant)),
        labelTextStyle: WidgetStatePropertyAll(
            tt.labelMedium!.copyWith(fontWeight: FontWeight.w700))),
    navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surface, indicatorColor: scheme.onSurface,
        indicatorShape: sharp,
        selectedIconTheme: IconThemeData(color: scheme.surface)),
    chipTheme: ChipThemeData(
        shape: sharp,
        selectedColor: scheme.onSurface,
        secondaryLabelStyle: TextStyle(color: scheme.surface, fontWeight: FontWeight.w700),
        side: BorderSide(color: scheme.outline),
        showCheckmark: false),
    segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(sharp),
          backgroundColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected) ? scheme.onSurface : null),
          foregroundColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected) ? scheme.surface : scheme.onSurface),
        )),
    filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(shape: sharp, backgroundColor: scheme.onSurface,
            foregroundColor: scheme.surface)),
    outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(shape: sharp,
            side: BorderSide(color: scheme.onSurface, width: 1.5))),
    inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(2)))),
    bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface, showDragHandle: true, elevation: 1,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(4)))),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1, thickness: 1),
    textSelectionTheme: TextSelectionThemeData(
        selectionColor: TL.yellow.withValues(alpha: 0.6), cursorColor: scheme.primary,
        selectionHandleColor: scheme.primary),
    scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(scheme.outline.withValues(alpha: 0.6)),
        thickness: const WidgetStatePropertyAll(4), radius: Radius.zero),
  );
}
