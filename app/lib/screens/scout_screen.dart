import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/bundle.dart';
import '../data/planner.dart';
import '../data/selectors.dart';
import '../format.dart';
import '../state/app_state.dart';
import '../widgets/brand.dart';
import '../widgets/empty_note.dart';
import '../widgets/league_chips.dart';
import '../widgets/rows.dart';
import '../widgets/section.dart';
import 'big_five_screen.dart';
import 'routes.dart';

typedef Solver = Future<Plan?> Function(
    List<PlanItem> items, double budget, Map<String, int> needs);

Plan? _solve((List<PlanItem>, double, Map<String, int>) a) => planSignings(a.$1, a.$2, a.$3);

Future<Plan?> isolateSolver(List<PlanItem> items, double budget, Map<String, int> needs) =>
    compute(_solve, (items, budget, needs));

const _labels = {'Attack': 'forwards', 'Midfield': 'midfielders', 'Defender': 'defenders',
    'Goalkeeper': 'goalkeepers'};

class ScoutScreen extends StatefulWidget {
  const ScoutScreen({super.key, this.solver = isolateSolver});
  final Solver solver;
  @override
  State<ScoutScreen> createState() => _ScoutScreenState();
}

class _ScoutScreenState extends State<ScoutScreen> {
  double budget = 100;
  final needs = {'Attack': 1, 'Midfield': 1, 'Defender': 1, 'Goalkeeper': 0};
  double maxAge = 30;
  String? league;
  Plan? plan;
  String? message;
  bool busy = false;
  String find = '';
  int? target;

  Future<void> _build(Bundle b) async {
    if (needs.values.every((v) => v == 0)) {
      setState(() {
        plan = null;
        message = 'Pick at least one position.';
      });
      return;
    }
    setState(() => busy = true);
    final items = planCandidates(b, league: league, maxAge: maxAge);
    final result = await widget.solver(items, budget, Map.of(needs));
    if (!mounted) return;
    setState(() {
      busy = false;
      plan = result;
      message = result == null
          ? 'Nothing fits €${budget.round()}M with those positions. '
              'Raise the budget or drop a position.'
          : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final b = AppScope.of(context).bundle!;
    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final muted = tt.bodyMedium!.copyWith(color: scheme.onSurfaceVariant);
    final matches = find.trim().isEmpty
        ? const <Player>[]
        : searchPlayers(b, PlayerQuery(text: find)).where((p) => p.qualified).take(5).toList();
    final t = target == null ? null : b.playerById[target];
    final p = plan;
    return Scaffold(
      appBar: AppBar(title: const ScreenTitle('Scouting')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: _gutter([
          if (b.prospects.isNotEmpty) ...[
            SectionHeading('Ready for the Big Five', padded: false, note: bigFiveNote(b)),
            for (final (i, pr) in b.prospects.take(3).indexed)
              ProspectRow(number: i + 1, prospect: pr),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const BigFiveScreen())),
                child: Text('See all ${b.prospects.length}, filter by league and position'),
              ),
            ),
          ],
          const SectionHeading('Build my window', padded: false),
          Text('The most player for your money, judged on ${b.playerSeason} numbers.',
              style: muted),
          const SizedBox(height: 16),
          Text('Budget €${budget.round()}M', style: tt.titleMedium),
          Slider(min: 10, max: 300, divisions: 58, value: budget, label: '€${budget.round()}M',
              onChanged: (v) => setState(() => budget = v)),
          for (final MapEntry(key: pos, value: label) in _labels.entries)
            Row(children: [
              Expanded(child: Text(label[0].toUpperCase() + label.substring(1),
                  style: tt.bodyLarge)),
              IconButton(
                tooltip: 'One fewer $label',
                icon: const Icon(Icons.remove_circle_outline_rounded),
                onPressed: needs[pos]! > 0 ? () => setState(() => needs[pos] = needs[pos]! - 1)
                    : null,
              ),
              SizedBox(width: 24, child: Text('${needs[pos]}', textAlign: TextAlign.center,
                  style: tt.titleMedium)),
              IconButton(
                tooltip: 'One more $label',
                icon: const Icon(Icons.add_circle_outline_rounded),
                onPressed: needs[pos]! < 3 ? () => setState(() => needs[pos] = needs[pos]! + 1)
                    : null,
              ),
            ]),
          const SizedBox(height: 8),
          Text('Max age ${maxAge.round()}', style: tt.titleMedium),
          Slider(min: 18, max: 36, divisions: 18, value: maxAge, label: '${maxAge.round()}',
              onChanged: (v) => setState(() => maxAge = v)),
          LeagueChips(selected: league, onSelected: (v) => setState(() => league = v)),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: busy ? null : () => _build(b),
            icon: const Icon(Icons.playlist_add_check_rounded),
            label: const Text('Find the signings'),
          ),
          if (busy) const Padding(padding: EdgeInsets.only(top: 12),
              child: LinearProgressIndicator()),
          if (message != null) EmptyNote(message!),
          if (p != null) ...[
            const SectionHeading('Your window', padded: false),
            Text('Spend ${money((p.cost * 1e6).round())} of €${budget.round()}M · '
                'fair value ${money((p.score * 1e6).round())}', style: tt.titleMedium),
            for (final id in p.ids)
              if (b.playerById[id] case final pl?)
                PlayerRow(
                  player: pl,
                  subtitle: [pl.clubName, pl.subPos ?? pl.pos].whereType<String>().join(' · '),
                  trailing: Column(mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(money(pl.marketValue), style: tt.labelLarge),
                    Text('worth ${money(pl.fairValue)}', style: tt.labelSmall!
                        .copyWith(color: scheme.primary)),
                  ]),
                  onTap: () => openPlayer(context, pl.id),
                ),
          ],
          const SectionHeading('Find a cheaper version', padded: false),
          TextField(
            decoration: const InputDecoration(
                hintText: 'Start with a player you like',
                prefixIcon: Icon(Icons.search_rounded), border: OutlineInputBorder()),
            onChanged: (v) => setState(() => find = v),
          ),
          for (final m in matches)
            PlayerRow(player: m, onTap: () => setState(() {
                  target = m.id;
                  find = '';
                })),
          if (t != null) ...[
            const SizedBox(height: 12),
            Text('Plays like ${t.name}, costs less:', style: tt.titleMedium),
            ...switch (similarCheaper(b, t)) {
              final list when list.isEmpty =>
                  [const EmptyNote('No cheaper lookalikes in the data.')],
              final list => [
                  for (final c in list)
                    PlayerRow(player: c,
                        trailing: Text(money(c.marketValue), style: tt.labelLarge),
                        onTap: () => openPlayer(context, c.id)),
                ],
            },
          ],
          const SectionHeading('Ask the Scout', padded: false),
          Text('Coming later: ask in plain words, like "a left-back under €15M".',
              style: muted),
        ]),
      ),
    );
  }
}

/// One page gutter: full-width rows and the chip strip carry their own 16px inset; everything
/// else gets it here, so figures and rules end on the same edge as the section rules.
List<Widget> _gutter(List<Widget> items) => [
      for (final w in items)
        w is ProspectRow || w is PlayerRow || w is LeagueChips
            ? w
            : Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: w),
    ];
