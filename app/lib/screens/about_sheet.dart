import 'package:flutter/material.dart';

Future<void> showAboutSheet(BuildContext context) => showModalBottomSheet<void>(
    context: context, isScrollControlled: true, builder: (_) => const AboutSheet());

class AboutSheet extends StatelessWidget {
  const AboutSheet({super.key});
  @override
  Widget build(BuildContext context) =>
      const Padding(padding: EdgeInsets.all(16), child: Text('How this works'));
}
