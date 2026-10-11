import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchline/screens/club_detail_screen.dart';
import 'package:touchline/screens/player_detail_screen.dart';

import 'helpers.dart';

void main() {
  testWidgets('qualified player shows value, why, forecast and workload', (tester) async {
    final p = fixtureBundle().players.firstWhere((p) =>
        p.qualified && p.fairValue != null && p.forecastGa5 != null && p.workload != null &&
        p.valueHistory.length > 2);
    await pumpApp(tester, PlayerDetailScreen(playerId: p.id));
    expect(find.text(p.name), findsWidgets);
    expect(find.textContaining('Fair'), findsWidgets);
    await tester.scrollUntilVisible(find.textContaining('not an injury prediction'), 300);
    expect(find.textContaining('not an injury prediction'), findsOneWidget);
  });

  testWidgets('unqualified player never shows a fair value or forecast', (tester) async {
    final p = fixtureBundle().players.firstWhere((p) => !p.qualified);
    await pumpApp(tester, PlayerDetailScreen(playerId: p.id));
    expect(find.text('Not enough minutes yet to judge.'), findsOneWidget);
    expect(find.textContaining('Not enough minutes yet for a fair-value read'), findsOneWidget);
    expect(find.textContaining('€0'), findsNothing);
  });

  testWidgets('compare is an app-bar action, not a floating button', (tester) async {
    final p = fixtureBundle().players.first;
    await pumpApp(tester, PlayerDetailScreen(playerId: p.id));
    expect(find.byTooltip('Compare'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('season line singularises one goal and one assist', (tester) async {
    final p = fixtureBundle().players.firstWhere((p) => p.season.goals == 1 && p.season.assists == 1);
    await pumpApp(tester, PlayerDetailScreen(playerId: p.id));
    expect(find.textContaining('1 goal · 1 assist'), findsOneWidget);
  });

  testWidgets('club page says power rating in plain words, no Elo jargon', (tester) async {
    final c = fixtureBundle().clubs.first;
    await pumpApp(tester, ClubDetailScreen(clubId: c.id));
    expect(find.textContaining('Elo'), findsNothing);
    await tester.scrollUntilVisible(find.textContaining('${c.elo.round()}, '), 200);
    expect(find.textContaining('${c.elo.round()}, '), findsOneWidget);
    expect(find.textContaining('Power rating ${c.elo.round()}'), findsNothing); // no echo of the heading
  });

  testWidgets('favourite toggles from the player screen', (tester) async {
    final p = fixtureBundle().players.first;
    final s = await pumpApp(tester, PlayerDetailScreen(playerId: p.id));
    await tester.tap(find.byTooltip('Add to your players'));
    await tester.pump();
    expect(s.isFavourite(p.id), isTrue);
    expect(find.byTooltip('Remove from your players'), findsOneWidget);
  });

  testWidgets('club detail shows the scarf, odds and squad', (tester) async {
    final b = fixtureBundle();
    final c = b.clubs.firstWhere((c) => c.proj != null && b.players.any((p) => p.club == c.id));
    await pumpApp(tester, ClubDetailScreen(clubId: c.id));
    expect(find.bySemanticsLabel('${c.name} scarf'), findsOneWidget);
    expect(find.text('Season odds'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Squad'), 300);
    expect(find.text('Squad'), findsOneWidget);
  });

  testWidgets('unknown ids show a friendly note instead of crashing', (tester) async {
    await pumpApp(tester, const PlayerDetailScreen(playerId: -42));
    expect(find.textContaining('no longer in the data'), findsOneWidget);
    await pumpApp(tester, const ClubDetailScreen(clubId: -42));
    expect(find.textContaining('no longer in the data'), findsOneWidget);
  });
}
