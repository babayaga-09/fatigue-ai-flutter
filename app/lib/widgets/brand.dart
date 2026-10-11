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
    final (icon, label) = s.io.fetchRemote == null
        ? (Icons.inventory_2_outlined, 'Built-in · $date')
        : s.refreshing
            ? (Icons.sync_rounded, 'Updating')
            : s.reachable
                ? (Icons.cloud_done_outlined, 'Data $date')
                : (Icons.cloud_off_outlined, 'Offline · $date');
    return Tooltip(
      message: 'Club data from ${shortDate(DateTime.parse(s.bundle!.clubsThrough))}',
      child: ActionChip(
        avatar: Icon(icon, size: 18),
        label: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
        onPressed: s.refreshing ? null : s.refresh,
      ),
    );
  }
}
