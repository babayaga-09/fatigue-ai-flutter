import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchline/data/bundle.dart';
import 'package:touchline/screens/home_screen.dart';
import 'package:touchline/state/app_state.dart';

import 'helpers.dart';

void main() {
  testWidgets('home leads with the hero scarf and has every section', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    await pumpApp(tester, const HomeScreen());
    expect(find.text('TOUCHLINE'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'win \d+%, draw \d+%')), findsWidgets);
    for (final h in ['Running hot', 'This week', 'Clubs in form', 'Power rankings', 'Bargains',
        'Overworked watch']) {
      await tester.scrollUntilVisible(find.text(h), 400,
          scrollable: find.byType(Scrollable).first);
      expect(find.text(h), findsOneWidget, reason: h);
    }
  });

  testWidgets('league chip filters globally', (tester) async {
    final s = await pumpApp(tester, const HomeScreen());
    await tester.tap(find.widgetWithText(ChoiceChip, 'LaLiga'));
    await tester.pump();
    expect(s.league, 'ES1');
  });

  testWidgets('tapping the hero opens the match breakdown', (tester) async {
    await pumpApp(tester, const HomeScreen());
    await tester.tap(find.byType(HeroFixture));
    await tester.pumpAndSettle();
    expect(find.textContaining('Expected goals'), findsWidgets);
    expect(find.text('Draw'), findsOneWidget);
  });

  testWidgets('a quiet week says so instead of collapsing', (tester) async {
    final s = AppState.preloaded(fixtureBundle(), clock: () => DateTime.utc(2027, 6, 1));
    await pumpApp(tester, const HomeScreen(), state: s);
    expect(find.textContaining('No fixtures in the next seven days'), findsOneWidget);
  });

  testWidgets('renders in dark mode without overflow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 780));
    await pumpApp(tester, const HomeScreen(), brightness: Brightness.dark);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a build without an update URL says it runs on built-in data', (tester) async {
    await pumpApp(tester, const HomeScreen());
    expect(find.text('11 Oct'), findsOneWidget); // the date always survives
    expect(find.byTooltip('Built-in data from 11 Oct'), findsOneWidget);
    expect(tester.getSemantics(find.bySemanticsLabel('Built-in data from 11 Oct')),
        isSemantics(isButton: true, hasTapAction: true));
    expect(find.text('Offline'), findsNothing);
  });

  test('fixture bundle has fixtures around fixtureNow', () {
    final Bundle b = fixtureBundle();
    expect(b.fixtures.any((f) => !f.finished && f.kickoff.isAfter(fixtureNow)), isTrue);
  });
}
