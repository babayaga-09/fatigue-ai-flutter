import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchline/app.dart';
import 'package:touchline/screens/about_sheet.dart';
import 'package:touchline/state/app_state.dart';

import 'helpers.dart';

void main() {
  testWidgets('bottom navigation switches tabs; Back returns Home first', (tester) async {
    final s = AppState.preloaded(fixtureBundle(), clock: () => fixtureNow);
    await tester.pumpWidget(TouchlineApp(state: s));
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.byType(NavigationBar), findsOneWidget);
    await tester.tap(find.text('Clubs').last);
    await tester.pump();
    expect(find.widgetWithText(AppBar, 'CLUBS'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('TOUCHLINE'), findsOneWidget);
  });

  testWidgets('wide screens use a navigation rail', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final s = AppState.preloaded(fixtureBundle(), clock: () => fixtureNow);
    await tester.pumpWidget(TouchlineApp(state: s));
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('about sheet states the honest numbers and switches theme', (tester) async {
    final s = await pumpApp(tester, const Scaffold(body: AboutSheet()));
    expect(find.text('HOW THIS WORKS'), findsOneWidget);
    expect(find.text('Who wins'), findsOneWidget);
    expect(find.textContaining('Not an injury prediction'), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('The price won'), 200);
    expect(find.textContaining('The price won'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Dark'), 200);
    await tester.ensureVisible(find.text('Dark'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pump();
    expect(s.themeMode, ThemeMode.dark);
  });
}
