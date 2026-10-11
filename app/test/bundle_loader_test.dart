import 'package:flutter_test/flutter_test.dart';
import 'package:touchline/data/bundle.dart';
import 'package:touchline/data/bundle_loader.dart';

import 'helpers.dart';

Map<String, dynamic> _at(String generatedAt, {int schema = 1}) =>
    minimalBundleJson()
      ..['generated_at'] = generatedAt
      ..['schema_version'] = schema;

void main() {
  final seed = gz(_at('2026-10-01T00:00:00Z'));
  final cache = gz(_at('2026-10-03T00:00:00Z'));

  test('valid cache wins over seed', () async {
    final r = await loadLocal(BundleIo(readSeed: () async => seed, readCache: () async => cache));
    expect(r.origin, BundleOrigin.cache);
    expect(r.bundle.generatedAt, DateTime.utc(2026, 10, 3));
  });

  test('corrupt or unsupported cache falls back to seed', () async {
    for (final bad in [
      [1, 2, 3],
      gz(_at('2026-10-09T00:00:00Z', schema: 2)),
    ]) {
      final r = await loadLocal(BundleIo(readSeed: () async => seed, readCache: () async => bad));
      expect(r.origin, BundleOrigin.seed);
    }
  });

  test('missing cache falls back to seed', () async {
    final r = await loadLocal(BundleIo(readSeed: () async => seed, readCache: () async => null));
    expect(r.origin, BundleOrigin.seed);
  });

  group('fetchNewer', () {
    final current = Bundle.fromJson(_at('2026-10-03T00:00:00Z'));

    test('newer bundle is returned and cached', () async {
      List<int>? written;
      final r = await fetchNewer(
          BundleIo(readSeed: () async => seed,
              fetchRemote: () async => gz(_at('2026-10-10T00:00:00Z')),
              writeCache: (b) async => written = b),
          current);
      expect(r.reachable, isTrue);
      expect(r.bundle!.generatedAt, DateTime.utc(2026, 10, 10));
      expect(written, isNotNull);
    });

    test('same or older bundle: reachable, nothing to swap', () async {
      final r = await fetchNewer(
          BundleIo(readSeed: () async => seed, fetchRemote: () async => cache), current);
      expect(r.reachable, isTrue);
      expect(r.bundle, isNull);
    });

    test('unsupported schema from network is ignored and not cached', () async {
      var wrote = false;
      final r = await fetchNewer(
          BundleIo(readSeed: () async => seed,
              fetchRemote: () async => gz(_at('2026-10-10T00:00:00Z', schema: 2)),
              writeCache: (_) async => wrote = true),
          current);
      expect(r.bundle, isNull);
      expect(wrote, isFalse);
      expect(r.needsAppUpdate, isTrue);
    });

    test('network failure or no remote configured: unreachable', () async {
      final failing = await fetchNewer(
          BundleIo(readSeed: () async => seed, fetchRemote: () async => throw Exception('x')),
          current);
      expect(failing.reachable, isFalse);
      final none = await fetchNewer(BundleIo(readSeed: () async => seed), current);
      expect(none.reachable, isFalse);
    });
  });
}
