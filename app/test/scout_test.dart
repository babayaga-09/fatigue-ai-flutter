import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchline/data/planner.dart';
import 'package:touchline/screens/scout_screen.dart';

import 'helpers.dart';

Future<Plan?> syncSolver(List<PlanItem> i, double b, Map<String, int> n) async =>
    planSignings(i, b, n);

void main() {
  testWidgets('default window builds three signings within budget', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 2000));
    await pumpApp(tester, const ScoutScreen(solver: syncSolver));
    await tester.tap(find.text('Find the signings'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Your window'), findsOneWidget);
    expect(find.textContaining('Spend'), findsOneWidget);
  });

  testWidgets('no positions asks for one; infeasible explains why', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 2000));
    await pumpApp(tester, ScoutScreen(solver: (i, b, n) async => null));
    await tester.tap(find.text('Find the signings'));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('Nothing fits'), findsOneWidget);
    for (final t in ['One fewer forwards', 'One fewer midfielders', 'One fewer defenders']) {
      await tester.tap(find.byTooltip(t));
      await tester.pump();
    }
    await tester.tap(find.text('Find the signings'));
    await tester.pump();
    expect(find.text('Pick at least one position.'), findsOneWidget);
  });

  testWidgets('cheaper lookalikes for a searched player', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 2400));
    final star = fixtureBundle().players
        .where((p) => p.qualified && (p.marketValue ?? 0) > 60000000).first;
    await pumpApp(tester, const ScoutScreen(solver: syncSolver));
    await tester.enterText(find.widgetWithText(TextField, 'Start with a player you like'),
        star.name);
    await tester.pump();
    await tester.tap(find.text(star.name).last);
    await tester.pump();
    expect(find.textContaining('Plays like ${star.name}'), findsOneWidget);
  });
}
