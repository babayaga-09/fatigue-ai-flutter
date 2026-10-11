import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchline/data/bundle.dart';

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

void main() {
  test('parses a minimal bundle and keeps nulls as nulls', () {
    final b = Bundle.fromJson(minimalBundleJson());
    final p = b.playerById[7]!;
    expect(p.fairValue, isNull);
    expect(p.forecastGa5, isNull);
    expect(p.workload, isNull);
    expect(p.trendScore, isNull);
    expect(p.qualified, isFalse);
    expect(b.clubById[11]!.colors!.primary, 0xFFDB0007);
    expect(b.clubById[11]!.proj, isNull);
    expect(b.fixtures.single.finished, isFalse);
    expect(b.fixtures.single.kickoff.isUtc, isTrue);
  });

  test('rejects other schema versions', () {
    final j = minimalBundleJson()..['schema_version'] = 2;
    expect(() => Bundle.fromJson(j), throwsA(isA<UnsupportedBundleError>()));
  });

  test('parseHexColor', () {
    expect(parseHexColor('#0F3D2E'), 0xFF0F3D2E);
    expect(parseHexColor('nope'), isNull);
    expect(parseHexColor(null), isNull);
  });

  test('parses the real frozen bundle', () {
    final raw = const GZipDecoder().decodeBytes(File('test/fixtures/bundle.json.gz').readAsBytesSync());
    final b = Bundle.fromJson(jsonDecode(utf8.decode(raw)) as Map<String, dynamic>);
    expect(b.clubs.length, 96);
    expect(b.players.length, greaterThan(2000));
    expect(b.players.where((p) => !p.qualified).every((p) => p.fairValue == null), isTrue);
    expect(b.leagues.map((l) => l.id), containsAll(['GB1', 'ES1', 'L1', 'IT1', 'FR1']));
  });
}
