import 'package:flutter/material.dart';

import '../copy/voice.dart';
import '../data/bundle.dart';
import '../data/selectors.dart';
import '../format.dart';
import '../state/app_state.dart';
import '../theme/theme.dart';
import '../theme/tokens.dart';
import '../widgets/brand.dart';
import '../widgets/empty_note.dart';
import '../widgets/halftone.dart';
import '../widgets/league_chips.dart';
import '../widgets/player_avatar.dart';
import '../widgets/print.dart';
import '../widgets/rows.dart';
import '../widgets/section.dart';
import 'about_sheet.dart';
import 'big_five_screen.dart';
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
          toolbarHeight: 60,
          titleSpacing: 16,
          title: const Wordmark(),
          actions: [
            const FreshnessChip(),
            IconButton(tooltip: 'How this works', icon: const Icon(Icons.info_outline_rounded),
                onPressed: () => showAboutSheet(context)),
            const SizedBox(width: 4),
          ],
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(52),
            child: Padding(padding: EdgeInsets.only(bottom: 4), child: LeagueChips()),
          ),
        ),
        box(featured == null
            ? pad(const Padding(
                padding: EdgeInsets.only(top: 16),
                child: EmptyNote('No fixtures in the next seven days. '
                    'International break, probably.')))
            : MatchCover(fixture: featured)),
        if (favs.isNotEmpty) ...[
          box(const SectionHeading('Your players')),
          box(PlayerStrip(players: favs, onTap: (p) => openPlayer(context, p.id))),
        ],
        box(const SectionHeading('Running hot')),
        box(hot.isEmpty
            ? pad(const EmptyNote('Nobody is on a run worth shouting about.'))
            : PlayerStrip(players: hot, onTap: (p) => openPlayer(context, p.id))),
        if (b.prospects.isNotEmpty) ...[
          box(SectionHeading('Ready for the Big Five',
              note: b.prospectsByPrice
                  ? 'Feeder-league players the market rates highest. Our model couldn\'t '
                      'beat that, so we say so. Figure: G/A per 90 at top-five level.'
                  : 'Most likely to become regulars after a move.',
              action: 'All', onAction: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const BigFiveScreen())))),
          SliverList.list(children: [
            for (final (i, p) in b.prospects.take(5).indexed)
              ProspectRow(number: i + 1, prospect: p),
          ]),
        ],
        if (b.bounce != null) ...[
          box(const SectionHeading('Does sacking the manager work?')),
          box(pad(BounceFinding(bounce: b.bounce!))),
        ],
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
                FormBoxes(form: c.form, cell: 16),
                const SizedBox(width: 10),
                _EloDelta(c.eloChange30d),
              ]),
              onTap: () => openClub(context, c.id),
            ),
        ], 'No league games played yet.'),
        box(const SectionHeading('Power rankings')),
        list([
          for (final (i, c) in ranks.indexed)
            TeamSheetRow(
              number: i + 1,
              title: c.name,
              subtitle: b.leagueById[c.league]?.name ?? c.league,
              trailing: Text('${c.elo.round()}', style: tabular(tt.titleMedium!)),
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
                  style: tt.titleSmall!.copyWith(color: scheme.secondary)),
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
            Container(height: 3, color: scheme.onSurface),
            const SizedBox(height: 10),
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

/// The programme cover: the week's big match, each half printed in its club's colour with
/// that club's most valuable player as a halftone, then the printed result strip.
class MatchCover extends StatelessWidget {
  const MatchCover({super.key, required this.fixture});
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
    final (hc, ac) = matchColors(home, away);
    final width = MediaQuery.sizeOf(context).width;
    final portraitH = (width * 0.62).clamp(220.0, 360.0);

    Widget half(Club? club, Color colour, String name, Alignment align) {
      final star = club == null ? null : squad(b, club.id).firstOrNull;
      return Expanded(
        child: Container(
          color: colour,
          height: portraitH,
          child: Stack(fit: StackFit.expand, children: [
            // the star printed straight onto the club's half, edge to edge
            if (star != null)
              Positioned.fill(
                bottom: 64,
                child: HalftonePortrait(
                  url: star.img, ink: inkOnField(club, colour), paper: colour, columns: 44,
                  fallback: const SizedBox.shrink()),
              ),
            Positioned(
              left: 10, right: 10, bottom: 8,
              child: Column(
                crossAxisAlignment: align == Alignment.bottomLeft
                    ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                children: [
                  if (star != null)
                    Text(star.name.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall!
                            .copyWith(color: onColor(colour), letterSpacing: 0.8)),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: align,
                    child: Text(name.toUpperCase(), style: masthead(34, onColor(colour))),
                  ),
                ],
              ),
            ),
          ]),
        ),
      );
    }

    return Semantics(
      button: true,
      label: '$hn v $an, ${kickoffLabel(f.kickoff, s.now)}. $hn win ${pct(f.p[0])}, '
          'draw ${pct(f.p[1])}, $an win ${pct(f.p[2])}. ${fixtureVerdict(hn, an, f.p)}',
      onTap: () => showMatchSheet(context, f),
      excludeSemantics: true,
      child: InkWell(
        onTap: () => showMatchSheet(context, f),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          ExcludeSemantics(
            child: Row(children: [
              half(home, hc, hn, Alignment.bottomLeft),
              Container(width: 3, height: portraitH, color: scheme.surface),
              half(away, ac, an, Alignment.bottomRight),
            ]),
          ),
          Container(
            color: TL.yellow,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: ExcludeSemantics(
              child: Text(
                  '${kickoffLabel(f.kickoff, s.now)} · ${b.leagueById[f.league]?.name ?? ''}'
                      .toUpperCase(),
                  style: tt.labelLarge!.copyWith(color: TL.ink, letterSpacing: 0.6)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: ResultStrip(fixture: f, home: home, away: away, hero: true),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: ExcludeSemantics(
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(child: Text(fixtureVerdict(hn, an, f.p), style: tt.titleLarge)),
                const SizedBox(width: 8),
                Text('Breakdown', style: tt.labelLarge!.copyWith(color: scheme.primary)),
                Icon(Icons.chevron_right_rounded, color: scheme.primary),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

/// The sacking-bounce finding as a printed feature: three bars around zero, then the words.
class BounceFinding extends StatelessWidget {
  const BounceFinding({super.key, required this.bounce});
  final Bounce bounce;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final bars = [
      ('Last 10 before the sacking', bounce.before),
      ("New manager's first 10", bounce.first10),
      if (bounce.control case final c?) ('Kept the manager: next 10', c),
    ];
    final maxAbs = bars.map((e) => e.$2.abs()).reduce((a, b) => a > b ? a : b);
    const h = 64.0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Semantics(
        label: 'Points per game against expectation: '
            '${bars.map((e) => '${e.$1} ${signed(e.$2, digits: 2)}').join(', ')}',
        child: ExcludeSemantics(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final (label, v) in bars)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(signed(v, digits: 2),
                        style: masthead(30, v < 0 ? scheme.primary : scheme.onSurface)),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: h * 2 + 1,
                      child: Column(children: [
                        Expanded(child: Align(alignment: Alignment.bottomLeft,
                            child: FractionallySizedBox(widthFactor: 0.5,
                                heightFactor: v > 0 ? v / maxAbs : 0,
                                child: ColoredBox(color: scheme.onSurface)))),
                        Container(height: 1, color: scheme.onSurface),
                        Expanded(child: Align(alignment: Alignment.topLeft,
                            child: FractionallySizedBox(widthFactor: 0.5,
                                heightFactor: v < 0 ? -v / maxAbs : 0,
                                child: ColoredBox(color: scheme.primary)))),
                      ]),
                    ),
                    const SizedBox(height: 6),
                    Text(label, style: tt.labelMedium),
                  ]),
                ),
              ),
          ]),
        ),
      ),
      const SizedBox(height: 12),
      Text(bounceVerdict(bounce), style: tt.bodyMedium),
    ]);
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
          Icon(up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 16,
              color: up ? scheme.onSurface : scheme.primary),
          Text('${delta.abs().round()}', style: Theme.of(context).textTheme.labelLarge),
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
        Icon(Icons.warning_amber_rounded, size: 18, color: scheme.primary,
            semanticLabel: 'Unusual load'),
      const SizedBox(width: 4),
      Text('${w.band} · ${w.index}', style: tt.labelLarge),
    ]);
  }
}
