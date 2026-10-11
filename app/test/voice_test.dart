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

  test('bounce verdict follows the interval, not a hunch', () {
    Bounce b(List<double>? ci) => Bounce(changes: 271, before: -0.36, first10: 0.06,
        next20: 0.17, control: 0.0, gapCi: ci);
    expect(bounceVerdict(b([-0.05, 0.17])), contains('within the noise'));
    expect(bounceVerdict(b([0.01, 0.12])), contains('small real edge'));
    expect(bounceVerdict(b(null)), contains('drifting back'));
  });

  test('manager trust is graded by the split-half correlation', () {
    expect(managerTrust(-0.1), startsWith('Mostly luck:'));
    expect(managerTrust(0.14), contains('some skill'));
    expect(managerTrust(0.5), startsWith('A real but noisy'));
  });

  test('signed numbers never print a minus zero', () {
    expect(signed(-0.0008, digits: 2), '0.00');
    expect(signed(0.06, digits: 2), '+0.06');
    expect(signed(-0.36, digits: 2), '−0.36');
  });
}
