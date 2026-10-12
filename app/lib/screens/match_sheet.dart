import 'package:flutter/material.dart';

import '../copy/voice.dart';
import '../data/bundle.dart';
import '../format.dart';
import '../state/app_state.dart';
import '../theme/theme.dart';
import '../widgets/print.dart';
import '../widgets/section.dart';
import '../widgets/stat_bar.dart';
import 'club_detail_screen.dart';

Future<void> showMatchSheet(BuildContext context, Fixture f) => showModalBottomSheet<void>(
    context: context, isScrollControlled: true, builder: (_) => MatchSheet(fixture: f));

class MatchSheet extends StatelessWidget {
  const MatchSheet({super.key, required this.fixture});
  final Fixture fixture;

  void _openClub(BuildContext context, int id) {
    final nav = Navigator.of(context);
    nav.pop();
    nav.push(MaterialPageRoute<void>(builder: (_) => ClubDetailScreen(clubId: id)));
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final b = s.bundle!;
    final f = fixture;
    final home = b.clubById[f.home];
    final away = b.clubById[f.away];
    final hn = home?.name ?? 'Home', an = away?.name ?? 'Away';
    final tt = Theme.of(context).textTheme;
    final muted = tt.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Text('${hn.toUpperCase()} v ${an.toUpperCase()}',
              style: masthead(34, Theme.of(context).colorScheme.onSurface)),
          Text('${kickoffLabel(f.kickoff, s.now)} · ${b.leagueById[f.league]?.name ?? f.league}',
              style: muted),
          const SizedBox(height: 16),
          ResultStrip(fixture: f, home: home, away: away, hero: true),
          const SizedBox(height: 12),
          Text(fixtureVerdict(hn, an, f.p), style: tt.titleMedium),
          if (f.score != null) ...[
            const SizedBox(height: 6),
            Text('Final score ${f.score![0]}–${f.score![1]}', style: tt.titleMedium),
          ],
          const SizedBox(height: 12),
          ShareBar(label: hn, value: f.p[0]),
          ShareBar(label: 'Draw', value: f.p[1]),
          ShareBar(label: an, value: f.p[2]),
          const SizedBox(height: 6),
          Text('Expected goals: $hn ${f.xg[0].toStringAsFixed(1)} · '
              '$an ${f.xg[1].toStringAsFixed(1)}', style: muted),
          const SectionHeading('Form', padded: false),
          for (final c in [home, away])
            if (c != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  SizedBox(width: 120, child: Text(c.name, style: tt.bodyMedium,
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                  FormBoxes(form: c.form, cell: 20),
                ]),
              ),
          const SizedBox(height: 16),
          Row(children: [
            if (home != null)
              Expanded(child: OutlinedButton(
                  onPressed: () => _openClub(context, home.id), child: Text(hn))),
            if (home != null && away != null) const SizedBox(width: 12),
            if (away != null)
              Expanded(child: OutlinedButton(
                  onPressed: () => _openClub(context, away.id), child: Text(an))),
          ]),
        ],
      ),
    );
  }
}
