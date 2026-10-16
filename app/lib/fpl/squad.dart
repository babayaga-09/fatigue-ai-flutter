/// The manager's FPL squad: who, money in the bank, free transfers, chips still to play.
library;

import 'dart:convert';

import 'fpl_bundle.dart';
import 'fpl_optimiser.dart';

const allChips = ['wildcard', 'freehit', '3xc', 'bboost'];
const chipNames = {
  'wildcard': 'Wildcard', 'freehit': 'Free Hit', '3xc': 'Triple Captain',
  'bboost': 'Bench Boost',
};

class Squad {
  const Squad({required this.ids, this.bank = 0, this.freeTransfers = 1,
      this.chipsAvailable = const {'wildcard', 'freehit', '3xc', 'bboost'}, this.sell = const {},
      this.teamId, this.teamName});

  final List<int> ids;
  final int bank; // tenths of £m
  final int freeTransfers;
  final Set<String> chipsAvailable;

  /// Selling price per player when known (imported); otherwise the current price is used.
  final Map<int, int> sell;
  final int? teamId;
  final String? teamName;

  Squad copyWith({List<int>? ids, int? bank, int? freeTransfers, Set<String>? chipsAvailable}) =>
      Squad(ids: ids ?? this.ids, bank: bank ?? this.bank,
          freeTransfers: freeTransfers ?? this.freeTransfers,
          chipsAvailable: chipsAvailable ?? this.chipsAvailable, sell: sell, teamId: teamId,
          teamName: teamName);

  Map<String, dynamic> toJson() => {
        'ids': ids, 'bank': bank, 'ft': freeTransfers, 'chips': chipsAvailable.toList(),
        'sell': {for (final e in sell.entries) '${e.key}': e.value},
        'team_id': teamId, 'team_name': teamName,
      };

  factory Squad.fromJson(Map<String, dynamic> j) => Squad(
        ids: [for (final i in j['ids'] as List) (i as num).toInt()],
        bank: (j['bank'] as num? ?? 0).toInt(), freeTransfers: (j['ft'] as num? ?? 1).toInt(),
        chipsAvailable: {for (final c in (j['chips'] as List? ?? allChips)) c as String},
        sell: {
          for (final e in ((j['sell'] as Map?) ?? const {}).entries)
            int.parse(e.key as String): (e.value as num).toInt()
        },
        teamId: (j['team_id'] as num?)?.toInt(), teamName: j['team_name'] as String?,
      );

  String encode() => jsonEncode(toJson());
  static Squad? decode(String? s) =>
      s == null ? null : Squad.fromJson(jsonDecode(s) as Map<String, dynamic>);

  /// Players in this squad that the bundle knows, as optimiser picks.
  List<Pick> picks(FplBundle b) => [
        for (final id in ids)
          if (b.byId[id] case final p?) Pick(p.id, p.pos, p.team, p.price)
      ];

  Map<int, int> sellPrices(FplBundle b) =>
      {for (final id in ids) if (b.byId[id] case final p?) id: sell[id] ?? p.price};

  int value(FplBundle b) => sellPrices(b).values.fold(0, (a, v) => a + v);
}

/// Why this squad can't be saved, in plain words; empty when it is legal.
List<String> validateSquad(List<int> ids, int bank, FplBundle b, {int budget = 1000}) {
  final problems = <String>[];
  final players = [for (final id in ids) ?b.byId[id]];
  final missing = ids.length - players.length;
  if (missing > 0) problems.add('$missing player${missing == 1 ? '' : 's'} not in our data');
  for (final MapEntry(key: pos, value: need) in squadSlots.entries) {
    final have = players.where((p) => p.pos == pos).length;
    if (have != need) problems.add('${_posName[pos]}: $have of $need');
  }
  final clubs = <int, int>{};
  for (final p in players) {
    clubs[p.team] = (clubs[p.team] ?? 0) + 1;
  }
  for (final MapEntry(key: t, value: n) in clubs.entries) {
    if (n > clubLimit) {
      problems.add('$n players from ${b.teamById[t]?.name ?? 'one club'} (max $clubLimit)');
    }
  }
  final cost = players.fold(0, (a, p) => a + p.price);
  if (cost > budget) {
    problems.add('Over budget by £${((cost - budget) / 10).toStringAsFixed(1)}m');
  }
  return problems;
}

const _posName = {'GK': 'Goalkeepers', 'DEF': 'Defenders', 'MID': 'Midfielders',
    'FWD': 'Forwards'};
