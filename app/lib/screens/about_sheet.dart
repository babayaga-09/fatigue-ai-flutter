import 'package:flutter/material.dart';

import '../format.dart';
import '../state/app_state.dart';
import '../theme/theme.dart';
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
      if (at('career', 'mae_h1') case final c?)
        ('Career curve', 'A neural network reads up to six seasons of a career and forecasts '
            'market value one to three seasons ahead, with a range. Tested on careers it never '
            'saw: typical miss ${f(c, 2)} (log scale) against ${f(at('career', 'baseline_mae_h1'), 2)} '
            'for the usual ageing curve one season out, and the range held '
            '${pct((at('career', 'coverage_h1') ?? 0).toDouble())} of outcomes. The edge '
            'grows further out.'),
      if (at('prospects', 'auc') case final a?)
        ('Ready for the Big Five', 'We tried to predict which feeder-league players become '
            'regulars after a move. Over ${at('prospects', 'n_test')} past moves our model '
            'scored ${f(a, 2)}; the market value alone scored '
            '${f(at('prospects', 'baseline_auc'), 2)} (0.5 is a coin flip). The price won, '
            'so the list shows the price ranking.'),
      if ((b.models['manager_effect'] as Map?)?['split_half_r'] case final num r)
        ('Managers', 'Points above what the squad should have taken, judged against club '
            'strength frozen at the start of each spell so a manager is not marked against '
            "his own results. A manager's odd and even games agree at r = ${f(r, 2)}, "
            'so read it as a tendency.'),
      if ((b.models['dependency'] as Map?)?['stability_r'] case final num r)
        ('With and without', 'Results with a player against results without him. It barely '
            'repeats from the first half of a season to the second (r = ${f(r, 2)}), so it is '
            'a description of this season, not a measure of how good he is.'),
    ];
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          Text('HOW THIS WORKS', style: masthead(34, Theme.of(context).colorScheme.onSurface)),
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
          Text('Type: Archivo by Omnibus-Type, SIL Open Font License.', style: muted),
        ],
      ),
    );
  }
}
