import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../copy/voice.dart';
import '../data/bundle.dart';
import '../data/selectors.dart';
import '../format.dart';
import '../state/app_state.dart';
import '../widgets/empty_note.dart';
import '../widgets/player_avatar.dart';
import '../widgets/rows.dart';
import '../widgets/section.dart';
import '../widgets/stat_bar.dart';
import '../widgets/value_chart.dart';
import 'routes.dart';

class PlayerDetailScreen extends StatelessWidget {
  const PlayerDetailScreen({super.key, required this.playerId});
  final int playerId;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final b = s.bundle!;
    final p = b.playerById[playerId];
    if (p == null) {
      return Scaffold(appBar: AppBar(),
          body: const Padding(padding: EdgeInsets.all(16),
              child: EmptyNote('This player is no longer in the data.')));
    }
    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final fav = s.isFavourite(p.id);
    final muted = tt.bodyMedium!.copyWith(color: scheme.onSurfaceVariant);
    final cheaper = similarCheaper(b, p).map((x) => x.id).toSet();
    final similar = [for (final id in p.similar) ?b.playerById[id]];
    return Scaffold(
      appBar: AppBar(title: Text(p.name), actions: [
        IconButton(
          tooltip: 'Compare',
          icon: const Icon(Icons.compare_arrows_rounded),
          onPressed: () => openCompare(context, p.id),
        ),
        IconButton(
          tooltip: fav ? 'Remove from your players' : 'Add to your players',
          icon: Icon(fav ? Icons.star_rounded : Icons.star_outline_rounded),
          onPressed: () => s.toggleFavourite(p.id),
        ),
      ]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            PlayerAvatar(player: p, size: 84),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.name, style: tt.titleLarge),
                if (p.clubName != null)
                  InkWell(
                    onTap: p.club != null && b.clubById.containsKey(p.club)
                        ? () => openClub(context, p.club!)
                        : null,
                    child: Padding(padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(p.clubName!, style: tt.titleSmall!
                            .copyWith(color: scheme.primary))),
                  ),
                Text([
                  p.subPos ?? p.pos,
                  if (p.age != null) 'Age ${p.age!.floor()}',
                  p.nat,
                ].whereType<String>().join(' · '), style: muted),
              ]),
            ),
          ]),
          const SizedBox(height: 20),
          Text(playerVerdict(p), style: tt.titleMedium),
          const SizedBox(height: 6),
          Text('${b.playerSeason}: ${p.season.apps} apps · ${thousands(p.season.minutes)} min · '
              '${count(p.season.goals, 'goal')} · ${count(p.season.assists, 'assist')}', style: muted),
          const SectionHeading('Value', padded: false),
          ..._value(context, p),
          const SectionHeading('Form', padded: false),
          ..._form(context, p),
          const SectionHeading('Workload', padded: false),
          ..._workload(context, p),
          const SectionHeading('Market value over time', padded: false),
          ValueChart(points: p.valueHistory),
          const SectionHeading('Transfers', padded: false),
          if (p.transfers.isEmpty)
            const EmptyNote('No transfers on record.')
          else
            for (final t in p.transfers.reversed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  SizedBox(width: 64, child: Text('${t.date.year}', style: tt.labelLarge)),
                  Expanded(child: Text('${t.from ?? '?'} → ${t.to ?? '?'}',
                      style: tt.bodyMedium, maxLines: 2)),
                  Text(t.fee == null ? '–' : t.fee == 0 ? 'Free' : money(t.fee),
                      style: tt.labelLarge),
                ]),
              ),
          const SectionHeading('Plays like', padded: false),
          if (similar.isEmpty)
            const EmptyNote('Not enough minutes to find lookalikes.')
          else
            Transform.translate(
              offset: const Offset(-16, 0),
              child: SizedBox(
                width: MediaQuery.sizeOf(context).width,
                child: PlayerStrip(
                  players: similar,
                  notes: (x) => cheaper.contains(x.id) ? 'Cheaper · ${money(x.marketValue)}'
                      : money(x.marketValue),
                  onTap: (x) => openPlayer(context, x.id),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _value(BuildContext context, Player p) {
    final tt = Theme.of(context).textTheme;
    final fv = p.fairValue, mv = p.marketValue;
    if (fv == null) {
      return [
        Text('Market ${money(mv)}', style: tt.titleMedium),
        const EmptyNote('Not enough minutes yet for a fair-value read.'),
      ];
    }
    final gap = fv - (mv ?? 0);
    final why = p.valueWhy ?? const <ValueWhy>[];
    final maxAbs = why.isEmpty ? 1.0 : why.map((w) => w.effectPct.abs()).reduce(math.max);
    return [
      Text('Market ${money(mv)} · Fair ${money(fv)}', style: tt.titleMedium),
      const SizedBox(height: 4),
      Text(gap >= 0
          ? 'The numbers say ${signedMoney(gap)} more than his price.'
          : 'Priced ${money(-gap)} above what the numbers show.', style: tt.bodyMedium),
      if (why.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text('What moves his value', style: tt.titleSmall),
        for (final w in why) EffectBar(label: w.label, effect: w.effectPct, maxAbs: maxAbs),
      ],
    ];
  }

  List<Widget> _form(BuildContext context, Player p) {
    final tt = Theme.of(context).textTheme;
    return [
      if (p.last5.isEmpty)
        const EmptyNote('No recent appearances.')
      else
        for (final g in p.last5.reversed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              SizedBox(width: 64, child: Text(shortDate(g.date), style: tt.labelLarge)),
              Expanded(child: Text(g.opp ?? 'Unknown opponent', style: tt.bodyMedium,
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
              Text('${g.ga} G/A · ${g.minutes}′', style: tt.labelLarge),
            ]),
          ),
      const SizedBox(height: 8),
      if (p.forecastGa5 == null)
        const EmptyNote('Not enough minutes yet for a forecast.')
      else
        Text('Projected ${p.forecastGa5!.toStringAsFixed(1)} goal involvements in the next five.',
            style: tt.titleMedium),
    ];
  }

  List<Widget> _workload(BuildContext context, Player p) {
    final tt = Theme.of(context).textTheme;
    final w = p.workload;
    if (w == null) return const [EmptyNote('No appearances to measure.')];
    return [
      Text('${w.band} · ${workloadVerdict(w.band)}', style: tt.titleMedium),
      ShareBar(label: 'Risk index', value: w.index / 100),
      Text('${thousands(w.seasonMinutes)} minutes · ${w.congestedApps} games on short rest · '
          'as of ${shortDate(w.asOf)}', style: tt.bodyMedium),
      const SizedBox(height: 4),
      Text('A workload risk index, not an injury prediction.',
          style: tt.bodySmall!.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
    ];
  }
}
