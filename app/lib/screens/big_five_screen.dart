import 'package:flutter/material.dart';

import '../data/bundle.dart';
import '../format.dart';
import '../state/app_state.dart';
import '../theme/theme.dart';
import '../widgets/brand.dart';
import '../widgets/crest.dart';
import '../widgets/empty_note.dart';
import '../widgets/halftone.dart';
import '../widgets/print.dart';

int _moves(Bundle b) =>
    ((b.models['prospects'] as Map?)?['n_train'] as num?)?.toInt() ?? 0;

/// The honest one-liner every Big Five list carries.
String bigFiveNote(Bundle b) => b.prospectsByPrice
    ? 'Ranked by price. We tested a model on ${thousands(_moves(b))} past moves and it '
        'couldn\'t beat the '
        'transfer market\'s own valuation, so we show the market\'s pick. The figure is their '
        'goal involvements per 90, translated to top-five level.'
    : 'Ranked by the chance of becoming a regular after a move. The figure is goal '
        'involvements per 90, translated to top-five level.';

/// One feeder-league player as a team-sheet line: number, halftone, name, translated output.
class ProspectRow extends StatelessWidget {
  const ProspectRow({super.key, required this.number, required this.prospect});
  final int number;
  final Prospect prospect;

  @override
  Widget build(BuildContext context) {
    final p = prospect;
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final age = p.age == null ? '' : ' · ${p.age!.floor()}';
    return Semantics(
      label: '$number. ${p.name}, ${p.clubName ?? ''}, ${p.leagueName}$age. '
          '${p.ga90.toStringAsFixed(2)} goal involvements per 90 there, about '
          '${p.translatedGa90.toStringAsFixed(2)} in a top league. Valued ${money(p.marketValue)}.',
      container: true,
      child: ExcludeSemantics(
        child: TeamSheetRow(
          number: number,
          leading: SizedBox(
            width: 40,
            height: 53,
            child: HalftonePortrait(
              url: p.img, ink: scheme.onSurface, paper: scheme.surfaceContainerHigh, columns: 14,
              fallback: Container(color: scheme.surfaceContainerHigh, alignment: Alignment.center,
                  child: Text(initials(p.name), style: masthead(18, scheme.onSurface))),
            ),
          ),
          title: p.name,
          subtitle: '${p.clubName ?? ''} · ${p.leagueName}$age · ${money(p.marketValue)}',
          trailing: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(p.translatedGa90.toStringAsFixed(2), style: masthead(26, scheme.onSurface)),
            Text('from ${p.ga90.toStringAsFixed(2)}',
                style: tt.labelSmall!.copyWith(color: scheme.onSurfaceVariant)),
          ]),
        ),
      ),
    );
  }
}

class BigFiveScreen extends StatefulWidget {
  const BigFiveScreen({super.key});
  @override
  State<BigFiveScreen> createState() => _BigFiveScreenState();
}

class _BigFiveScreenState extends State<BigFiveScreen> {
  String? league, pos;

  @override
  Widget build(BuildContext context) {
    final b = AppScope.of(context).bundle!;
    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final leagues = {for (final p in b.prospects) p.league: p.leagueName};
    final positions = {for (final p in b.prospects) ?p.pos}.toList()..sort();
    final rows = b.prospects
        .where((p) => (league == null || p.league == league) && (pos == null || p.pos == pos))
        .toList();
    Widget chips<T>(List<(String, T?)> items, T? current, ValueChanged<T?> set) => SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final (label, v) in items)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(label: Text(label), selected: current == v,
                      onSelected: (_) => setState(() => set(v))),
                ),
            ],
          ),
        );
    return Scaffold(
      appBar: AppBar(title: const ScreenTitle('Ready for the Big Five')),
      body: ListView(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(bigFiveNote(b),
              style: tt.bodySmall!.copyWith(color: scheme.onSurfaceVariant)),
        ),
        chips<String>([('All leagues', null), for (final e in leagues.entries) (e.value, e.key)],
            league, (v) => league = v),
        chips<String>([('All positions', null), for (final p in positions) (p, p)],
            pos, (v) => pos = v),
        const SizedBox(height: 8),
        if (rows.isEmpty)
          const Padding(padding: EdgeInsets.all(16),
              child: EmptyNote('Nobody fits that filter.'))
        else
          for (final (i, p) in rows.indexed) ProspectRow(number: i + 1, prospect: p),
        const SizedBox(height: 32),
      ]),
    );
  }
}
