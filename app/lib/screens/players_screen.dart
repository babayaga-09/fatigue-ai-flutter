import 'package:flutter/material.dart';

import '../data/bundle.dart';
import '../data/selectors.dart';
import '../format.dart';
import '../state/app_state.dart';
import '../widgets/empty_note.dart';
import '../widgets/league_chips.dart';
import '../widgets/rows.dart';
import 'routes.dart';

const _positions = {'Attack': 'Forwards', 'Midfield': 'Midfielders', 'Defender': 'Defenders',
    'Goalkeeper': 'Goalkeepers'};
const _sorts = {
  PlayerSort.trending: 'Trending',
  PlayerSort.valueGap: 'Biggest bargains',
  PlayerSort.forecast: 'Projected G/A',
  PlayerSort.marketValue: 'Market value',
  PlayerSort.name: 'Name',
};

class PlayersScreen extends StatefulWidget {
  const PlayersScreen({super.key});
  @override
  State<PlayersScreen> createState() => _PlayersScreenState();
}

class _PlayersScreenState extends State<PlayersScreen> {
  final _search = TextEditingController();
  String? pos;
  double? maxAge;
  int? maxPrice;
  PlayerSort sort = PlayerSort.trending;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _clear() => setState(() {
        _search.clear();
        pos = null;
        maxAge = null;
        maxPrice = null;
      });

  Widget _trailing(BuildContext context, Player p) {
    final tt = Theme.of(context).textTheme;
    final text = switch (sort) {
      PlayerSort.valueGap => p.fairValue == null || p.marketValue == null
          ? '–' : signedMoney(p.fairValue! - p.marketValue!),
      PlayerSort.forecast => p.forecastGa5 == null ? '–' : '${p.forecastGa5!.toStringAsFixed(1)} G/A',
      _ => money(p.marketValue),
    };
    return Text(text, style: tt.labelLarge);
  }

  Future<void> _moreFilters(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        builder: (context) => StatefulBuilder(builder: (context, set) {
          final tt = Theme.of(context).textTheme;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Max age ${maxAge?.round() ?? 'any'}', style: tt.titleSmall),
                Slider(min: 17, max: 40, divisions: 23, value: maxAge ?? 40,
                    label: '${(maxAge ?? 40).round()}',
                    onChanged: (v) { set(() {}); setState(() => maxAge = v >= 40 ? null : v); }),
                Text('Max price ${maxPrice == null ? 'any' : money(maxPrice)}', style: tt.titleSmall),
                Slider(min: 1, max: 200, divisions: 199, value: (maxPrice ?? 200000000) / 1e6,
                    label: '€${((maxPrice ?? 200000000) / 1e6).round()}M',
                    onChanged: (v) {
                      set(() {});
                      setState(() => maxPrice = v >= 200 ? null : (v * 1e6).round());
                    }),
              ]),
            ),
          );
        }),
      );

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final b = s.bundle!;
    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final results = searchPlayers(b, PlayerQuery(text: _search.text, league: s.league, pos: pos,
        maxAge: maxAge, maxPrice: maxPrice, sort: sort));
    final extra = (maxAge != null ? 1 : 0) + (maxPrice != null ? 1 : 0);
    return Scaffold(
      appBar: AppBar(title: const Text('Players')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: SearchBar(
            controller: _search,
            hintText: 'Search ${thousands(b.players.length)} players',
            leading: const Icon(Icons.search_rounded),
            elevation: const WidgetStatePropertyAll(0),
            backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainerHigh),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const LeagueChips(),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final MapEntry(key: k, value: label) in _positions.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(label: Text(label), selected: pos == k,
                      onSelected: (on) => setState(() => pos = on ? k : null)),
                ),
              ActionChip(
                avatar: const Icon(Icons.tune_rounded, size: 18),
                label: Text(extra == 0 ? 'Age & price' : 'Age & price · $extra'),
                onPressed: () => _moreFilters(context),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 4, 0),
          child: Row(children: [
            Text('${thousands(results.length)} players', style: tt.labelLarge),
            const Spacer(),
            PopupMenuButton<PlayerSort>(
              initialValue: sort,
              tooltip: 'Sort players',
              onSelected: (v) => setState(() => sort = v),
              itemBuilder: (_) => [
                for (final e in _sorts.entries) PopupMenuItem(value: e.key, child: Text(e.value)),
              ],
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  const Icon(Icons.sort_rounded, size: 18),
                  const SizedBox(width: 6),
                  Text(_sorts[sort]!, style: tt.labelLarge),
                ]),
              ),
            ),
          ]),
        ),
        Expanded(
          child: results.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const EmptyNote('Nobody matches. Loosen a filter.'),
                    TextButton(onPressed: _clear, child: const Text('Clear filters')),
                  ]),
                )
              : ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (context, i) {
                    final p = results[i];
                    return PlayerRow(
                      player: p,
                      subtitle: [p.clubName, p.subPos ?? p.pos].whereType<String>().join(' · '),
                      trailing: _trailing(context, p),
                      onTap: () => openPlayer(context, p.id),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}
