import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('seed and fixture bundles are schema-1 gzip JSON with club colours', () {
    for (final path in ['assets/data/touchline-bundle.json.gz', 'test/fixtures/bundle.json.gz']) {
      final raw = const GZipDecoder().decodeBytes(File(path).readAsBytesSync());
      final j = jsonDecode(utf8.decode(raw)) as Map<String, dynamic>;
      expect(j['schema_version'], 1, reason: path);
      expect((j['clubs'] as List).every((c) => (c as Map)['colors'] != null), isTrue,
          reason: path);
    }
  });

  test('budget golden cases exist', () {
    final cases = jsonDecode(File('test/fixtures/budget_cases.json').readAsStringSync()) as List;
    expect(cases, hasLength(3));
  });
}
