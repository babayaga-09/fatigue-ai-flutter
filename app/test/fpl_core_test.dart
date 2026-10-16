import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:touchline/fpl/fpl_bundle.dart';
import 'package:touchline/fpl/fpl_optimiser.dart';
import 'package:touchline/fpl/squad.dart';
import 'package:touchline/fpl/team_import.dart';

FplBundle fplFixture() =>
    decodeFplGz(File('test/fixtures/fpl-bundle.json.gz').readAsBytesSync());

void main() {
  test('parses the real FPL bundle', () {
    final b = fplFixture();
    expect(b.players.length, greaterThan(500));
    expect(b.gws.length, 6);
    expect(b.source, anyOf('ours', 'fpl'));
    expect(b.wildcard.every((w) => w.squad.length == 15), isTrue);
    expect(b.players.where((p) => p.status == 'i').every((p) => p.next == 0), isTrue);
  });

  test('optimiser reproduces the Python golden cases exactly', () {
    final cases = jsonDecode(File('test/fixtures/fpl_cases.json').readAsStringSync()) as List;
    for (final c in cases.cast<Map<String, dynamic>>()) {
      final pool = [
        for (final p in (c['pool'] as List).cast<Map<String, dynamic>>())
          Pick((p['id'] as num).toInt(), p['pos'] as String, (p['team'] as num).toInt(),
              (p['price'] as num).toInt())
      ];
      final ids = {for (final i in c['squad'] as List) (i as num).toInt()};
      final squad = pool.where((p) => ids.contains(p.id)).toList();
      final horizon = [
        for (final h in (c['horizon'] as List).cast<Map<String, dynamic>>())
          {for (final e in h.entries) int.parse(e.key): (e.value as num).toDouble()}
      ];
      final sell = {
        for (final e in (c['sell'] as Map<String, dynamic>).entries)
          int.parse(e.key): (e.value as num).toInt()
      };
      final x = bestXi(squad, horizon.first);
      final want = c['best_xi'] as Map<String, dynamic>;
      expect([...x.xi]..sort(), [for (final i in want['xi'] as List) (i as num).toInt()]);
      expect(x.bench, [for (final i in want['bench'] as List) (i as num).toInt()]);
      expect(x.captain, want['captain']);
      expect(x.vice, want['vice']);
      expect(x.points, closeTo((want['points'] as num).toDouble(), 1e-6));

      final plans = suggestTransfers(squad, sell, (c['bank'] as num).toInt(),
          (c['free_transfers'] as num).toInt(), pool, horizon);
      final wantPlans = (c['plans'] as List).cast<Map<String, dynamic>>();
      expect(plans.length, wantPlans.length);
      for (var i = 0; i < plans.length; i++) {
        final w = wantPlans[i];
        expect([for (final t in plans[i].transfers) [t.$1, t.$2]],
            [for (final t in w['transfers'] as List) [for (final v in t as List) v]]);
        expect(plans[i].value, closeTo((w['value'] as num).toDouble(), 1e-6));
        expect(plans[i].hits, w['hits']);
        expect(plans[i].worthIt, w['worth_it']);
      }
    }
  });

  test('sell price keeps half the profit, rounded down', () {
    expect(sellPrice(50, 53), 51);
    expect(sellPrice(50, 47), 47);
  });

  test('pickGrid takes the largest budget that fits, else the cheapest flagged', () {
    final grid = [950, 1000, 1050];
    expect(pickGrid(grid, 1020, (g) => g), (1000, false));
    expect(pickGrid(grid, 900, (g) => g), (950, true));
  });

  test('squad validation names each problem', () {
    final b = fplFixture();
    final mids = b.players.where((p) => p.pos == 'MID').take(6).map((p) => p.id).toList();
    final problems = validateSquad(mids, 0, b);
    expect(problems.any((p) => p.startsWith('Midfielders: 6 of 5')), isTrue);
    expect(problems.any((p) => p.startsWith('Goalkeepers')), isTrue);
    final wc = b.wildcard.firstWhere((w) => w.budget == 1000).squad;
    expect(validateSquad(wc, 0, b), isEmpty);
    // a fourth player from one club is refused
    final club = b.byId[wc.first]!.team;
    final extra = b.players.where((p) => p.team == club && !wc.contains(p.id)).take(3);
    final heavy = [...wc.take(12), ...extra.map((p) => p.id)];
    expect(validateSquad(heavy, 0, b).any((p) => p.contains('(max 3)')), isTrue);
  });

  test('squad round-trips through storage', () {
    const s = Squad(ids: [1, 2, 3], bank: 15, freeTransfers: 2, chipsAvailable: {'3xc'},
        sell: {1: 55}, teamId: 42, teamName: 'Aryan XI');
    final back = Squad.decode(s.encode())!;
    expect(back.ids, [1, 2, 3]);
    expect(back.bank, 15);
    expect(back.chipsAvailable, {'3xc'});
    expect(back.sell, {1: 55});
    expect(back.teamName, 'Aryan XI');
  });

  group('team import', () {
    http.Client client(Map<String, Object> routes, {int status = 200}) =>
        MockClient((req) async {
          final path = req.url.path.replaceFirst('/api/', '');
          final body = routes[path];
          if (body == null) return http.Response('', 404);
          return http.Response(jsonEncode(body), status);
        });

    test('pulls picks, bank, chips left and a free-transfer estimate', () async {
      final c = client({
        'entry/42/': {'name': 'Aryan XI', 'current_event': 6},
        'entry/42/event/6/picks/': {
          'picks': [for (var i = 1; i <= 15; i++) {'element': i}],
          'entry_history': {'bank': 7},
        },
        'entry/42/history/': {
          'chips': [{'name': 'wildcard', 'event': 3}],
          'current': [for (var g = 1; g <= 6; g++) {'event': g, 'event_transfers': g == 5 ? 2 : 0}],
        },
      });
      final s = await importTeam(42, c);
      expect(s.ids.length, 15);
      expect(s.bank, 7);
      expect(s.chipsAvailable.contains('wildcard'), isFalse);
      expect(s.chipsAvailable, containsAll(['freehit', '3xc', 'bboost']));
      expect(s.freeTransfers, inInclusiveRange(1, 5));
      expect(s.teamName, 'Aryan XI');
    });

    test('unknown team id gives a plain message', () async {
      expect(() => importTeam(999, client({})),
          throwsA(isA<ImportFailure>().having((e) => e.message, 'message',
              'No FPL team with that ID.')));
    });

    test('chips reset for the second half of the season', () {
      final h = {'chips': [{'name': 'wildcard', 'event': 3}, {'name': 'bboost', 'event': 25}]};
      expect(chipsLeft(h, 10), {'freehit', '3xc', 'bboost'});
      expect(chipsLeft(h, 26), {'wildcard', 'freehit', '3xc'});
    });
  });
}
