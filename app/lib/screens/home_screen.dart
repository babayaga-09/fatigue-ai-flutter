import 'package:flutter/material.dart';

import '../copy/voice.dart';
import '../data/bundle.dart';
import '../data/selectors.dart';
import '../format.dart';
import '../state/app_state.dart';
import '../widgets/brand.dart';
import '../widgets/crest.dart';
import '../widgets/empty_note.dart';
import '../widgets/league_chips.dart';
import '../widgets/rows.dart';
import '../widgets/scarf.dart';
import '../widgets/section.dart';
import 'about_sheet.dart';
import 'match_sheet.dart';
import 'routes.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final b = s.bundle!;
    final lg = s.league;
    final now = s.now;
    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final featured = featuredFixture(b, lg, now);
    final week = weekFixtures(b, lg, now).where((f) => f.id != featured?.id).take(6).toList();
    final hot = trendingPlayers(b, lg);
    final inForm = clubsInForm(b, lg);
    final ranks = powerRankings(b, lg);
    final deals = bargains(b, lg, n: 6);
    final tired = overworked(b, lg, n: 6);
    final favs = [for (final id in s.favourites) ?b.playerById[id]];

    Widget box(Widget w) => SliverToBoxAdapter(child: w);
    Widget pad(Widget w) =>
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: w);
    Widget list(List<Widget> rows, String empty) =>
        rows.isEmpty ? box(pad(EmptyNote(empty))) : SliverList.list(children: rows);

    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverAppBar(
          pinned: true,
          toolbarHeight: 64,
          titleSpacing: 16,
          title: const Wordmark(),
          actions: [
            const FreshnessChip(),
            IconButton(tooltip: 'How this works', icon: const Icon(Icons.info_outline_rounded),
                onPressed: () => showAboutSheet(context)),
            const SizedBox(width: 4),
          ],
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(60),
            child: Column(children: [BrandBand(), SizedBox(height: 4), LeagueChips()]),
          ),
        ),
        box(Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: featured == null
              ? const EmptyNote('No fixtures in the next seven days. International break, probably.')
              : HeroFixture(fixture: featured),
        )),
        if (favs.isNotEmpty) ...[
          box(const SectionHeading('Your players')),
          box(PlayerStrip(players: favs, onTap: (p) => openPlayer(context, p.id))),
        ],
        box(const SectionHeading('Running hot')),
        box(hot.isEmpty
            ? pad(const EmptyNote('Nobody is on a run worth shouting about.'))
            : PlayerStrip(players: hot, onTap: (p) => openPlayer(context, p.id))),
        box(const SectionHeading('This week')),
        list([
          for (final f in week)
            FixtureRow(fixture: f, home: b.clubById[f.home], away: b.clubById[f.away], now: now,
                onTap: () => showMatchSheet(context, f)),
        ], 'Nothing else on this week.'),
        box(const SectionHeading('Clubs in form')),
        list([
          for (final c in inForm)
            ClubRow(
              club: c,
              subtitle: formVerdict(c.form),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                FormScarf(form: c.form, cell: 16),
                const SizedBox(width: 10),
                _EloDelta(c.eloChange30d),
              ]),
              onTap: () => openClub(context, c.id),
            ),
        ], 'No league games played yet.'),
        box(const SectionHeading('Power rankings')),
        list([
          for (final (i, c) in ranks.indexed)
            ClubRow(
              club: c,
              subtitle: '${ordinal(i + 1)} · ${b.leagueById[c.league]?.name ?? c.league}',
              trailing: Text('${c.elo.round()}', style: tt.labelLarge),
              onTap: () => openClub(context, c.id),
            ),
        ], 'No ratings for this league.'),
        box(const SectionHeading('Bargains')),
        list([
          for (final p in deals)
            PlayerRow(
              player: p,
              subtitle: '${p.clubName ?? ''} · priced ${money(p.marketValue)}',
              trailing: Text(signedMoney(p.fairValue! - p.marketValue!),
                  style: tt.titleSmall!.copyWith(color: scheme.primary)),
              onTap: () => openPlayer(context, p.id),
            ),
        ], 'No clear bargains above ${money(bargainFloor)} here.'),
        box(const SectionHeading('Overworked watch')),
        list([
          for (final p in tired)
            PlayerRow(
              player: p,
              subtitle: '${thousands(p.workload!.seasonMinutes)} min · '
                  '${p.workload!.congestedApps} on short rest',
              trailing: _BandLabel(p.workload!),
              onTap: () => openPlayer(context, p.id),
            ),
        ], 'Nobody is carrying an unusual load.'),
        box(Padding(
          padding: const EdgeInsets.fromLTRB(16, 32, 16, 32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Club data from ${shortDate(DateTime.parse(b.clubsThrough))}. '
                'Player stats: ${b.playerSeason} season.',
                style: tt.bodySmall!.copyWith(color: scheme.onSurfaceVariant)),
            TextButton(onPressed: () => showAboutSheet(context),
                child: const Text('How the numbers are made')),
          ]),
        )),
      ]),
    );
  }
}

class HeroFixture extends StatelessWidget {
  const HeroFixture({super.key, required this.fixture});
  final Fixture fixture;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final b = s.bundle!;
    final f = fixture;
    final home = b.clubById[f.home], away = b.clubById[f.away];
    final hn = home?.name ?? 'Home', an = away?.name ?? 'Away';
    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showMatchSheet(context, f),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$hn v $an', style: tt.titleLarge),
            Text('${kickoffLabel(f.kickoff, s.now)} · ${b.leagueById[f.league]?.name ?? ''}',
                style: tt.bodyMedium!.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            Row(children: [
              Crest(club: home, size: 36),
              const SizedBox(width: 8),
              Expanded(child: FixtureScarf(fixture: f, home: home, away: away, hero: true)),
              const SizedBox(width: 8),
              Crest(club: away, size: 36),
            ]),
            const SizedBox(height: 14),
            Text(fixtureVerdict(hn, an, f.p), style: tt.titleMedium),
            const SizedBox(height: 4),
            Row(children: [
              Expanded(
                child: Text(
                    'Expected goals ${f.xg[0].toStringAsFixed(1)}–${f.xg[1].toStringAsFixed(1)}',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: tt.bodyMedium!.copyWith(color: scheme.onSurfaceVariant)),
              ),
              Text('Breakdown', style: tt.labelLarge!.copyWith(color: scheme.primary)),
              Icon(Icons.chevron_right_rounded, color: scheme.primary),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _EloDelta extends StatelessWidget {
  const _EloDelta(this.delta);
  final double delta;

  @override
  Widget build(BuildContext context) {
    final up = delta >= 0;
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Rating ${up ? 'up' : 'down'} ${delta.abs().round()} in 30 days',
      child: ExcludeSemantics(
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(up ? Icons.trending_up_rounded : Icons.trending_down_rounded, size: 18,
              color: up ? scheme.primary : scheme.tertiary),
          Text('${up ? '+' : '−'}${delta.abs().round()}',
              style: Theme.of(context).textTheme.labelLarge),
        ]),
      ),
    );
  }
}

class _BandLabel extends StatelessWidget {
  const _BandLabel(this.w);
  final Workload w;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      if (w.flag)
        Icon(Icons.warning_amber_rounded, size: 18, color: scheme.tertiary,
            semanticLabel: 'Unusual load'),
      const SizedBox(width: 4),
      Text('${w.band} · ${w.index}', style: tt.labelLarge),
    ]);
  }
}
