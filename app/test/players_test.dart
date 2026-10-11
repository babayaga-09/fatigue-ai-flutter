import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchline/screens/players_screen.dart';

import 'helpers.dart';

void main() {
  testWidgets('accent-free search finds the player', (tester) async {
    await pumpApp(tester, const PlayersScreen());
    await tester.enterText(find.byType(SearchBar), 'mbappe');
    await tester.pump();
    expect(find.text('Kylian Mbappé'), findsOneWidget);
  });

  testWidgets('position chip filters and no-results offers a reset', (tester) async {
    await pumpApp(tester, const PlayersScreen());
    await tester.tap(find.widgetWithText(ChoiceChip, 'Goalkeepers'));
    await tester.pump();
    await tester.enterText(find.byType(SearchBar), 'zzzzqqq');
    await tester.pump();
    expect(find.textContaining('Nobody matches'), findsOneWidget);
    await tester.tap(find.text('Clear filters'));
    await tester.pump();
    expect(find.textContaining('Nobody matches'), findsNothing);
  });
}
