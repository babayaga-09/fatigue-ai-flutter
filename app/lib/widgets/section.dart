import 'package:flutter/material.dart';

/// Programme section: a heavy rule, then the title in masthead caps. More space above than
/// below; optional trailing action.
class SectionHeading extends StatelessWidget {
  const SectionHeading(this.title, {super.key, this.action, this.onAction, this.padded = true,
      this.note});

  final String title;
  final String? action;
  final VoidCallback? onAction;
  final bool padded;

  /// One plain line under the title (e.g. what a figure means, or its honesty caveat).
  final String? note;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: padded ? const EdgeInsets.fromLTRB(16, 32, 16, 10)
          : const EdgeInsets.fromLTRB(0, 32, 0, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(height: 3, color: scheme.onSurface),
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(
              child: Semantics(
                  header: true,
                  label: title,
                  child: ExcludeSemantics(
                      child: Text(title.toUpperCase(), style: tt.headlineSmall)))),
          if (action != null)
            TextButton(onPressed: onAction, child: Text(action!)),
        ]),
        if (note != null) ...[
          const SizedBox(height: 4),
          Text(note!, style: tt.bodySmall!.copyWith(color: scheme.onSurfaceVariant)),
        ],
      ]),
    );
  }
}
