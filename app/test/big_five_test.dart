import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchline/screens/big_five_screen.dart';

import 'helpers.dart';

void main() {
  testWidgets('filters by league and keeps the honest note', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 3000));
    final b = fixtureBundle();
    await pumpApp(tester, const BigFiveScreen());
    expect(find.text(bigFiveNote(b)), findsOneWidget);
    final all = find.byType(ProspectRow).evaluate().length;
    final lg = b.prospects.first; // its chip is first in the row, so on screen
    await tester.tap(find.widgetWithText(ChoiceChip, lg.leagueName));
    await tester.pump();
    final n = b.prospects.where((p) => p.league == lg.league).length;
    expect(find.byType(ProspectRow), findsNWidgets(n < all ? n : all));
  });
}
