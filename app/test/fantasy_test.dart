import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchline/fpl/fpl_state.dart';
import 'package:touchline/fpl/squad.dart';
import 'package:touchline/screens/fantasy_screen.dart';
import 'package:touchline/screens/squad_picker_screen.dart';
import 'package:touchline/theme/theme.dart';
import 'package:touchline/widgets/fpl_pitch.dart';

import 'fpl_core_test.dart' show fplFixture;

Future<FplState> pumpFantasy(WidgetTester tester, {Squad? squad, double scale = 1}) async {
  final b = fplFixture();
  final s = FplState.preloaded(b, squad: squad);
  await tester.pumpWidget(FplScope(
    state: s,
    child: MaterialApp(
      theme: buildTheme(Brightness.light),
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!),
      home: FantasyScreen(now: b.gws.isEmpty ? DateTime.now() : b.generatedAt),
    ),
  ));
  await tester.pump();
  return s;
}

Squad wildcardSquad() {
  final b = fplFixture();
  final wc = b.wildcard.firstWhere((w) => w.budget == 1000);
  return Squad(ids: wc.squad, bank: 0);
}

void main() {
  testWidgets('with no squad, offers the picker and a starting squad; no import on web',
      (tester) async {
    final s = await pumpFantasy(tester);
    expect(find.text('Pick your 15'), findsOneWidget);
    expect(find.text('Import by team ID'), findsNothing);
    await tester.tap(find.text('Or start from our best £100m squad'));
    await tester.pump();
    expect(s.squad!.ids.length, 15);
    expect(find.byType(FplPitch), findsOneWidget);
  });

  testWidgets('a squad gets an XI, moves and a chip planner, even at 1.3x text',
      (tester) async {
    await pumpFantasy(tester, squad: wildcardSquad(), scale: 1.3);
    final list = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.textContaining('YOUR XI'), 300, scrollable: list);
    expect(find.byType(FplPitch), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r', captain,')), findsOneWidget);
    await tester.scrollUntilVisible(find.text("THIS WEEK'S MOVES"), 300, scrollable: list);
    await tester.scrollUntilVisible(find.text('TRIPLE CAPTAIN'), 300, scrollable: list);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the squad picker will not save an incomplete squad', (tester) async {
    final b = fplFixture();
    await tester.pumpWidget(FplScope(
      state: FplState.preloaded(b),
      child: MaterialApp(theme: buildTheme(Brightness.light), home: const SquadPickerScreen()),
    ));
    await tester.pump();
    expect(find.text('0/15'), findsOneWidget);
    final save = tester.widget<TextButton>(find.widgetWithText(TextButton, 'Save'));
    expect(save.onPressed, isNull);
    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.pump();
    expect(find.text('1/15'), findsOneWidget);
  });
}
