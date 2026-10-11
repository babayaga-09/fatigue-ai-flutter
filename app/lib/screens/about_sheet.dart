import 'package:flutter/material.dart';

import '../format.dart';
import '../state/app_state.dart';
import '../widgets/section.dart';

Future<void> showAboutSheet(BuildContext context) => showModalBottomSheet<void>(
    context: context, isScrollControlled: true, builder: (_) => const AboutSheet());

class AboutSheet extends StatelessWidget {
  const AboutSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final b = s.bundle!;
    final tt = Theme.of(context).textTheme;
    final muted = tt.bodySmall!.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    num? at(String model, String key) => (b.models[model] as Map?)?[key] as num?;
    String f(num? v, int d) => v == null ? '–' : v.toStringAsFixed(d);
    final lines = <(String, String)>[
      if (at('club_elo', 'favourite_accuracy') case final acc?)
        ('Who wins', 'Picks the winner in ${pct(acc.toDouble())} of games that had one. '
            'Backing the home team every time gets '
            '${pct((at('club_elo', 'baseline_home_pick_accuracy') ?? 0).toDouble())}.'),
      if (at('match_model', 'rps') case final r?)
        ('Match odds', 'Probability score ${f(r, 3)} against '
            '${f(at('match_model', 'baseline_rps'), 3)} for a base-rate guess. Lower is better.'),
      if (at('valuator', 'mae_eur') case final e?)
        ('Fair value', 'Typically within ${money(e.round())} of the market. A simple '
            'age-and-position rule misses by ${money(at('valuator', 'baseline_mae_eur')?.round())}.'),
      if (at('form', 'gru_mae') case final g?)
        ('Next five games', "A neural network reads each player's last ten games. Average miss "
            '${f(g, 2)} goal involvements; a classic stats model ${f(at('form', 'glm_mae'), 2)}; '
            'recent averages ${f(at('form', 'naive_mae'), 2)}.'),
      ('Workload', 'A risk index from minutes, games on short rest and sudden load spikes. '
          'Not an injury prediction: the data has no injury records.'),
    ];
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          Text('How this works', style: tt.titleLarge),
          const SizedBox(height: 6),
          Text('Every number comes from a model tested on a season it never saw, and checked '
              'against a simple rule of thumb. Results below are from ${b.playerSeason}.',
              style: tt.bodyMedium),
          for (final (title, body) in lines)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: tt.titleSmall),
                const SizedBox(height: 2),
                Text(body, style: tt.bodyMedium),
              ]),
            ),
          const SectionHeading('Data', padded: false),
          Text('Clubs, tables and fixtures update weekly; this copy is from '
              '${shortDate(DateTime.parse(b.clubsThrough))}. Player stats are '
              '${b.playerSeason}, the latest complete season in the open dataset.',
              style: tt.bodyMedium),
          const SizedBox(height: 6),
          Text('Sources: Transfermarkt open dataset (CC0) and football-data.org. Market values '
              'are crowd estimates, not transfer fees. Not affiliated with any club or league.',
              style: muted),
          const SectionHeading('Appearance', padded: false),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.system, label: Text('System')),
              ButtonSegment(value: ThemeMode.light, label: Text('Light')),
              ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
            ],
            selected: {s.themeMode},
            onSelectionChanged: (v) => s.setThemeMode(v.first),
          ),
          const SizedBox(height: 24),
          Text('Lettering: Jersey by Sarah Cadigan-Fried, SIL Open Font License.', style: muted),
        ],
      ),
    );
  }
}
