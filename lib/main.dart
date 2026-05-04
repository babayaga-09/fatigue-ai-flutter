import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/home_screen.dart';

void main() => runApp(const FatigueApp());

class FatigueApp extends StatefulWidget {
  const FatigueApp({super.key});
  static _FatigueAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_FatigueAppState>()!;
  @override
  State<FatigueApp> createState() => _FatigueAppState();
}

class _FatigueAppState extends State<FatigueApp> {
  bool _isDark = true;
  void toggleTheme() => setState(() => _isDark = !_isDark);
  bool get isDark => _isDark;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fatigue AI',
      debugShowCheckedModeBanner: false,
      theme: _isDark ? _darkTheme() : _lightTheme(),
      home: const HomeScreen(),
    );
  }

  ThemeData _darkTheme() => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF080C14),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
          secondary: Color(0xFF7C4DFF),
          surface: Color(0xFF0F1623),
        ),
        textTheme:
            GoogleFonts.dmSansTextTheme(ThemeData.dark().textTheme),
      );

  ThemeData _lightTheme() => ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF0F4FF),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF0077AA),
          secondary: Color(0xFF5C35CC),
          surface: Color(0xFFFFFFFF),
        ),
        textTheme:
            GoogleFonts.dmSansTextTheme(ThemeData.light().textTheme),
      );
}