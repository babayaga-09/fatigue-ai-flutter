import 'package:flutter/material.dart';

import '../data/bundle.dart';
import '../data/selectors.dart';
import '../format.dart';
import '../state/app_state.dart';
import '../theme/theme.dart';
import '../widgets/crest.dart';
import '../widgets/empty_note.dart';
import '../widgets/league_chips.dart';
import 'routes.dart';

class ClubsScreen extends StatefulWidget {
  const ClubsScreen({super.key});
  @override
  State<ClubsScreen> createState() => _ClubsScreenState();
}

class _ClubsScreenState extends State<ClubsScreen> {
  String? league;
  bool odds = false;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final b = s.bundle!;
    final lg = league ?? s.league ?? b.leagues.first.id;
    final rows = leagueTable(b, lg);
    final hasOdds = rows.any((c) => c.proj != null);
    final tt = Theme.of(context).textTheme;
    final muted = tt.labelMedium!.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);

    Widget num(String v, {bool strong = false}) => SizedBox(
        width: 56,
        child: Text(v, textAlign: TextAlign.end,
            style: tabular(strong ? tt.titleSmall! : tt.bodyMedium!)));
    Widget head(String v) => SizedBox(width: 56, child: Text(v, textAlign: TextAlign.end, style: muted));

    Widget row(Club c) {
      final p = c.proj;
      return InkWell(
        onTap: () => openClub(context, c.id),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              SizedBox(width: 28, child: Text('${c.table.pos}', style: tabular(tt.labelLarge!))),
              Crest(club: c, size: 28),
              const SizedBox(width: 10),
              Expanded(child: Text(c.name, style: tt.titleSmall, maxLines: 1,
                  overflow: TextOverflow.ellipsis)),
              if (!odds) ...[
                num('${c.table.played}'),
                num(c.table.gd > 0 ? '+${c.table.gd}' : '${c.table.gd}'),
                num('${c.table.points}', strong: true),
              ] else ...[
                num(p == null ? '–' : pct(p.pTitle), strong: true),
                num(p == null ? '–' : pct(p.pTop4)),
                num(p == null ? '–' : pct(p.pReleg)),
              ],
            ]),
          ),
        ),
      );
    }

    final n = rows.length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clubs'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: LeagueChips(allowAll: false, selected: lg,
              onSelected: (v) => setState(() => league = v)),
        ),
      ),
      body: ListView(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Table'),
                  icon: Icon(Icons.format_list_numbered_rounded)),
              ButtonSegment(value: true, label: Text('Odds'), icon: Icon(Icons.insights_rounded)),
            ],
            selected: {odds},
            onSelectionChanged: (v) => setState(() => odds = v.first),
          ),
        ),
        if (odds && !hasOdds)
          const Padding(padding: EdgeInsets.all(16),
              child: EmptyNote('Odds need the live season. Connect and refresh from Home.'))
        else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(children: [
              const SizedBox(width: 66),
              Expanded(child: Text('Club', style: muted)),
              ...odds ? [head('Title'), head('Top 4'), head('Bottom 3')]
                  : [head('P'), head('GD'), head('Pts')],
            ]),
          ),
          for (final (i, c) in rows.indexed) ...[
            row(c),
            if (i == 3 || i == n - 4) const Divider(thickness: 2) else const Divider(indent: 16),
          ],
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          child: Text(odds ? 'From 10,000 simulations of the rest of the season.'
              : 'Live table. Thick lines mark the top four and the bottom three.',
              style: tt.bodySmall),
        ),
      ]),
    );
  }
}
