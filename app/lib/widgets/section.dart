import 'package:flutter/material.dart';

/// Section title with more space above than below; optional trailing action.
class SectionHeading extends StatelessWidget {
  const SectionHeading(this.title, {super.key, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 28, 8, 8),
        child: Row(children: [
          Expanded(
              child: Semantics(
                  header: true,
                  child: Text(title, style: Theme.of(context).textTheme.titleLarge))),
          if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
        ]),
      );
}
