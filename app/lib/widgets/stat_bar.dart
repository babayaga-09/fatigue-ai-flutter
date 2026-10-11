import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../format.dart';
import '../theme/theme.dart';
import 'scarf.dart';

/// Signed effect bar centred at zero ("+35%" pushes right, "−12%" left).
class EffectBar extends StatelessWidget {
  const EffectBar({super.key, required this.label, required this.effect, this.maxAbs = 1.0});

  final String label;
  final double effect;
  final double maxAbs;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final frac = (effect.abs() / maxAbs).clamp(0.0, 1.0);
    final positive = effect >= 0;
    final text = '${positive ? '+' : '−'}${(effect.abs() * 100).round()}%';
    return Semantics(
      label: '$label: $text',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Expanded(flex: 5, child: Text(label, style: tt.bodyMedium)),
            Expanded(
              flex: 4,
              child: LayoutBuilder(builder: (context, c) {
                final half = c.maxWidth / 2;
                final w = math.max(2.0, half * frac);
                return SizedBox(
                  height: 10,
                  child: Stack(children: [
                    Positioned(left: half - 0.5, top: 0, bottom: 0,
                        child: Container(width: 1, color: scheme.outline)),
                    Positioned(
                      left: positive ? half : half - w,
                      width: w, top: 1, bottom: 1,
                      child: DecoratedBox(decoration: BoxDecoration(
                          color: positive ? scheme.primary : scheme.tertiary,
                          borderRadius: BorderRadius.circular(2))),
                    ),
                  ]),
                );
              }),
            ),
            SizedBox(width: 56,
                child: Text(text, textAlign: TextAlign.end, style: tabular(tt.labelLarge!))),
          ]),
        ),
      ),
    );
  }
}

/// A 0–1 share with its percentage.
class ShareBar extends StatelessWidget {
  const ShareBar({super.key, required this.label, required this.value, this.colors});

  final String label;
  final double value;

  /// Knit colours for the filled part; the theme's primary when null.
  final List<Color>? colors;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Semantics(
      label: '$label ${pct(value)}',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            SizedBox(width: 96, child: Text(label, style: tt.bodyMedium)),
            Expanded(
              child: ShareScarf(value: value, colors: colors ?? [scheme.primary], height: 14),
            ),
            SizedBox(width: 52,
                child: Text(pct(value), textAlign: TextAlign.end,
                    style: tabular(tt.labelLarge!))),
          ]),
        ),
      ),
    );
  }
}

/// A probability knitted as a scarf: the share in [colors], the rest a dropped stitch.
class ShareScarf extends StatelessWidget {
  const ShareScarf({super.key, required this.value, required this.colors, this.height = 8});

  final double value;
  final List<Color> colors;
  final double height;

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0);
    return ExcludeSemantics(
      child: Scarf(
        height: height,
        stripeWidth: 6,
        semanticLabel: '',
        bands: [
          ScarfBand(flex: v, colors: colors),
          ScarfBand(flex: 1 - v, colors: [Theme.of(context).colorScheme.outlineVariant],
              knit: Knit.dropped),
        ],
      ),
    );
  }
}
