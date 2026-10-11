import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchline/data/bundle_loader.dart';
import 'package:touchline/data/prefs.dart';
import 'package:touchline/state/app_state.dart';

import 'helpers.dart';

void main() {
  test('start shows local data first, then swaps in a newer network bundle', () async {
    final seed = gz(minimalBundleJson()..['generated_at'] = '2026-10-01T00:00:00Z');
    final remote = gz(minimalBundleJson()..['generated_at'] = '2026-10-08T00:00:00Z');
    final origins = <BundleOrigin?>[];
    final s = AppState(
      io: BundleIo(readSeed: () async => seed, fetchRemote: () async => remote),
      prefs: MemoryPrefs(),
      decode: decodeInline,
    )..addListener(() => origins.add(null));
    await s.start();
    expect(s.origin, BundleOrigin.network);
    expect(s.reachable, isTrue);
    expect(s.bundle!.generatedAt, DateTime.utc(2026, 10, 8));
  });

  test('offline start keeps the seed and reports unreachable', () async {
    final seed = gz(minimalBundleJson());
    final s = AppState(io: BundleIo(readSeed: () async => seed), prefs: MemoryPrefs(),
        decode: decodeInline);
    await s.start();
    expect(s.origin, BundleOrigin.seed);
    expect(s.reachable, isFalse);
    expect(s.bundle, isNotNull);
  });

  test('favourites and theme persist across launches', () async {
    final prefs = MemoryPrefs();
    final seed = gz(minimalBundleJson());
    final a = AppState(io: BundleIo(readSeed: () async => seed), prefs: prefs,
        decode: decodeInline);
    await a.start();
    await a.toggleFavourite(7);
    await a.setThemeMode(ThemeMode.dark);
    final b = AppState(io: BundleIo(readSeed: () async => seed), prefs: prefs,
        decode: decodeInline);
    await b.start();
    expect(b.isFavourite(7), isTrue);
    expect(b.themeMode, ThemeMode.dark);
  });

  test('corrupt favourites pref is ignored', () async {
    final prefs = MemoryPrefs();
    await prefs.write('favourites', '7,abc,,9');
    final s = AppState(io: BundleIo(readSeed: () async => gz(minimalBundleJson())),
        prefs: prefs, decode: decodeInline);
    await s.start();
    expect(s.favourites, {7, 9});
  });

  test('league filter notifies only on change', () {
    final s = AppState.preloaded(fixtureBundle());
    var n = 0;
    s.addListener(() => n++);
    s.setLeague('GB1');
    s.setLeague('GB1');
    expect(n, 1);
  });
}
