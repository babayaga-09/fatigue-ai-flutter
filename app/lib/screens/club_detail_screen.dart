import 'package:flutter/material.dart';

import '../copy/voice.dart';
import '../data/selectors.dart';
import '../format.dart';
import '../state/app_state.dart';
import '../widgets/crest.dart';
import '../widgets/empty_note.dart';
import '../widgets/rows.dart';
import '../theme/theme.dart';
import '../widgets/print.dart';
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
      return Scaffold(
        appBar: AppBar(),
        body: const Padding(
          padding: EdgeInsets.all(16),
          child: EmptyNote('This club is no longer in the data.'),
        ),
      );
    }
    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final p = c.proj;
    final fixtures = clubFixtures(b, c.id);
    final players = squad(b, c.id);
    final tired = players.where((p) => p.workload != null).toList()
      ..sort(
        (a, x) => ((x.workload!.flag ? 1000 : 0) + x.workload!.index).compareTo(
          (a.workload!.flag ? 1000 : 0) + a.workload!.index,
        ),
      );
    final change = c.eloChange30d;
    final accent = clubColors(c).first.computeLuminance() > 0.7
        ? scheme.onSurface
        : clubColors(c).first;
    final boss = b.managerByClub[c.id];
    final sheet = teamSheet(b, c.id);
    return Scaffold(
      appBar: AppBar(title: Text(c.name)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: _gutter([
          ClubBand(club: c),
          const SizedBox(height: 16),
          Row(
            children: [
              Crest(club: c, size: 44),
              const SizedBox(width: 12),
              Expanded(child: Text(clubVerdict(c), style: tt.titleMedium)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${b.leagueById[c.league]?.name ?? c.league} · ${ordinal(c.table.pos)} · '
            '${c.table.points} pts from ${c.table.played}',
            style: tt.bodyMedium!.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SectionHeading('Form', padded: false),
          Row(
            children: [
              FormBoxes(form: c.form),
              const SizedBox(width: 12),
              Expanded(child: Text(formVerdict(c.form), style: tt.bodyMedium)),
            ],
          ),
          const SectionHeading('Season odds', padded: false),
          if (p == null)
            const EmptyNote('Odds appear once the live season has loaded.')
          else ...[
            ShareBar(label: 'Title', value: p.pTitle, colors: [accent]),
            ShareBar(label: 'Top four', value: p.pTop4, colors: [accent]),
            ShareBar(label: 'Bottom three', value: p.pReleg, colors: [accent]),
            const SizedBox(height: 6),
            Text(
              'Expected finish ${ordinal(p.expPos.round())} on about '
              '${p.expPoints.round()} points.',
              style: tt.bodyMedium,
            ),
          ],
          if (b.managers.isNotEmpty) ...[
            SectionHeading(
              'Manager',
              padded: false,
              note: 'Luck-adjusted. ${managerTrust(b.managerSplitHalf)}',
            ),
            if (boss == null)
              const EmptyNote('No manager on record for this club.')
            else ...[
              Text(boss.name.toUpperCase(), style: masthead(30, scheme.onSurface)),
              const SizedBox(height: 4),
              Text(
                '${managerLine(boss.per38)}: ${signed(boss.per38)} points per 38 games '
                'over ${boss.games} games since ${monthYear(boss.since)}.',
                style: tt.bodyMedium,
              ),
            ],
          ],
          if (b.players.any((p) => p.dependency != null)) ...[
            const SectionHeading(
              'With and without them',
              padded: false,
              note:
                  'Points per game against expectation with each player, minus without. '
                  'A description of this season, not a ranking: it barely repeats from one '
                  'half-season to the next.',
            ),
            if (sheet.isEmpty)
              const EmptyNote('Nobody has missed enough games to compare yet.')
            else
              for (final pl in sheet)
                TeamSheetRow(
                  title: pl.name,
                  subtitle:
                      '${dependencyLine(pl.dependency!.index)} · played '
                      '${pl.dependency!.played}, missed ${pl.dependency!.missed}',
                  trailing: Text(
                    signed(pl.dependency!.index, digits: 2),
                    style: tabular(tt.titleMedium!),
                  ),
                  onTap: () => openPlayer(context, pl.id),
                ),
          ],
          const SectionHeading('Power rating', padded: false),
          Text(
            '${c.elo.round()}, ${change >= 0 ? 'up' : 'down'} '
            '${change.abs().round()} this month',
            style: tt.titleMedium,
          ),
          const SectionHeading('Fixtures', padded: false),
          if (fixtures.isEmpty)
            const EmptyNote('No fixtures in the window we track.')
          else
            for (final f in fixtures)
              FixtureRow(
                fixture: f,
                home: b.clubById[f.home],
                away: b.clubById[f.away],
                now: s.now,
              ),
          const SectionHeading('Workload watch', padded: false),
          if (tired.isEmpty)
            const EmptyNote('No workload data for this squad yet.')
          else
            for (final pl in tired.take(3))
              PlayerRow(
                player: pl,
                subtitle:
                    '${thousands(pl.workload!.seasonMinutes)} min · '
                    '${pl.workload!.congestedApps} on short rest',
                trailing: Text(
                  '${pl.workload!.band} · ${pl.workload!.index}',
                  style: tt.labelLarge,
                ),
                onTap: () => openPlayer(context, pl.id),
              ),
          const SectionHeading('Squad', padded: false),
          if (players.isEmpty)
            const EmptyNote('No squad data for this club yet.')
          else
            for (final pl in players.take(30))
              PlayerRow(
                player: pl,
                subtitle:
                    '${pl.subPos ?? pl.pos ?? ''}${pl.age == null ? '' : ' · ${pl.age!.floor()}'}',
                trailing: Text(money(pl.marketValue), style: tt.labelLarge),
                onTap: () => openPlayer(context, pl.id),
              ),
        ]),
      ),
    );
  }
}

/// One page gutter: full-width rows carry their own 16px inset; everything else gets it here,
/// so every trailing figure and every rule ends on the same edge.
List<Widget> _gutter(List<Widget> items) => [
      for (final w in items)
        w is FixtureRow || w is PlayerRow || w is TeamSheetRow
            ? w
            : Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: w),
    ];
