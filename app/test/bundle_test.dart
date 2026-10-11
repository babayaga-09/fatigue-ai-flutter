import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchline/data/bundle.dart';

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
  });
}
