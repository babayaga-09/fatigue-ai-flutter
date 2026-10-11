import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchline/data/bundle.dart';
import 'package:touchline/widgets/crest.dart';
import 'package:touchline/widgets/empty_note.dart';
import 'package:touchline/widgets/player_avatar.dart';
import 'package:touchline/widgets/scarf.dart';
import 'package:touchline/widgets/value_chart.dart';

import 'helpers.dart';

Club _club(String? crest) => Club.fromJson({
      'id': 1, 'name': 'Borussia Dortmund', 'crest': crest, 'league': 'L1', 'elo': 1800,
      'elo_change_30d': 0, 'form': [], 'colors': ['#FDE100', '#000000'], 'proj': null,
      'table': {'pos': 1, 'played': 0, 'points': 0, 'gd': 0, 'gf': 0, 'ga': 0},
    });

void main() {
  testWidgets('fixture scarf announces the split in words', (tester) async {
    final b = fixtureBundle();
    final f = b.fixtures.firstWhere((f) => !f.finished);
    await pumpApp(tester, Scaffold(body: FixtureScarf(
        fixture: f, home: b.clubById[f.home], away: b.clubById[f.away], hero: true)));
    final home = b.clubById[f.home]!.name;
    expect(find.bySemanticsLabel(RegExp('^$home win \\d+%, draw \\d+%, .+ win \\d+%\$')),
        findsOneWidget);
  });

  testWidgets('scarves skip the knit-in when animations are disabled', (tester) async {
    await pumpApp(tester, const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: Scaffold(body: FormScarf(form: ['W', 'D', 'L']))));
    final paint = tester.widget<CustomPaint>(find.descendant(
        of: find.byType(Scarf), matching: find.byType(CustomPaint)).first);
    expect((paint.painter! as ScarfPainter).progress, 1.0);
    expect(find.bySemanticsLabel('Form: won, drew, lost'), findsOneWidget);
  });

  testWidgets('empty form says so', (tester) async {
    await pumpApp(tester, const Scaffold(body: FormScarf(form: [])));
    expect(find.text('No games yet'), findsOneWidget);
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

  testWidgets('value chart with one point shows an empty note', (tester) async {
    await pumpApp(tester, Scaffold(
        body: ValueChart(points: [ValuePoint(DateTime(2025, 7, 1), 1000000)])));
    expect(find.byType(EmptyNote), findsOneWidget);
  });
}
