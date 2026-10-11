import 'package:flutter/material.dart';

class EmptyNote extends StatelessWidget {
  const EmptyNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Icon(Icons.hourglass_empty_rounded, size: 18, color: scheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: Theme.of(context).textTheme.bodyMedium!
                  .copyWith(color: scheme.onSurfaceVariant)),
        ),
      ]),
    );
  }
}
