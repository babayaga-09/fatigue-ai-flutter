import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchline/data/bundle.dart';
import 'package:touchline/screens/clubs_screen.dart';
import 'package:touchline/state/app_state.dart';

import 'helpers.dart';

void main() {
  testWidgets('table then odds for the selected league', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 2400));
    await pumpApp(tester, const ClubsScreen());
    expect(find.text('Pts'), findsOneWidget);
    final pl = fixtureBundle().clubs.where((c) => c.league == 'GB1').length;
    expect(find.byType(InkWell), findsAtLeastNWidgets(pl));
    await tester.tap(find.text('Odds'));
    await tester.pump();
    expect(find.text('Title'), findsOneWidget);
    expect(find.text('Bottom 3'), findsOneWidget);
  });

  testWidgets('offline bundle without projections explains the missing odds', (tester) async {
    final s = AppState.preloaded(Bundle.fromJson(minimalBundleJson()));
    await pumpApp(tester, const ClubsScreen(), state: s);
    await tester.tap(find.text('Odds'));
    await tester.pump();
    expect(find.textContaining('Odds need the live season'), findsOneWidget);
  });
}
