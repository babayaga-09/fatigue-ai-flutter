import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchline/data/bundle.dart';
import 'package:touchline/widgets/crest.dart';
import 'package:touchline/widgets/empty_note.dart';
import 'package:touchline/widgets/player_avatar.dart';
import 'package:touchline/widgets/rows.dart';
import 'package:touchline/widgets/print.dart';
import 'package:touchline/widgets/value_chart.dart';

import 'helpers.dart';

Club _club(String? crest) => Club.fromJson({
      'id': 1, 'name': 'Borussia Dortmund', 'crest': crest, 'league': 'L1', 'elo': 1800,
      'elo_change_30d': 0, 'form': [], 'colors': ['#FDE100', '#000000'], 'proj': null,
      'table': {'pos': 1, 'played': 0, 'points': 0, 'gd': 0, 'gf': 0, 'ga': 0},
    });

void main() {
  testWidgets('result strip announces the split in words', (tester) async {
    final b = fixtureBundle();
    final f = b.fixtures.firstWhere((f) => !f.finished);
    await pumpApp(tester, Scaffold(body: ResultStrip(
        fixture: f, home: b.clubById[f.home], away: b.clubById[f.away], hero: true)));
    final home = b.clubById[f.home]!.name;
    expect(find.bySemanticsLabel(RegExp('^$home win \\d+%, draw \\d+%, .+ win \\d+%\$')),
        findsOneWidget);
  });

  testWidgets('form boxes carry letters, not just colour', (tester) async {
    await pumpApp(tester, const Scaffold(body: FormBoxes(form: ['W', 'D', 'L'])));
    expect(find.bySemanticsLabel('Form: won, drew, lost'), findsOneWidget);
    for (final r in ['W', 'D', 'L']) {
      expect(find.text(r), findsOneWidget);
    }
  });

  testWidgets('empty form says so', (tester) async {
    await pumpApp(tester, const Scaffold(body: FormBoxes(form: [])));
    expect(find.text('No games yet'), findsOneWidget);
  });

  test('clashing club colours fall back to the away second colour', () {
    final red = Club.fromJson({
      'id': 2, 'name': 'Reds', 'crest': null, 'league': 'GB1', 'elo': 1800,
      'elo_change_30d': 0, 'form': [], 'colors': ['#DB0007', '#FFFFFF'], 'proj': null,
      'table': {'pos': 1, 'played': 0, 'points': 0, 'gd': 0, 'gf': 0, 'ga': 0},
    });
    final (h, a) = matchColors(red, red);
    expect(h, const Color(0xFFDB0007));
    expect(a, const Color(0xFFFFFFFF));
  });

  testWidgets('crest falls back to a stitched monogram (null and failed URL)', (tester) async {
    await pumpApp(tester, Scaffold(body: Column(children: [
      Crest(club: _club(null)),
      Crest(club: _club('https://example.invalid/crest.png')),
    ])));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('monogram')), findsNWidgets(2));
    expect(find.text('BD'), findsNWidgets(2));
  });

  testWidgets('player avatar falls back to initials', (tester) async {
    final p = fixtureBundle().players.first;
    await pumpApp(tester, Scaffold(body: PlayerAvatar(player: p)));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('initials')), findsOneWidget);
  });

  testWidgets('player tiles never clip at large text', (tester) async {
    final ps = fixtureBundle().players.take(6).toList();
    await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: MaterialApp(home: Scaffold(body: PlayerStrip(players: ps,
            notes: (_) => 'Four goal involvements in the last five games')))));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('value chart with one point shows an empty note', (tester) async {
    await pumpApp(tester, Scaffold(
        body: ValueChart(points: [ValuePoint(DateTime(2025, 7, 1), 1000000)])));
    expect(find.byType(EmptyNote), findsOneWidget);
  });
}
