import 'package:flutter/material.dart';

import '../data/bundle.dart';
import '../format.dart';
import 'crest.dart';
import '../theme/theme.dart';
import 'player_avatar.dart';
import 'print.dart';

class _RowShell extends StatelessWidget {
  const _RowShell({required this.leading, required this.title, this.subtitle, this.trailing,
      this.onTap});

  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: tt.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (subtitle != null)
                  Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: tt.bodySmall!.copyWith(color: scheme.onSurfaceVariant)),
              ]),
            ),
            if (trailing != null) ...[const SizedBox(width: 12), trailing!],
          ]),
        ),
      ),
    );
  }
}

class PlayerRow extends StatelessWidget {
  const PlayerRow({super.key, required this.player, this.subtitle, this.trailing, this.onTap});
  final Player player;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => _RowShell(
      leading: PlayerAvatar(player: player, size: 36),
      title: player.name,
      subtitle: subtitle ?? player.clubName,
      trailing: trailing,
      onTap: onTap);
}

class ClubRow extends StatelessWidget {
  const ClubRow({super.key, required this.club, this.subtitle, this.trailing, this.onTap});
  final Club club;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => _RowShell(
      leading: Crest(club: club), title: club.name, subtitle: subtitle, trailing: trailing,
      onTap: onTap);
}

class FixtureRow extends StatelessWidget {
  const FixtureRow({super.key, required this.fixture, required this.home, required this.away,
      required this.now, this.onTap});
  final Fixture fixture;
  final Club? home;
  final Club? away;
  final DateTime now;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final score = fixture.score;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          SizedBox(
            width: 92,
            child: Text(score != null ? '${score[0]}–${score[1]}' : kickoffLabel(fixture.kickoff, now),
                style: score != null ? masthead(26, scheme.onSurface) : tt.labelLarge!
                    .copyWith(color: scheme.onSurfaceVariant)),
          ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${home?.name ?? 'TBC'} v ${away?.name ?? 'TBC'}',
                  style: tt.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              ResultStrip(fixture: fixture, home: home, away: away),
            ]),
          ),
        ]),
      ),
    );
  }
}

class PlayerTile extends StatelessWidget {
  const PlayerTile({super.key, required this.player, this.note, this.onTap});
  final Player player;
  final String? note;
  final VoidCallback? onTap;

  static const width = 132.0;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          PlayerAvatar(player: player, size: width),
          const SizedBox(height: 8),
          Text(player.name.toUpperCase(), style: tt.titleSmall!.copyWith(letterSpacing: 0.3),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(player.clubName ?? '', style: tt.bodySmall!
              .copyWith(color: scheme.onSurfaceVariant), maxLines: 1,
              overflow: TextOverflow.ellipsis),
          if (note != null)
            Text(note!, style: tt.labelMedium!.copyWith(color: scheme.primary,
                fontWeight: FontWeight.w700),
                maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }
}

class PlayerStrip extends StatelessWidget {
  const PlayerStrip({super.key, required this.players, this.notes, this.onTap});
  final List<Player> players;
  final String? Function(Player)? notes;
  final void Function(Player)? onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        // Portrait (3:4) and gap, plus one line each of name, club and note at the text scale.
        height: PlayerTile.width * 4 / 3 + 12 + MediaQuery.textScalerOf(context).scale(60),
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          itemCount: players.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (context, i) => PlayerTile(
              player: players[i],
              note: notes?.call(players[i]) ??
                  (players[i].trendReasons.isEmpty ? null : players[i].trendReasons.first),
              onTap: onTap == null ? null : () => onTap!(players[i])),
        ),
      );
}
