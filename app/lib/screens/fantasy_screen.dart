import 'package:flutter/material.dart';

import '../fpl/fpl_bundle.dart';
import '../fpl/fpl_state.dart';
import '../fpl/squad.dart';
import '../theme/theme.dart';
import '../theme/tokens.dart';
import '../widgets/brand.dart';
import '../widgets/empty_note.dart';
import '../widgets/fpl_pitch.dart';
import '../widgets/print.dart';
import '../widgets/section.dart';
import 'squad_picker_screen.dart';

String _m(int tenths) => '£${(tenths / 10).toStringAsFixed(1)}m';
String _pts(double v) => v.toStringAsFixed(1);

String deadlineLabel(DateTime d, DateTime now) {
  final local = d.toLocal();
  final left = d.difference(now);
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final hm = '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  final when = '${days[local.weekday - 1]} $hm';
  if (left.isNegative) return 'Deadline passed';
  if (left.inHours < 24) return 'Deadline in ${left.inHours}h ${left.inMinutes % 60}m · $when';
  return 'Deadline ${left.inDays}d ${left.inHours % 24}h · $when';
}

class FantasyScreen extends StatelessWidget {
  const FantasyScreen({super.key, this.now});
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final s = FplScope.of(context);
    final b = s.bundle;
    return Scaffold(
      appBar: AppBar(title: const ScreenTitle('Fantasy'), actions: [
        if (s.squad != null)
          IconButton(tooltip: 'Edit squad', icon: const Icon(Icons.edit_outlined),
              onPressed: () => openSquadPicker(context)),
        IconButton(tooltip: 'How this works', icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => _showMethod(context, b)),
      ]),
      body: b == null
          ? Center(child: s.loading ? const CircularProgressIndicator()
              : const Padding(padding: EdgeInsets.all(16),
                  child: EmptyNote('Fantasy data could not be opened.')))
          : s.squad == null
              ? _Start(bundle: b)
              : _Week(bundle: b, now: now ?? DateTime.now()),
    );
  }
}

class _Start extends StatelessWidget {
  const _Start({required this.bundle});
  final FplBundle bundle;

  @override
  Widget build(BuildContext context) {
    final s = FplScope.of(context);
    final tt = Theme.of(context).textTheme;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
      const SectionHeading('Your FPL team', padded: false,
          note: 'Expected points for every Premier League player over the next six '
              'gameweeks, the best transfers for your squad, your captain and when to play '
              'each chip.'),
      if (s.canImport) ...[
        FilledButton.icon(onPressed: () => _askTeamId(context),
            icon: const Icon(Icons.download_rounded), label: const Text('Import by team ID')),
        const SizedBox(height: 4),
        Text('Find it in the FPL website address: fantasy.premierleague.com/entry/ID/…',
            style: tt.bodySmall),
        const SizedBox(height: 12),
      ],
      OutlinedButton.icon(onPressed: () => openSquadPicker(context),
          icon: const Icon(Icons.checklist_rounded), label: const Text('Pick your 15')),
      const SizedBox(height: 12),
      TextButton(
        onPressed: () {
          final wc = bundle.wildcard.firstWhere((w) => w.budget == 1000,
              orElse: () => bundle.wildcard.first);
          s.saveSquad(Squad(ids: wc.squad, bank: 1000 - wc.squad.fold<int>(
              0, (a, id) => a + (bundle.byId[id]?.price ?? 0))));
        },
        child: const Text('Or start from our best £100m squad'),
      ),
    ]);
  }
}

Future<void> _askTeamId(BuildContext context) async {
  final s = FplScope.of(context);
  final ctrl = TextEditingController();
  final id = await showDialog<int>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Import your FPL team'),
      content: TextField(controller: ctrl, keyboardType: TextInputType.number,
          autofocus: true, decoration: const InputDecoration(labelText: 'Team ID')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, int.tryParse(ctrl.text.trim())),
            child: const Text('Import')),
      ],
    ),
  );
  if (id == null || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await s.importById(id);
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('$e')));
  }
}

class _Week extends StatelessWidget {
  const _Week({required this.bundle, required this.now});
  final FplBundle bundle;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final s = FplScope.of(context);
    final a = s.advice!;
    final sq = s.squad!;
    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final gw = bundle.nextGameweek;
    final missing = sq.ids.where((i) => !bundle.byId.containsKey(i)).length;

    return ListView(padding: const EdgeInsets.only(bottom: 32), children: [
      Container(
        color: TL.yellow,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
            '${gw?.name ?? 'Next gameweek'} · '
            '${gw == null ? '' : deadlineLabel(gw.deadline, now)}'.toUpperCase(),
            style: tt.labelLarge!.copyWith(color: TL.ink, letterSpacing: 0.6)),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(child: Text((sq.teamName ?? 'Your squad').toUpperCase(),
              style: masthead(30, scheme.onSurface), maxLines: 1,
              overflow: TextOverflow.ellipsis)),
          Text('Bank ${_m(sq.bank)}', style: tt.labelLarge),
        ]),
      ),
      if (bundle.source == 'fpl')
        const Padding(padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: EmptyNote("These are FPL's own expected points: our model didn't beat "
                'them in its latest test, so we show theirs.')),
      if (missing > 0)
        Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: EmptyNote('$missing of your players are not in our data yet. '
                'Swap them in the squad editor.')),
      if (!a.complete)
        const Padding(padding: EdgeInsets.all(16),
            child: EmptyNote('Your squad needs 15 known players for advice.'))
      else ...[
        _xi(context, a),
        _moves(context, a, sq),
        _chips(context, a),
      ],
    ]);
  }

  Widget _xi(BuildContext context, FplAdvice a) {
    final x = a.xi!;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionHeading('Your XI · ${_pts(x.points)} pts',
          note: 'Expected points for ${bundle.nextGameweek?.name ?? 'the next gameweek'}, '
              'captain counted twice. Tap a player for his forecast.'),
      FplPitch(bundle: bundle, xi: x, onTap: (p) => showFplPlayer(context, bundle, p)),
    ]);
  }

  Widget _moves(BuildContext context, FplAdvice a, Squad sq) {
    final s = FplScope.of(context);
    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final best = a.bestPlan;
    final rows = <Widget>[
      const SectionHeading("This week's moves",
          note: 'Judged on expected points over the next five gameweeks. A −4 hit is only '
              'suggested when it pays back with a point to spare.'),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          Text('Free transfers', style: tt.bodyMedium),
          const Spacer(),
          IconButton(tooltip: 'One fewer free transfer',
              icon: const Icon(Icons.remove_circle_outline_rounded),
              onPressed: sq.freeTransfers > 0
                  ? () => s.saveSquad(sq.copyWith(freeTransfers: sq.freeTransfers - 1)) : null),
          Text('${sq.freeTransfers}', style: tabular(tt.titleMedium!)),
          IconButton(tooltip: 'One more free transfer',
              icon: const Icon(Icons.add_circle_outline_rounded),
              onPressed: sq.freeTransfers < 5
                  ? () => s.saveSquad(sq.copyWith(freeTransfers: sq.freeTransfers + 1)) : null),
        ]),
      ),
    ];
    if (best == null || best.transfers.isEmpty) {
      rows.add(const Padding(padding: EdgeInsets.symmetric(horizontal: 16),
          child: EmptyNote('No move beats rolling the transfer. Save it for next week.')));
    } else {
      for (final (o, i) in best.transfers) {
        final out = a.bundle.byId[o]!, inn = a.bundle.byId[i]!;
        rows.add(TeamSheetRow(
          title: '${out.name} → ${inn.name}',
          subtitle: '${_m(out.price)} out · ${_m(inn.price)} in · '
              '${a.bundle.teamById[inn.team]?.short ?? ''}',
          trailing: Text('${_pts(inn.horizon())} pts', style: tabular(tt.titleSmall!)),
          onTap: () => showFplPlayer(context, a.bundle, inn),
        ));
      }
      rows.add(Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Text(
            best.hits > 0
                ? '+${_pts(best.gain)} pts over five gameweeks, minus a ${best.hits}-point hit: '
                    'worth it by ${_pts(best.gain - best.hits)}.'
                : '+${_pts(best.gain)} pts over five gameweeks, using free transfers.',
            style: tt.bodyMedium!.copyWith(color: scheme.onSurface)),
      ));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
  }

  Widget _chips(BuildContext context, FplAdvice a) {
    final tt = Theme.of(context).textTheme;
    if (a.chips.isEmpty) {
      return const Column(children: [
        SectionHeading('Chips'),
        Padding(padding: EdgeInsets.symmetric(horizontal: 16),
            child: EmptyNote('No chips left in this half of the season.')),
      ]);
    }
    String verdict(ChipAdvice c) => switch (c.chip) {
          'wildcard' => c.recommend
              ? 'Play it now: a rebuild adds ${_pts(c.gain)} pts over five gameweeks.'
              : c.gain < 0.5
                  ? 'Hold. A rebuild would not beat the squad you have.'
                  : 'Hold. A rebuild would add ${_pts(c.gain)} pts, below the 12 that justifies it.',
          'freehit' => c.recommend
              ? 'GW${c.gw}: a one-week team beats yours by ${_pts(c.gain)}.'
              : 'Hold. Best week is GW${c.gw} at +${_pts(c.gain)}, below the 15 that justifies it.',
          '3xc' => 'Best week GW${c.gw}: ${a.bundle.byId[c.player]?.name ?? 'your captain'} '
              'expects ${_pts(c.gain)} pts.',
          _ => 'Best week GW${c.gw}: your bench expects ${_pts(c.gain)} pts.',
        };
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionHeading('Chip planner',
          note: 'Over the next six gameweeks. Chips you have already used this half are left '
              'out.'),
      for (final c in a.chips.values)
        TeamSheetRow(
          title: chipNames[c.chip]!,
          subtitle: verdict(c) + (c.over ? ' (needs more budget than you have)' : ''),
          trailing: c.chip == 'wildcard' || c.chip == 'freehit'
              ? Text(c.recommend ? 'PLAY' : 'HOLD', style: tt.labelLarge)
              : Text('GW${c.gw}', style: tabular(tt.titleSmall!)),
        ),
    ]);
  }
}

Future<void> showFplPlayer(BuildContext context, FplBundle b, FplPlayer p) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final tt = Theme.of(ctx).textTheme;
        final scheme = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
            Text(p.full.toUpperCase(), style: masthead(30, scheme.onSurface)),
            Text('${b.teamById[p.team]?.name ?? ''} · ${p.pos} · ${_m(p.price)} · '
                '${p.sel.toStringAsFixed(1)}% own', style: tt.bodyMedium),
            if (p.news != null) ...[
              const SizedBox(height: 6),
              Text(p.news!, style: tt.bodyMedium!.copyWith(color: scheme.primary)),
            ],
            const SizedBox(height: 10),
            Text('${(p.pPlay * 100).round()}% to play next gameweek', style: tt.titleMedium),
            const SectionHeading('Expected points', padded: false),
            for (final (k, g) in b.gameweeks.indexed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  SizedBox(width: 64, child: Text('GW${g.id}', style: tt.labelLarge)),
                  Expanded(child: ShareTrack(
                      value: (k < p.xpts.length ? p.xpts[k] : 0) / 12,
                      color: scheme.primary, height: 10)),
                  SizedBox(width: 48, child: Text(
                      _pts(k < p.xpts.length ? p.xpts[k] : 0), textAlign: TextAlign.end,
                      style: tabular(tt.labelLarge!))),
                ]),
              ),
            if (p.why != null) ...[
              const SectionHeading('Where the points come from', padded: false),
              for (final e in p.why!.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(children: [
                    Expanded(child: Text(_whyLabel[e.key] ?? e.key, style: tt.bodyMedium)),
                    Text(_pts(e.value), style: tabular(tt.labelLarge!)),
                  ]),
                ),
            ],
          ]),
        );
      },
    );

const _whyLabel = {
  'minutes': 'Playing time (appearance points)',
  'attack': 'Goals and assists',
  'defence': 'Clean sheet, minus goals conceded',
  'bonus': 'Bonus',
  'other': 'Saves, defensive work, cards',
};

void _showMethod(BuildContext context, FplBundle? b) {
  final m = b?.models ?? const {};
  num? n(String k) => m[k] as num?;
  final text = m.isEmpty
      ? 'Expected points come from a model of minutes, goals, assists and clean sheets.'
      : 'Expected points are built from four parts: the chance a player plays, his goals and '
          'assists per 90 (shrunk toward his position\'s average when the sample is small), '
          "fixture strength from Touchline's match model, and FPL's scoring rules.\n\n"
          'Tested on the ${m['test_season']} season it never saw, against FPL\'s own expected '
          'points: average miss ${n('mae')?.toStringAsFixed(2)} vs '
          '${n('mae_fpl')?.toStringAsFixed(2)} points per player-gameweek, and captain picks '
          'scoring ${n('captain_points')?.round()} vs ${n('captain_points_fpl')?.round()} over '
          'the season. The captaincy edge is small.\n\n'
          'Transfers are searched exhaustively for up to two moves; Wildcard and Free Hit teams '
          'are solved exactly for your budget.';
  showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => SafeArea(child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        Text('HOW FANTASY WORKS', style: masthead(30, Theme.of(ctx).colorScheme.onSurface)),
        const SizedBox(height: 8),
        Text(text, style: Theme.of(ctx).textTheme.bodyMedium),
      ]),
    )),
  );
}
