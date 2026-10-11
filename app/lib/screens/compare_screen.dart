import 'package:flutter/material.dart';

import '../data/bundle.dart';
import '../data/selectors.dart';
import '../format.dart';
import '../state/app_state.dart';
import '../theme/theme.dart';
import '../widgets/empty_note.dart';
import '../widgets/rows.dart';

class CompareLine {
  const CompareLine(this.label, this.a, this.b, this.better);
  final String label;
  final String a;
  final String b;

  /// -1: first is better, 1: second is better, 0: equal or not comparable.
  final int better;
}

int _cmp(num? a, num? b, {bool lowerIsBetter = false}) {
  if (a == null || b == null || a == b) return 0;
  final aWins = lowerIsBetter ? a < b : a > b;
  return aWins ? -1 : 1;
}

List<CompareLine> compareLines(Player a, Player b) {
  String f1(double? v) => v == null ? '–' : v.toStringAsFixed(1);
  String f2(double? v) => v == null ? '–' : v.toStringAsFixed(2);
  return [
    CompareLine('Market value', money(a.marketValue), money(b.marketValue), 0),
    CompareLine('Fair value', money(a.fairValue), money(b.fairValue),
        _cmp(a.fairValue, b.fairValue)),
    CompareLine('Value vs price',
        a.valueGapPct == null ? '–' : pct(a.valueGapPct!),
        b.valueGapPct == null ? '–' : pct(b.valueGapPct!),
        _cmp(a.valueGapPct, b.valueGapPct)),
    CompareLine('G/A per 90', f2(a.season.ga90), f2(b.season.ga90),
        a.qualified && b.qualified ? _cmp(a.season.ga90, b.season.ga90) : 0),
    CompareLine('Goals', '${a.season.goals}', '${b.season.goals}',
        _cmp(a.season.goals, b.season.goals)),
    CompareLine('Assists', '${a.season.assists}', '${b.season.assists}',
        _cmp(a.season.assists, b.season.assists)),
    CompareLine('Minutes', thousands(a.season.minutes), thousands(b.season.minutes), 0),
    CompareLine('Projected G/A, next 5', f1(a.forecastGa5), f1(b.forecastGa5),
        _cmp(a.forecastGa5, b.forecastGa5)),
    CompareLine('Workload index', '${a.workload?.index ?? '–'}', '${b.workload?.index ?? '–'}',
        _cmp(a.workload?.index, b.workload?.index, lowerIsBetter: true)),
    CompareLine('Age', a.age == null ? '–' : '${a.age!.floor()}',
        b.age == null ? '–' : '${b.age!.floor()}', 0),
  ];
}

class CompareScreen extends StatefulWidget {
  const CompareScreen({super.key, required this.firstId, this.secondId});
  final int firstId;
  final int? secondId;

  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  late int? second = widget.secondId;
  String query = '';

  @override
  Widget build(BuildContext context) {
    final b = AppScope.of(context).bundle!;
    final a = b.playerById[widget.firstId];
    final other = second == null ? null : b.playerById[second];
    if (a == null) {
      return Scaffold(appBar: AppBar(),
          body: const Padding(padding: EdgeInsets.all(16),
              child: EmptyNote('This player is no longer in the data.')));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(other == null ? 'Compare ${a.name} with…' : 'Compare'),
        actions: [
          if (other != null)
            TextButton(onPressed: () => setState(() => second = null),
                child: const Text('Change')),
        ],
      ),
      body: other == null ? _picker(context, b, a) : _table(context, a, other),
    );
  }

  Widget _picker(BuildContext context, Bundle b, Player a) {
    final results = query.trim().isEmpty
        ? [for (final id in a.similar) ?b.playerById[id]]
        : searchPlayers(b, PlayerQuery(text: query)).where((p) => p.id != a.id).take(30)
            .toList();
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: TextField(
          autofocus: true,
          decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded), hintText: 'Search a player',
              border: OutlineInputBorder()),
          onChanged: (v) => setState(() => query = v),
        ),
      ),
      if (query.trim().isEmpty)
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(alignment: Alignment.centerLeft,
                child: Text('Players like him', style: Theme.of(context).textTheme.titleSmall))),
      Expanded(
        child: results.isEmpty
            ? const Padding(padding: EdgeInsets.all(16),
                child: EmptyNote('Nobody by that name. Try a surname.'))
            : ListView(children: [
                for (final p in results)
                  PlayerRow(player: p, onTap: () => setState(() => second = p.id)),
              ]),
      ),
    ]);
  }

  Widget _table(BuildContext context, Player a, Player b) {
    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    Widget cell(String v, bool wins, TextAlign align) => Row(
          mainAxisAlignment: align == TextAlign.end ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            if (wins && align == TextAlign.end)
              Icon(Icons.arrow_drop_up_rounded, color: scheme.primary, semanticLabel: 'better'),
            Text(v, style: tabular(wins ? tt.titleMedium!.copyWith(color: scheme.primary)
                : tt.bodyLarge!)),
            if (wins && align == TextAlign.start)
              Icon(Icons.arrow_drop_up_rounded, color: scheme.primary, semanticLabel: 'better'),
          ],
        );
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Row(children: [
          Expanded(child: Text(a.name, style: tt.titleMedium, textAlign: TextAlign.end)),
          const SizedBox(width: 120),
          Expanded(child: Text(b.name, style: tt.titleMedium)),
        ]),
        const SizedBox(height: 8),
        for (final l in compareLines(a, b)) ...[
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(children: [
              Expanded(child: cell(l.a, l.better == -1, TextAlign.end)),
              SizedBox(width: 120,
                  child: Text(l.label, textAlign: TextAlign.center,
                      style: tt.labelMedium!.copyWith(color: scheme.onSurfaceVariant))),
              Expanded(child: cell(l.b, l.better == 1, TextAlign.start)),
            ]),
          ),
        ],
        const SizedBox(height: 12),
        Text('Season figures are ${AppScope.of(context).bundle!.playerSeason}. '
            'Workload: lower is fresher.', style: tt.bodySmall),
      ],
    );
  }
}
