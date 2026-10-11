import 'package:flutter_test/flutter_test.dart';
import 'package:touchline/copy/voice.dart';
import 'package:touchline/data/bundle.dart';

import 'helpers.dart';

void main() {
  test('fixture verdicts scale with confidence', () {
    expect(fixtureVerdict('Arsenal', 'Leeds', [0.71, 0.18, 0.11]),
        'Arsenal should handle this. Leeds need a miracle.');
    expect(fixtureVerdict('A', 'B', [0.55, 0.25, 0.20]), 'A are favourites, not certainties.');
    expect(fixtureVerdict('A', 'B', [0.36, 0.30, 0.34]), 'Too close to call. Expect nerves.');
    expect(fixtureVerdict('A', 'B', [0.20, 0.25, 0.55]), 'B are favourites, not certainties.');
  });

  test('form and workload', () {
    expect(formVerdict(['W', 'W', 'W', 'W', 'W']), 'Five from five. Somebody stop them.');
    expect(formVerdict(['L', 'L', 'L', 'D', 'L']), 'Grim viewing.');
    expect(formVerdict([]), 'No games yet.');
    expect(workloadVerdict('Heavy'), 'Legs are being asked a lot.');
    expect(workloadVerdict('Light'), 'Fresh legs.');
  });

  test('player verdict never judges an unqualified player', () {
    final p = Bundle.fromJson(minimalBundleJson()).playerById[7]!;
    expect(playerVerdict(p), 'Not enough minutes yet to judge.');
  });

  test('real players get a verdict line', () {
    for (final p in fixtureBundle().players.where((p) => p.qualified).take(200)) {
      expect(playerVerdict(p), isNotEmpty);
    }
  });
}
