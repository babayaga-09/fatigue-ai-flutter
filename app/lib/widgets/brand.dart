import 'package:flutter/material.dart';

import '../format.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import 'scarf.dart';

/// Touchline's own scarf as a thin knitted band.
class BrandBand extends StatelessWidget {
  const BrandBand({super.key});

  @override
  Widget build(BuildContext context) => const ExcludeSemantics(
        child: Scarf(
          height: 8,
          stripeWidth: 12,
          semanticLabel: '',
          bands: [ScarfBand(flex: 1, colors: [TL.pitch, TL.pink])],
        ),
      );
}

class Wordmark extends StatelessWidget {
  const Wordmark({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
        header: true,
        label: 'Touchline',
        child: ExcludeSemantics(
          child: Text('TOUCHLINE', style: Theme.of(context).textTheme.displaySmall!
              .copyWith(color: Theme.of(context).colorScheme.primary)),
        ),
      );
}

class FreshnessChip extends StatelessWidget {
  const FreshnessChip({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final date = shortDate(DateTime.parse(s.bundle!.clubsThrough));
    final (icon, meaning) = s.io.fetchRemote == null
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
