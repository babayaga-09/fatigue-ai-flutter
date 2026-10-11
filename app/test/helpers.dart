import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchline/data/bundle.dart';
import 'package:touchline/state/app_state.dart';
import 'package:touchline/theme/theme.dart';

Map<String, dynamic> minimalBundleJson() => {
      'schema_version': 1,
      'generated_at': '2026-10-04T06:00:00Z',
      'data_through': {'players': '2026-06-28', 'clubs': '2026-10-03'},
      'player_season': '2025/26',
      'leagues': [
        {'id': 'GB1', 'fd': 'PL', 'name': 'Premier League'}
      ],
      'clubs': [
        {
          'id': 11, 'name': 'Arsenal', 'crest': null, 'league': 'GB1', 'elo': 1912.4,
          'elo_change_30d': 14.2, 'form': ['W', 'D'], 'colors': ['#DB0007', '#FFFFFF'],
          'table': {'pos': 1, 'played': 7, 'points': 19, 'gd': 12, 'gf': 15, 'ga': 3},
          'proj': null,
        }
      ],
      'fixtures': [
        {
          'id': 5, 'league': 'GB1', 'kickoff': '2026-10-10T14:00:00Z', 'home': 11,
          'away': -1076, 'status': 'TIMED', 'score': null, 'p': [0.7, 0.2, 0.1],
          'xg': [1.9, 0.8],
        }
      ],
      'players': [
        {
          'id': 7, 'name': 'Young Sub', 'img': null, 'club': 11, 'club_name': 'Arsenal FC',
          'league': 'GB1', 'pos': 'Attack', 'sub_pos': null, 'age': null, 'nat': null,
          'foot': null, 'height': null, 'market_value': 500000, 'fair_value': null,
          'value_gap_pct': null, 'value_why': null,
          'season': {'apps': 3, 'minutes': 120, 'goals': 0, 'assists': 0, 'ga90': 0.0},
          'form': {'last5': [], 'forecast_ga5': null}, 'workload': null,
          'value_history': [], 'transfers': [], 'similar': [],
          'trend': {'score': null, 'reasons': []},
        }
      ],
      'models': {'club_elo': {'favourite_accuracy': 0.689}},
    };

List<int> gz(Map<String, dynamic> json) => const GZipEncoder().encode(utf8.encode(jsonEncode(json)));

Bundle? _fixture;

/// The frozen real bundle (test/fixtures/bundle.json.gz), parsed once per test run.
Bundle fixtureBundle() => _fixture ??= Bundle.fromJson(jsonDecode(utf8.decode(
    const GZipDecoder().decodeBytes(File('test/fixtures/bundle.json.gz').readAsBytesSync())))
    as Map<String, dynamic>);

/// "Now" for widget tests: the frozen bundle's own generation time, inside its fixture window.
DateTime get fixtureNow => fixtureBundle().generatedAt;

Future<AppState> pumpApp(WidgetTester tester, Widget child,
    {AppState? state, Brightness brightness = Brightness.light}) async {
  final s = state ?? AppState.preloaded(fixtureBundle(), clock: () => fixtureNow);
  await tester.pumpWidget(AppScope(
      state: s,
      child: MaterialApp(theme: buildTheme(brightness), home: child)));
  await tester.pump(const Duration(milliseconds: 800));
  return s;
}
