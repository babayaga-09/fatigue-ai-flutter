import 'package:flutter/material.dart';

import '../data/bundle.dart';
import 'crest.dart';

class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({super.key, required this.player, this.size = 56});

  final Player player;

  /// Width; height is 4:3 of it (Transfermarkt portraits are 3:4).
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fallback = Container(
      key: const ValueKey('initials'),
      color: scheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Text(initials(player.name),
          style: Theme.of(context).textTheme.headlineSmall!
              .copyWith(color: scheme.onSurfaceVariant)),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: size,
        height: size * 4 / 3,
        child: player.img == null
            ? fallback
            : Image.network(player.img!,
                fit: BoxFit.cover,
                semanticLabel: player.name,
                webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                errorBuilder: (context, error, stack) => fallback),
      ),
    );
  }
}
