/// Typed view of the Touchline bundle (docs/bundle-schema.md, schema v1).
library;

const supportedSchemaVersion = 1;

class UnsupportedBundleError implements Exception {
  UnsupportedBundleError(this.version);
  final Object? version;
  @override
  String toString() => 'Unsupported bundle schema: $version';
}

double? _d(Object? v) => v == null ? null : (v as num).toDouble();
int? _i(Object? v) => v == null ? null : (v as num).toInt();
String? _s(Object? v) => v as String?;
Map<String, dynamic> _m(Object? v) => (v as Map).cast<String, dynamic>();
List<Map<String, dynamic>> _maps(Object? v) => [for (final e in (v as List? ?? const [])) _m(e)];
List<double> _ds(Object? v) => [for (final e in (v as List? ?? const [])) (e as num).toDouble()];

int? parseHexColor(String? hex) {
  if (hex == null || !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(hex)) return null;
  return 0xFF000000 | int.parse(hex.substring(1), radix: 16);
}

class League {
  const League({required this.id, required this.fd, required this.name});
  factory League.fromJson(Map<String, dynamic> j) =>
      League(id: j['id'] as String, fd: j['fd'] as String, name: j['name'] as String);
  final String id;
  final String fd;
  final String name;
}

class ClubTable {
  const ClubTable({required this.pos, required this.played, required this.points,
      required this.gd, required this.gf, required this.ga});
  factory ClubTable.fromJson(Map<String, dynamic> j) => ClubTable(
      pos: _i(j['pos'])!, played: _i(j['played'])!, points: _i(j['points'])!,
      gd: _i(j['gd'])!, gf: _i(j['gf'])!, ga: _i(j['ga'])!);
  final int pos, played, points, gd, gf, ga;
}

class Projection {
  const Projection({required this.expPoints, required this.expPos, required this.pTitle,
      required this.pTop4, required this.pReleg});
  factory Projection.fromJson(Map<String, dynamic> j) => Projection(
      expPoints: _d(j['exp_points'])!, expPos: _d(j['exp_pos'])!,
      pTitle: _d(j['p_title'])!, pTop4: _d(j['p_top4'])!, pReleg: _d(j['p_releg'])!);
  final double expPoints, expPos, pTitle, pTop4, pReleg;
}

class ClubColors {
  const ClubColors(this.primary, this.secondary);
  final int primary;
  final int secondary;
}

class Club {
  const Club({required this.id, required this.name, required this.crest, required this.league,
      required this.elo, required this.eloChange30d, required this.form, required this.table,
      required this.proj, required this.colors});
  factory Club.fromJson(Map<String, dynamic> j) {
    final cols = j['colors'] as List?;
    final a = cols != null && cols.length == 2 ? parseHexColor(cols[0] as String?) : null;
    final b = cols != null && cols.length == 2 ? parseHexColor(cols[1] as String?) : null;
    return Club(
      id: _i(j['id'])!,
      name: j['name'] as String,
      crest: _s(j['crest']),
      league: j['league'] as String,
      elo: _d(j['elo'])!,
      eloChange30d: _d(j['elo_change_30d']) ?? 0,
      form: [for (final f in (j['form'] as List? ?? const [])) f as String],
      table: ClubTable.fromJson(_m(j['table'])),
      proj: j['proj'] == null ? null : Projection.fromJson(_m(j['proj'])),
      colors: a != null && b != null ? ClubColors(a, b) : null,
    );
  }
  final int id;
  final String name;
  final String? crest;
  final String league;
  final double elo;
  final double eloChange30d;
  final List<String> form;
  final ClubTable table;
  final Projection? proj;
  final ClubColors? colors;
}

class Fixture {
  const Fixture({required this.id, required this.league, required this.kickoff,
      required this.home, required this.away, required this.status, required this.score,
      required this.p, required this.xg});
  factory Fixture.fromJson(Map<String, dynamic> j) => Fixture(
        id: _i(j['id'])!,
        league: j['league'] as String,
        kickoff: DateTime.parse(j['kickoff'] as String),
        home: _i(j['home'])!,
        away: _i(j['away'])!,
        status: j['status'] as String,
        score: (j['score'] as List?)?.map((e) => (e as num).toInt()).toList(),
        p: _ds(j['p']),
        xg: _ds(j['xg']),
      );
  final int id;
  final String league;
  final DateTime kickoff;
  final int home;
  final int away;
  final String status;
  final List<int>? score;

  /// Pre-match probabilities: home, draw, away.
  final List<double> p;
  final List<double> xg;
  bool get finished => status == 'FINISHED' || status == 'AWARDED';
}

class ValueWhy {
  const ValueWhy(this.label, this.effectPct);
  final String label;
  final double effectPct;
}

class SeasonStats {
  const SeasonStats({required this.apps, required this.minutes, required this.goals,
      required this.assists, required this.ga90});
  final int apps, minutes, goals, assists;
  final double ga90;
}

class RecentGame {
  const RecentGame({required this.date, required this.opp, required this.ga,
      required this.minutes});
  final DateTime date;
  final String? opp;
  final int ga;
  final int minutes;
}

class Workload {
  const Workload({required this.index, required this.band, required this.acwr,
      required this.seasonMinutes, required this.congestedApps, required this.flag,
      required this.asOf});
  final int index;
  final String band;
  final double acwr;
  final int seasonMinutes;
  final int congestedApps;
  final bool flag;
  final DateTime asOf;
}

class ValuePoint {
  const ValuePoint(this.date, this.value);
  final DateTime date;
  final int value;
}

class Transfer {
  const Transfer({required this.date, required this.from, required this.to, required this.fee});
  final DateTime date;
  final String? from;
  final String? to;
  final int? fee;
}

class Player {
  const Player({required this.id, required this.name, required this.img, required this.club,
      required this.clubName, required this.league, required this.pos, required this.subPos,
      required this.age, required this.nat, required this.foot, required this.height,
      required this.marketValue, required this.fairValue, required this.valueGapPct,
      required this.valueWhy, required this.season, required this.last5,
      required this.forecastGa5, required this.workload, required this.valueHistory,
      required this.transfers, required this.similar, required this.trendScore,
      required this.trendReasons});

  factory Player.fromJson(Map<String, dynamic> j) {
    final s = _m(j['season']);
    final f = _m(j['form']);
    final w = j['workload'] == null ? null : _m(j['workload']);
    final t = _m(j['trend']);
    return Player(
      id: _i(j['id'])!,
      name: j['name'] as String,
      img: _s(j['img']),
      club: _i(j['club']),
      clubName: _s(j['club_name']),
      league: j['league'] as String,
      pos: _s(j['pos']),
      subPos: _s(j['sub_pos']),
      age: _d(j['age']),
      nat: _s(j['nat']),
      foot: _s(j['foot']),
      height: _d(j['height']),
      marketValue: _i(j['market_value']),
      fairValue: _i(j['fair_value']),
      valueGapPct: _d(j['value_gap_pct']),
      valueWhy: j['value_why'] == null
          ? null
          : [
              for (final e in _maps(j['value_why']))
                ValueWhy(e['f'] as String, _d(e['effect_pct'])!)
            ],
      season: SeasonStats(apps: _i(s['apps'])!, minutes: _i(s['minutes'])!,
          goals: _i(s['goals'])!, assists: _i(s['assists'])!, ga90: _d(s['ga90'])!),
      last5: [
        for (final g in _maps(f['last5']))
          RecentGame(date: DateTime.parse(g['date'] as String), opp: _s(g['opp']),
              ga: _i(g['ga'])!, minutes: _i(g['min'])!)
      ],
      forecastGa5: _d(f['forecast_ga5']),
      workload: w == null
          ? null
          : Workload(index: _i(w['index'])!, band: w['band'] as String,
              acwr: _d(w['acwr'])!, seasonMinutes: _i(w['season_minutes'])!,
              congestedApps: _i(w['congested_apps'])!, flag: w['flag'] as bool,
              asOf: DateTime.parse(w['as_of'] as String)),
      valueHistory: [
        for (final e in (j['value_history'] as List? ?? const []))
          ValuePoint(DateTime.parse((e as List)[0] as String), (e[1] as num).toInt())
      ],
      transfers: [
        for (final e in _maps(j['transfers']))
          Transfer(date: DateTime.parse(e['date'] as String), from: _s(e['from']),
              to: _s(e['to']), fee: _i(e['fee']))
      ],
      similar: [for (final e in (j['similar'] as List? ?? const [])) (e as num).toInt()],
      trendScore: _d(t['score']),
      trendReasons: [for (final e in (t['reasons'] as List? ?? const [])) e as String],
    );
  }

  final int id;
  final String name;
  final String? img;
  final int? club;
  final String? clubName;
  final String league;
  final String? pos;
  final String? subPos;
  final double? age;
  final String? nat;
  final String? foot;
  final double? height;
  final int? marketValue;
  final int? fairValue;
  final double? valueGapPct;
  final List<ValueWhy>? valueWhy;
  final SeasonStats season;
  final List<RecentGame> last5;
  final double? forecastGa5;
  final Workload? workload;
  final List<ValuePoint> valueHistory;
  final List<Transfer> transfers;
  final List<int> similar;
  final double? trendScore;
  final List<String> trendReasons;

  /// Model outputs are only shown for players with 900+ minutes in the season.
  bool get qualified => season.minutes >= 900;
}

class Bundle {
  Bundle({required this.schemaVersion, required this.generatedAt, required this.playersThrough,
      required this.clubsThrough, required this.playerSeason, required this.leagues,
      required this.clubs, required this.fixtures, required this.players, required this.models});

  factory Bundle.fromJson(Map<String, dynamic> j) {
    final v = j['schema_version'];
    if (v != supportedSchemaVersion) throw UnsupportedBundleError(v);
    final dt = _m(j['data_through']);
    return Bundle(
      schemaVersion: v as int,
      generatedAt: DateTime.parse(j['generated_at'] as String),
      playersThrough: dt['players'] as String,
      clubsThrough: dt['clubs'] as String,
      playerSeason: j['player_season'] as String,
      leagues: [for (final e in _maps(j['leagues'])) League.fromJson(e)],
      clubs: [for (final e in _maps(j['clubs'])) Club.fromJson(e)],
      fixtures: [for (final e in _maps(j['fixtures'])) Fixture.fromJson(e)],
      players: [for (final e in _maps(j['players'])) Player.fromJson(e)],
      models: _m(j['models']),
    );
  }

  final int schemaVersion;
  final DateTime generatedAt;
  final String playersThrough;
  final String clubsThrough;
  final String playerSeason;
  final List<League> leagues;
  final List<Club> clubs;
  final List<Fixture> fixtures;
  final List<Player> players;
  final Map<String, dynamic> models;

  late final Map<int, Club> clubById = {for (final c in clubs) c.id: c};
  late final Map<int, Player> playerById = {for (final p in players) p.id: p};
  late final Map<String, League> leagueById = {for (final l in leagues) l.id: l};
}
