import 'package:flutter/material.dart';

import '../format.dart';
import '../state/app_state.dart';
import '../theme/theme.dart';
import '../theme/tokens.dart';

class Wordmark extends StatelessWidget {
  const Wordmark({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
        header: true,
        label: 'Touchline',
        child: ExcludeSemantics(
          child: Text('TOUCHLINE',
              style: masthead(36, TL.red)),
        ),
      );
}

class FreshnessChip extends StatelessWidget {
  const FreshnessChip({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final date = shortDate(DateTime.parse(s.bundle!.clubsThrough));
    final (icon, meaning) = s.needsAppUpdate
        ? (Icons.system_update_outlined, 'New data needs an app update. Showing data from $date')
        : s.io.fetchRemote == null
        ? (Icons.inventory_2_outlined, 'Built-in data from $date')
        : s.refreshing
            ? (Icons.sync_rounded, 'Updating; showing data from $date')
            : s.reachable
                ? (Icons.cloud_done_outlined, 'Up to date: data from $date')
                : (Icons.cloud_off_outlined, 'Offline: showing data from $date');
    return Tooltip(
      message: meaning,
      child: Semantics(
        label: meaning,
        button: true,
        onTap: s.refreshing ? null : s.refresh,
        excludeSemantics: true,
        child: ActionChip(
          avatar: Icon(icon, size: 18),
          label: Text(date, maxLines: 1),
          onPressed: s.refreshing ? null : s.refresh,
        ),
      ),
    );
  }
}

/// A screen's title in masthead caps.
class ScreenTitle extends StatelessWidget {
  const ScreenTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
        header: true,
        label: text,
        child: ExcludeSemantics(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(text.toUpperCase(),
                style: masthead(32, Theme.of(context).colorScheme.onSurface)),
          ),
        ),
      );
}
