import 'package:flutter_test/flutter_test.dart';
import 'package:touchline/data/bundle.dart';
import 'package:touchline/data/selectors.dart';

import 'helpers.dart';

Map<String, dynamic> _club(int id, String league, double elo, {double change = 0, int pos = 1}) => {
      'id': id, 'name': 'C$id', 'crest': null, 'league': league, 'elo': elo,
      'elo_change_30d': change, 'form': ['W'], 'colors': null, 'proj': null,
      'table': {'pos': pos, 'played': 5, 'points': 10, 'gd': 1, 'gf': 5, 'ga': 4},
    };

Map<String, dynamic> _fix(int id, int h, int a, DateTime k,
        {String league = 'GB1', String status = 'TIMED'}) => {
      'id': id, 'league': league, 'kickoff': k.toIso8601String(), 'home': h, 'away': a,
      'status': status, 'score': status == 'FINISHED' ? [1, 0] : null,
      'p': [0.5, 0.3, 0.2], 'xg': [1.4, 1.0],
    };

Map<String, dynamic> _player(int id, String name,
    {String league = 'GB1', int minutes = 2000, double? trend, int? fair, int? market,
    Map<String, dynamic>? workload, String pos = 'Attack', double age = 24,
    List<int> similar = const []}) => {
      'id': id, 'name': name, 'img': null, 'club': 1, 'club_name': 'C1', 'league': league,
      'pos': pos, 'sub_pos': null, 'age': age, 'nat': null, 'foot': null, 'height': null,
      'market_value': market, 'fair_value': fair,
      'value_gap_pct': fair != null && market != null ? (fair - market) / market : null,
      'value_why': null,
      'season': {'apps': 30, 'minutes': minutes, 'goals': 5, 'assists': 3, 'ga90': 0.4},
      'form': {'last5': [], 'forecast_ga5': trend == null ? null : 2.0}, 'workload': workload,
      'value_history': [], 'transfers': [], 'similar': similar,
      'trend': {'score': trend, 'reasons': trend == null ? [] : ['Hot']},
    };

Map<String, dynamic> _wl(int index, bool flag) => {
      'index': index, 'band': 'High', 'acwr': 1.1, 'season_minutes': 4000,
      'congested_apps': 9, 'flag': flag, 'as_of': '2026-05-24'};

final now = DateTime.utc(2026, 10, 5, 12);

Bundle _bundle() => Bundle.fromJson(minimalBundleJson()
  ..['clubs'] = [
    _club(1, 'GB1', 1900, change: 20, pos: 2),
    _club(2, 'GB1', 1700, change: -5, pos: 1),
    _club(3, 'GB1', 1600, change: 8, pos: 3),
    _club(4, 'ES1', 1950, change: 3, pos: 1),
  ]
  ..['fixtures'] = [
    _fix(10, 2, 3, now.add(const Duration(days: 1))),
    _fix(11, 1, 2, now.add(const Duration(days: 2))),
    _fix(12, 1, 3, now.add(const Duration(days: 9))),
    _fix(13, 3, 1, now.subtract(const Duration(days: 2)), status: 'FINISHED'),
    _fix(14, 4, 4, now.add(const Duration(days: 3)), league: 'ES1'),
  ]
  ..['players'] = [
    _player(1, 'Kylian Mbappé', trend: 2.0, fair: 30000000, market: 20000000,
        workload: _wl(70, false), similar: [2, 3]),
    _player(2, 'Cheap Lookalike', trend: 1.0, fair: 9000000, market: 6000000,
        workload: _wl(90, false)),
    _player(3, 'Pricey Lookalike', trend: null, fair: 4000000, market: 50000000,
        workload: _wl(40, true), pos: 'Defender', age: 31),
    _player(4, 'Tiny Club Hero', trend: 0.5, fair: 3000000, market: 1000000, league: 'ES1'),
    _player(5, 'Bench Kid', minutes: 200),
  ]);

void main() {
  final b = _bundle();

  test('week fixtures: upcoming within 7 days, sorted, league-filtered', () {
    expect(weekFixtures(b, null, now).map((f) => f.id), [10, 11, 14]);
    expect(weekFixtures(b, 'GB1', now).map((f) => f.id), [10, 11]);
  });

  test('featured fixture is the biggest match by combined Elo', () {
    expect(featuredFixture(b, 'GB1', now)!.id, 11);
    expect(featuredFixture(b, 'IT1', now), isNull);
  });

  test('recent results are finished games, newest first', () {
    expect(recentResults(b, null).map((f) => f.id), [13]);
  });

  test('trending excludes null scores and respects league', () {
    expect(trendingPlayers(b, null).map((p) => p.id), [1, 2, 4]);
    expect(trendingPlayers(b, 'GB1').map((p) => p.id), [1, 2]);
  });

  test('bargains: positive gap, market >= floor, sorted by euro gap', () {
    expect(bargains(b, null).map((p) => p.id), [1, 2]);
  });

  test('overworked: flagged first, then index', () {
    expect(overworked(b, null).map((p) => p.id), [3, 2, 1]);
  });

  test('clubs in form, power rankings, table', () {
    expect(clubsInForm(b, 'GB1').map((c) => c.id), [1, 3, 2]);
    expect(powerRankings(b, null).map((c) => c.id), [4, 1, 2, 3]);
    expect(leagueTable(b, 'GB1').map((c) => c.id), [2, 1, 3]);
  });

  test('similar cheaper keeps only lower market value', () {
    expect(similarCheaper(b, b.playerById[1]!).map((p) => p.id), [2]);
  });

  test('search folds accents and case; filters and sorts', () {
    expect(searchPlayers(b, const PlayerQuery(text: 'mbappe')).map((p) => p.id), [1]);
    expect(searchPlayers(b, const PlayerQuery(pos: 'Defender')).map((p) => p.id), [3]);
    expect(searchPlayers(b, const PlayerQuery(maxAge: 30, maxPrice: 10000000,
            sort: PlayerSort.marketValue)).map((p) => p.id), [2, 4]);
    // Euro gap, not percentage: cheap players with huge % gaps must not flood the list.
    expect(searchPlayers(b, const PlayerQuery(sort: PlayerSort.valueGap)).first.id, 1);
  });

  test('fold', () {
    expect(fold('Vinícius Júnior'), 'vinicius junior');
    expect(fold('Øde­gaard'), contains('odegaard'));
  });
}
