import 'package:flutter/material.dart';

import '../fpl/fpl_bundle.dart';
import '../fpl/fpl_optimiser.dart';
import '../fpl/fpl_state.dart';
import '../fpl/squad.dart';
import '../theme/theme.dart';
import '../widgets/brand.dart';
import '../widgets/empty_note.dart';

void openSquadPicker(BuildContext context) => Navigator.of(context)
    .push(MaterialPageRoute<void>(builder: (_) => const SquadPickerScreen()));

class SquadPickerScreen extends StatefulWidget {
  const SquadPickerScreen({super.key});
  @override
  State<SquadPickerScreen> createState() => _SquadPickerScreenState();
}

class _SquadPickerScreenState extends State<SquadPickerScreen> {
  late List<int> picked;
  String query = '';
  String pos = 'GK';
  bool _init = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    picked = [...?FplScope.of(context).squad?.ids];
  }

  @override
  Widget build(BuildContext context) {
    final s = FplScope.of(context);
    final b = s.bundle!;
    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final spent = picked.fold<int>(0, (a, id) => a + (b.byId[id]?.price ?? 0));
    final problems = validateSquad(picked, 1000 - spent, b);
    final q = query.trim().toLowerCase();
    final list = b.players
        .where((p) => p.pos == pos && p.status != 'u' &&
            (q.isEmpty || p.full.toLowerCase().contains(q) || p.name.toLowerCase().contains(q)))
        .toList()
      ..sort((a, c) => c.horizon().compareTo(a.horizon()));
    final count = picked.where((i) => b.byId[i]?.pos == pos).length;

    return Scaffold(
      appBar: AppBar(title: const ScreenTitle('Your 15'), actions: [
        TextButton(
          onPressed: problems.isEmpty
              ? () {
                  final old = s.squad;
                  s.saveSquad(Squad(ids: picked, bank: 1000 - spent,
                      freeTransfers: old?.freeTransfers ?? 1,
                      chipsAvailable: old?.chipsAvailable ?? allChips.toSet(),
                      teamId: old?.teamId, teamName: old?.teamName));
                  Navigator.pop(context);
                }
              : null,
          child: const Text('Save'),
        ),
      ]),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(children: [
            Text('${picked.length}/15', style: masthead(30, scheme.onSurface)),
            const Spacer(),
            Text('£${((1000 - spent) / 10).toStringAsFixed(1)}m left',
                style: tabular(tt.titleMedium!.copyWith(
                    color: spent > 1000 ? scheme.error : scheme.onSurface))),
          ]),
        ),
        if (problems.isNotEmpty && picked.isNotEmpty)
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
              child: EmptyNote(problems.join(' · '))),
        SizedBox(
          height: 48,
          child: ListView(scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16), children: [
            for (final p in squadSlots.keys)
              Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(
                  label: Text('$p ${picked.where((i) => b.byId[i]?.pos == p).length}/'
                      '${squadSlots[p]}'),
                  selected: pos == p, onSelected: (_) => setState(() => pos = p))),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextField(
            decoration: const InputDecoration(hintText: 'Search players',
                prefixIcon: Icon(Icons.search_rounded), isDense: true),
            onChanged: (v) => setState(() => query = v),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, i) {
              final p = list[i];
              final on = picked.contains(p.id);
              final full = !on && count >= squadSlots[pos]!;
              return CheckboxListTile(
                value: on,
                onChanged: full ? null : (v) => setState(() {
                  v == true ? picked.add(p.id) : picked.remove(p.id);
                }),
                title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('${b.teamById[p.team]?.short ?? ''} · '
                    '£${(p.price / 10).toStringAsFixed(1)}m · '
                    '${p.horizon().toStringAsFixed(1)} pts next 5'),
              );
            },
          ),
        ),
      ]),
    );
  }
}

/// Exposed for tests: the bundle a squad picker would save against.
FplBundle? pickerBundle(BuildContext context) => FplScope.of(context).bundle;
