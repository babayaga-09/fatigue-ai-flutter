import 'package:flutter/material.dart';

import '../state/app_state.dart';

class LeagueChips extends StatelessWidget {
  const LeagueChips({super.key, this.allowAll = true, this.selected, this.onSelected});

  final bool allowAll;
  final String? selected;

  /// When null, the chips drive the app-wide league filter.
  final ValueChanged<String?>? onSelected;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final current = onSelected == null ? s.league : selected;
    final select = onSelected ?? s.setLeague;
    Widget chip(String label, String? id) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(label: Text(label), selected: current == id,
              onSelected: (_) => select(id)),
        );
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          if (allowAll) chip('All', null),
          for (final l in s.bundle!.leagues) chip(l.name, l.id),
        ],
      ),
    );
  }
}
