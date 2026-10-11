import 'package:flutter/material.dart';

import '../copy/voice.dart';
import '../data/selectors.dart';
import '../format.dart';
import '../state/app_state.dart';
import '../widgets/crest.dart';
import '../widgets/empty_note.dart';
import '../widgets/rows.dart';
import '../widgets/scarf.dart';
import '../widgets/section.dart';
import '../widgets/stat_bar.dart';
import 'routes.dart';

class ClubDetailScreen extends StatelessWidget {
  const ClubDetailScreen({super.key, required this.clubId});
  final int clubId;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final b = s.bundle!;
    final c = b.clubById[clubId];
    if (c == null) {
      return Scaffold(appBar: AppBar(),
          body: const Padding(padding: EdgeInsets.all(16),
              child: EmptyNote('This club is no longer in the data.')));
    }
    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final p = c.proj;
    final fixtures = clubFixtures(b, c.id);
    final players = squad(b, c.id);
    final change = c.eloChange30d;
    return Scaffold(
      appBar: AppBar(title: Text(c.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          ClubScarf(club: c),
          const SizedBox(height: 16),
          Row(children: [
            Crest(club: c, size: 44),
            const SizedBox(width: 12),
            Expanded(child: Text(clubVerdict(c), style: tt.titleMedium)),
          ]),
          const SizedBox(height: 8),
          Text('${b.leagueById[c.league]?.name ?? c.league} · ${ordinal(c.table.pos)} · '
              '${c.table.points} pts from ${c.table.played}',
              style: tt.bodyMedium!.copyWith(color: scheme.onSurfaceVariant)),
          const SectionHeading('Form', padded: false),
          Row(children: [
            FormScarf(form: c.form),
            const SizedBox(width: 12),
            Expanded(child: Text(formVerdict(c.form), style: tt.bodyMedium)),
          ]),
          const SectionHeading('Season odds', padded: false),
          if (p == null)
            const EmptyNote('Odds appear once the live season has loaded.')
          else ...[
            ShareBar(label: 'Title', value: p.pTitle, colors: clubColors(c)),
            ShareBar(label: 'Top four', value: p.pTop4, colors: clubColors(c)),
            ShareBar(label: 'Bottom three', value: p.pReleg, colors: clubColors(c)),
            const SizedBox(height: 6),
            Text('Expected finish ${ordinal(p.expPos.round())} on about '
                '${p.expPoints.round()} points.', style: tt.bodyMedium),
          ],
          const SectionHeading('Power rating', padded: false),
          Text('Power rating ${c.elo.round()}, ${change >= 0 ? 'up' : 'down'} '
              '${change.abs().round()} this month', style: tt.titleMedium),
          const SectionHeading('Fixtures', padded: false),
          if (fixtures.isEmpty)
            const EmptyNote('No fixtures in the window we track.')
          else
            for (final f in fixtures)
              FixtureRow(fixture: f, home: b.clubById[f.home], away: b.clubById[f.away],
                  now: s.now),
          const SectionHeading('Squad', padded: false),
          if (players.isEmpty)
            const EmptyNote('No squad data for this club yet.')
          else
            for (final pl in players.take(30))
              PlayerRow(
                player: pl,
                subtitle: '${pl.subPos ?? pl.pos ?? ''}${pl.age == null ? '' : ' · ${pl.age!.floor()}'}',
                trailing: Text(money(pl.marketValue), style: tt.labelLarge),
                onTap: () => openPlayer(context, pl.id),
              ),
        ],
      ),
    );
  }
}
