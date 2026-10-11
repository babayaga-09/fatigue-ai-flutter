import 'bundle.dart';

class PlanItem {
  const PlanItem(this.id, this.pos, this.price, this.score);
  final int id;
  final String pos;

  /// € millions.
  final double price;

  /// Fair value in € millions: the quality the planner maximises.
  final double score;
}

class Plan {
  const Plan(this.ids, this.cost, this.score);
  final List<int> ids;
  final double cost;
  final double score;
}

class _State {
  const _State(this.cost, this.score, this.ids);
  final double cost;
  final double score;
  final List<int> ids;
}

const _eps = 1e-9;

List<_State> _pareto(List<_State> states) {
  states.sort((a, b) => a.cost != b.cost ? a.cost.compareTo(b.cost) : b.score.compareTo(a.score));
  final out = <_State>[];
  var best = double.negativeInfinity;
  for (final s in states) {
    if (s.score > best + _eps) {
      out.add(s);
      best = s.score;
    }
  }
  return out;
}

List<PlanItem> _prune(List<PlanItem> items, int need) => [
      for (final it in items)
        if (items.where((o) =>
                    !identical(o, it) &&
                    o.price <= it.price &&
                    o.score >= it.score &&
                    (o.price < it.price || o.score > it.score))
                .length <
            need)
          it
    ];

Plan? planSignings(List<PlanItem> items, double budget, Map<String, int> needs) {
  var acc = [const _State(0, 0, <int>[])];
  for (final MapEntry(key: pos, value: need) in needs.entries) {
    if (need <= 0) continue;
    final cands = _prune(
        [for (final it in items) if (it.pos == pos && it.price <= budget + _eps) it], need);
    final fronts = List.generate(need + 1, (_) => <_State>[]);
    fronts[0] = [const _State(0, 0, <int>[])];
    for (final it in cands) {
      for (var c = need; c >= 1; c--) {
        if (fronts[c - 1].isEmpty) continue;
        final added = [
          for (final s in fronts[c - 1])
            if (s.cost + it.price <= budget + _eps)
              _State(s.cost + it.price, s.score + it.score, [...s.ids, it.id])
        ];
        if (added.isNotEmpty) fronts[c] = _pareto([...fronts[c], ...added]);
      }
    }
    if (fronts[need].isEmpty) return null;
    acc = _pareto([
      for (final a in acc)
        for (final s in fronts[need])
          if (a.cost + s.cost <= budget + _eps)
            _State(a.cost + s.cost, a.score + s.score, [...a.ids, ...s.ids])
    ]);
    if (acc.isEmpty) return null;
  }
  final best = acc.reduce((a, b) => b.score > a.score ? b : a);
  return Plan(best.ids, best.cost, best.score);
}

List<PlanItem> planCandidates(Bundle b, {String? league, double? maxAge}) => [
      for (final p in b.players)
        if (p.fairValue != null &&
            (p.marketValue ?? 0) > 0 &&
            p.pos != null &&
            (league == null || p.league == league) &&
            (maxAge == null || (p.age != null && p.age! <= maxAge)))
          PlanItem(p.id, p.pos!, p.marketValue! / 1e6, p.fairValue! / 1e6)
    ];
