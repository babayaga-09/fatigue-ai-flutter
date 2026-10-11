import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:touchline/data/planner.dart';

import 'helpers.dart';

const toy = [
  PlanItem(1, 'Attack', 60, 80),
  PlanItem(2, 'Attack', 30, 45),
  PlanItem(3, 'Midfield', 40, 50),
  PlanItem(4, 'Midfield', 25, 40),
  PlanItem(5, 'Defender', 20, 30),
];

void main() {
  test('finds the optimum, not the greedy pick', () {
    final p = planSignings(toy, 100, {'Attack': 1, 'Midfield': 1})!;
    expect(p.ids.toSet(), {1, 3}); // 60 + 40 = 100, score 130 beats {1, 4} = 120
    expect(p.score, 130);
    expect(p.cost, 100);
  });

  test('infeasible budget returns null; zero needs returns an empty plan', () {
    expect(planSignings(toy, 10, {'Attack': 1}), isNull);
    expect(planSignings(toy, 100, {'Attack': 3}), isNull);
    final empty = planSignings(toy, 100, {'Attack': 0})!;
    expect(empty.ids, isEmpty);
  });

  test('matches the pipeline ILP on the real golden cases', () {
    final cases = jsonDecode(File('test/fixtures/budget_cases.json').readAsStringSync()) as List;
    final items = planCandidates(fixtureBundle());
    for (final c in cases.cast<Map<String, dynamic>>()) {
      final needs = (c['needs'] as Map).map((k, v) => MapEntry(k as String, v as int));
      final plan = planSignings(items, (c['budget_m'] as num).toDouble(), needs)!;
      expect(plan.score, greaterThanOrEqualTo((c['ilp_score'] as num).toDouble() - 1e-6),
          reason: 'budget ${c['budget_m']}');
      expect(plan.cost, lessThanOrEqualTo((c['budget_m'] as num).toDouble() + 1e-9));
    }
  });
}
