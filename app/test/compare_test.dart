import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchline/screens/compare_screen.dart';

import 'helpers.dart';

void main() {
  test('compare lines mark the better side and skip judgement on missing data', () {
    final ps = fixtureBundle().players.where((p) => p.qualified).toList();
    final a = ps.first, b = ps[1];
    final lines = compareLines(a, b);
    expect(lines.map((l) => l.label), contains('Fair value'));
    final work = lines.firstWhere((l) => l.label == 'Workload index');
    if (a.workload != null && b.workload != null && a.workload!.index != b.workload!.index) {
      expect(work.better, a.workload!.index < b.workload!.index ? -1 : 1); // lower is better
    }
    final unq = fixtureBundle().players.firstWhere((p) => !p.qualified);
    expect(compareLines(a, unq).firstWhere((l) => l.label == 'Fair value').better, 0);
  });

  testWidgets('pick a second player, then see the table', (tester) async {
    final ps = fixtureBundle().players.where((p) => p.qualified).toList();
    await pumpApp(tester, CompareScreen(firstId: ps.first.id));
    await tester.enterText(find.byType(TextField), ps[1].name);
    await tester.pump();
    await tester.tap(find.text(ps[1].name).last);
    await tester.pump();
    expect(find.text('Fair value'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_drop_up_rounded), findsWidgets);
  });
}
