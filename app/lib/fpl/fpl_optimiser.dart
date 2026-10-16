/// Dart port of pipeline/touchline/fpl/optimise.py (best XI and the 0-2 transfer search).
/// Ordering and tie-breaks mirror the Python exactly; test/fpl_optimiser_test.dart checks the
/// shared golden cases.
library;

const squadSlots = {'GK': 2, 'DEF': 5, 'MID': 5, 'FWD': 3};
const clubLimit = 3;
const hitCost = 4;
const hitMargin = 1.0;
const benchWeight = 0.1;
const candidatesPerPos = 25;
const doublePool = 40;

final formations = [
  for (var d = 3; d <= 5; d++)
    for (var m = 2; m <= 5; m++)
      if (10 - d - m >= 1 && 10 - d - m <= 3) (d, m, 10 - d - m),
];

class Pick {
  const Pick(this.id, this.pos, this.team, this.price);
  final int id;
  final String pos;
  final int team;
  final int price; // tenths of £m
}

class XiResult {
  const XiResult(this.xi, this.bench, this.captain, this.vice, this.points, this.benchPoints);
  final List<int> xi;
  final List<int> bench;
  final int captain, vice;
  final double points; // captain doubled
  final double benchPoints;
}

int _byPts(Pick a, Pick b, Map<int, double> pts) {
  final c = (pts[b.id] ?? 0).compareTo(pts[a.id] ?? 0);
  return c != 0 ? c : a.id.compareTo(b.id);
}

XiResult bestXi(List<Pick> squad, Map<int, double> pts) {
  final by = {
    for (final p in squadSlots.keys)
      p: (squad.where((q) => q.pos == p).toList()..sort((a, b) => _byPts(a, b, pts)))
  };
  double? bestTotal;
  late List<Pick> best;
  for (final (d, m, f) in formations) {
    final pick = [
      ...by['GK']!.take(1), ...by['DEF']!.take(d), ...by['MID']!.take(m), ...by['FWD']!.take(f)
    ];
    var total = 0.0;
    for (final q in pick) {
      total += pts[q.id] ?? 0;
    }
    if (bestTotal == null || total > bestTotal + 1e-12) {
      bestTotal = total;
      best = pick;
    }
  }
  final ids = {for (final q in best) q.id};
  final outfieldBench = squad.where((q) => !ids.contains(q.id) && q.pos != 'GK').toList()
    ..sort((a, b) => _byPts(a, b, pts));
  final gkBench = by['GK']!.skip(1).toList();
  final ranked = [...best]..sort((a, b) => _byPts(a, b, pts));
  final bench = [for (final q in [...gkBench, ...outfieldBench]) q.id];
  var benchPts = 0.0;
  for (final i in bench) {
    benchPts += pts[i] ?? 0;
  }
  return XiResult([for (final q in best) q.id], bench, ranked[0].id, ranked[1].id,
      bestTotal! + (pts[ranked[0].id] ?? 0), benchPts);
}

/// FPL keeps half of any rise (rounded down to £0.1m); falls are passed on in full.
int sellPrice(int buy, int now) => now > buy ? buy + (now - buy) ~/ 2 : now;

double horizonValue(List<Pick> squad, List<Map<int, double>> horizon) {
  var total = 0.0;
  for (final pts in horizon) {
    final x = bestXi(squad, pts);
    total += x.points + benchWeight * x.benchPoints;
  }
  return total;
}

class TransferPlan {
  const TransferPlan(this.transfers, this.value, this.gain, this.hits, this.worthIt);
  final List<(int, int)> transfers; // (out, in)
  final double value, gain;
  final int hits;
  final bool worthIt;
}

bool _legal(List<Pick> squad) {
  final teams = <int, int>{};
  for (final p in squad) {
    teams[p.team] = (teams[p.team] ?? 0) + 1;
  }
  return teams.values.every((n) => n <= clubLimit);
}

TransferPlan _plan(List<(int, int)> moves, double value, double base, int freeTransfers) {
  final hits = (moves.length - freeTransfers).clamp(0, 99) * hitCost;
  final gain = value - base;
  return TransferPlan(moves, value, gain, hits, gain - hits > (hits > 0 ? hitMargin : 0.0));
}

/// Best plan with 0, 1 and 2 transfers (same candidate rules as the Python).
List<TransferPlan> suggestTransfers(List<Pick> squad, Map<int, int> sell, int bank,
    int freeTransfers, List<Pick> pool, List<Map<int, double>> horizon,
    {int maxTransfers = 2}) {
  final owned = {for (final p in squad) p.id};
  final total = <int, double>{};
  for (final p in pool) {
    var t = 0.0;
    for (final h in horizon) {
      t += h[p.id] ?? 0;
    }
    total[p.id] = t;
  }
  int byTotal(Pick a, Pick b) {
    final c = total[b.id]!.compareTo(total[a.id]!);
    return c != 0 ? c : a.id.compareTo(b.id);
  }

  final cands = {
    for (final pos in squadSlots.keys)
      pos: (pool.where((p) => p.pos == pos && !owned.contains(p.id)).toList()..sort(byTotal))
          .take(candidatesPerPos)
          .toList()
  };
  final base = horizonValue(squad, horizon);
  final plans = [TransferPlan(const [], base, 0, 0, true)];

  final singles = <(double, Pick, Pick)>[];
  for (final out in [...squad]..sort((a, b) => a.id.compareTo(b.id))) {
    for (final nw in cands[out.pos]!) {
      if (bank + sell[out.id]! < nw.price) continue;
      final s = [for (final p in squad) p.id == out.id ? nw : p];
      if (_legal(s)) singles.add((horizonValue(s, horizon), out, nw));
    }
  }
  singles.sort((a, b) {
    var c = b.$1.compareTo(a.$1);
    if (c != 0) return c;
    c = a.$2.id.compareTo(b.$2.id);
    return c != 0 ? c : a.$3.id.compareTo(b.$3.id);
  });
  if (singles.isNotEmpty && maxTransfers >= 1) {
    final (v, out, nw) = singles.first;
    plans.add(_plan([(out.id, nw.id)], v, base, freeTransfers));
  }
  if (maxTransfers >= 2) {
    final top = singles.take(doublePool).toList();
    (double, int)? bestKey;
    List<(int, int)>? bestMoves;
    double bestValue = 0;
    for (var i = 0; i < top.length; i++) {
      for (var j = i + 1; j < top.length; j++) {
        final (_, o1, n1) = top[i];
        final (_, o2, n2) = top[j];
        if (o1.id == o2.id || n1.id == n2.id) continue;
        if (bank + sell[o1.id]! + sell[o2.id]! < n1.price + n2.price) continue;
        final s = [for (final p in squad) p.id == o1.id ? n1 : p.id == o2.id ? n2 : p];
        if (!_legal(s)) continue;
        final v = horizonValue(s, horizon);
        final key = (v, -(o1.id < o2.id ? o1.id : o2.id));
        if (bestKey == null || key.$1 > bestKey.$1 ||
            (key.$1 == bestKey.$1 && key.$2 > bestKey.$2)) {
          bestKey = key;
          bestMoves = [(o1.id, n1.id), (o2.id, n2.id)]
            ..sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2));
          bestValue = v;
        }
      }
    }
    if (bestMoves != null) plans.add(_plan(bestMoves, bestValue, base, freeTransfers));
  }
  return plans;
}

/// The pre-solved squad for the largest grid budget within [budget]; else the cheapest, flagged.
(T, bool) pickGrid<T>(List<T> grid, int budget, int Function(T) budgetOf) {
  final fits = grid.where((g) => budgetOf(g) <= budget).toList();
  if (fits.isNotEmpty) {
    return (fits.reduce((a, b) => budgetOf(a) >= budgetOf(b) ? a : b), false);
  }
  return (grid.reduce((a, b) => budgetOf(a) <= budgetOf(b) ? a : b), true);
}
