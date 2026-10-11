import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchline/data/bundle.dart';
import 'package:touchline/format.dart';

import 'helpers.dart';

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
    expect(b.prospects, isNotEmpty);
    expect(b.managers, isNotEmpty);
    expect(b.players.where((p) => p.career != null).every((p) => p.qualified), isTrue);
    expect(b.players.any((p) => p.dependency != null), isTrue);
    expect(b.prospectsByPrice, isTrue);
    expect(b.bounce, isNotNull);
  });

  test('v1 bundles without the v2 keys still load', () {
    final b = Bundle.fromJson(minimalBundleJson());
    expect(b.prospects, isEmpty);
    expect(b.managers, isEmpty);
    expect(b.playerById[7]!.career, isNull);
    expect(b.playerById[7]!.dependency, isNull);
    expect(b.bounce, isNull);
    expect(b.managerSplitHalf, isNull);
  });

  test('parses the v2 keys', () {
    final j = minimalBundleJson();
    (j['players'] as List).first
      ..['dependency'] = {'index': 0.41, 'played': 28, 'missed': 6}
      ..['career'] = {
        'seasons': ['2026/27', '2027/28', '2028/29'],
        'p10': [1, 2, 3], 'p50': [4, 5, 6], 'p90': [7, 8, 9],
        'peak_value': 6, 'peak_age': 26.3, 'vs_curve': 'ahead',
      };
    j['prospects'] = [
      {'id': 1, 'name': 'Kid', 'img': null, 'club_name': 'PSV', 'league': 'NL1',
       'league_name': 'Eredivisie', 'pos': 'Attack', 'age': 20.5, 'market_value': 9000000,
       'ga90': 0.6, 'translated_ga90': 0.4, 'p_regular': 0.55, 'why': []}
    ];
    j['managers'] = [
      {'name': 'Boss', 'club': 11, 'league': 'GB1', 'games': 120, 'since': '2023-07-01',
       'pae': 0.1, 'pae_raw': 0.2, 'per38': 3.8, 'first10': null}
    ];
    j['models'] = {
      'prospects': {'chosen': 'value_only', 'auc': 0.56, 'baseline_auc': 0.6},
      'manager_effect': {'reliability': null, 'split_half_r': -0.1, 'bounce': {
        'n_changes': 103, 'last10_before': -0.35, 'first10': 0.22, 'next20': null,
        'control_next10': 0.2}},
    };
    final b = Bundle.fromJson(j);
    final p = b.playerById[7]!;
    expect(p.dependency!.missed, 6);
    expect(p.career!.p50, [4, 5, 6]);
    expect(p.career!.vsCurve, 'ahead');
    expect(b.prospects.single.translatedGa90, 0.4);
    expect(b.managers.single.first10, isNull);
    expect(b.managerByClub[11]!.name, 'Boss');
    expect(b.prospectsByPrice, isTrue);
    expect(b.bounce!.first10, 0.22);
    expect(b.bounce!.next20, isNull);
    expect(b.bounce!.control, 0.2);
    expect(b.managerSplitHalf, -0.1);
  });

  test('a malformed career block is dropped, not drawn', () {
    for (final bad in [
      {'seasons': <String>[], 'p10': [], 'p50': [], 'p90': [], 'peak_value': 1,
       'peak_age': 25.0, 'vs_curve': 'on'},
      {'seasons': ['2026/27'], 'p10': [1], 'p50': [2], 'p90': <int>[], 'peak_value': 1,
       'peak_age': 25.0, 'vs_curve': 'on'},
      {'seasons': ['next year'], 'p10': [1], 'p50': [2], 'p90': [3], 'peak_value': 1,
       'peak_age': 25.0, 'vs_curve': 'on'},
    ]) {
      final j = minimalBundleJson();
      (j['players'] as List).first['career'] = bad;
      expect(Bundle.fromJson(j).playerById[7]!.career, isNull, reason: '$bad');
    }
  });

  test('extreme shares never print as certainties', () {
    expect(pct(0.996), '>99%');
    expect(pct(0.003), '<1%');
    expect(pct(1.0), '100%');
    expect(pct(0.0), '0%');
  });
}
