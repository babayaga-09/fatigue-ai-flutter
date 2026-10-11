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
/// A career block the app can draw: equal-length non-empty lists and "YYYY/YY" season labels.
bool _validCareer(Map<String, dynamic>? c) {
  if (c == null) return false;
  final s = c['seasons'], a = c['p10'], m = c['p50'], z = c['p90'];
  if (s is! List || a is! List || m is! List || z is! List) return false;
  if (s.isEmpty || a.length != s.length || m.length != s.length || z.length != s.length) {
    return false;
  }
  return s.every((e) => e is String && RegExp(r'^\d{4}/').hasMatch(e)) &&
      c['peak_value'] is num && c['vs_curve'] is String;
}

List<int> _is(Object? v) => [for (final e in (v as List? ?? const [])) (e as num).toInt()];
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

class Dependency {
  const Dependency({required this.index, required this.played, required this.missed});
  /// Points per game with him minus without him, against expectation (shrunk). Descriptive only.
  final double index;
  final int played, missed;
}

class Career {
  const Career({required this.seasons, required this.p10, required this.p50, required this.p90,
      required this.peakValue, required this.peakAge, required this.vsCurve});
  final List<String> seasons;
  final List<int> p10, p50, p90;
  final int peakValue;
  final double? peakAge;

  /// "ahead", "on" or "behind" the usual curve for his position and age.
  final String vsCurve;
}

class Prospect {
  const Prospect({required this.id, required this.name, required this.img,
      required this.clubName, required this.league, required this.leagueName, required this.pos,
      required this.age, required this.marketValue, required this.ga90,
      required this.translatedGa90, required this.pRegular});
  factory Prospect.fromJson(Map<String, dynamic> j) => Prospect(
      id: _i(j['id'])!, name: j['name'] as String, img: _s(j['img']),
      clubName: _s(j['club_name']), league: j['league'] as String,
      leagueName: j['league_name'] as String, pos: _s(j['pos']), age: _d(j['age']),
      marketValue: _i(j['market_value']), ga90: _d(j['ga90'])!,
      translatedGa90: _d(j['translated_ga90'])!, pRegular: _d(j['p_regular'])!);
  final int id;
  final String name;
  final String? img;
  final String? clubName;
  final String league;
  final String leagueName;
  final String? pos;
  final double? age;
  final int? marketValue;
  final double ga90, translatedGa90, pRegular;
}

class Manager {
  const Manager({required this.name, required this.club, required this.league,
      required this.games, required this.since, required this.pae, required this.paeRaw,
      required this.per38, required this.first10});
  factory Manager.fromJson(Map<String, dynamic> j) => Manager(
      name: j['name'] as String, club: _i(j['club'])!, league: j['league'] as String,
      games: _i(j['games'])!, since: DateTime.parse(j['since'] as String),
      pae: _d(j['pae'])!, paeRaw: _d(j['pae_raw'])!, per38: _d(j['per38'])!,
      first10: _d(j['first10']));
  final String name;
  final int club;
  final String league;
  final int games;
  final DateTime since;

  /// Points above expected per game: shrunk toward 0, and raw.
  final double pae, paeRaw, per38;
  final double? first10;
}

class Bounce {
  const Bounce({required this.changes, required this.before, required this.first10,
      required this.next20, required this.control, this.gapCi});
  final int changes;
  final double before, first10;

  /// Games 11-30, only for managers who lasted that long.
  final double? next20;

  /// What clubs on an equally bad run did over their next 10 when they kept the manager.
  final double? control;

  /// 95% interval for the new manager's first 10 minus the kept-manager control.
  final List<double>? gapCi;
}

class Player {
  const Player({required this.id, required this.name, required this.img, required this.club,
      required this.clubName, required this.league, required this.pos, required this.subPos,
      required this.age, required this.nat, required this.foot, required this.height,
      required this.marketValue, required this.fairValue, required this.valueGapPct,
      required this.valueWhy, required this.season, required this.last5,
      required this.forecastGa5, required this.workload, required this.valueHistory,
      required this.transfers, required this.similar, required this.trendScore,
      required this.trendReasons, this.dependency, this.career});

  factory Player.fromJson(Map<String, dynamic> j) {
    final s = _m(j['season']);
    final f = _m(j['form']);
    final w = j['workload'] == null ? null : _m(j['workload']);
    final t = _m(j['trend']);
    final d = j['dependency'] == null ? null : _m(j['dependency']);
    final c = j['career'] == null ? null : _m(j['career']);
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
      dependency: d == null
          ? null
          : Dependency(index: _d(d['index'])!, played: _i(d['played'])!,
              missed: _i(d['missed'])!),
      career: !_validCareer(c)
          ? null
          : Career(
              seasons: [for (final e in c!['seasons'] as List) e as String],
              p10: _is(c['p10']), p50: _is(c['p50']), p90: _is(c['p90']),
              peakValue: _i(c['peak_value'])!, peakAge: _d(c['peak_age']),
              vsCurve: c['vs_curve'] as String),
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
  final Dependency? dependency;
  final Career? career;

  /// Model outputs are only shown for players with 900+ minutes in the season.
  bool get qualified => season.minutes >= 900;
}

class Bundle {
  Bundle({required this.schemaVersion, required this.generatedAt, required this.playersThrough,
      required this.clubsThrough, required this.playerSeason, required this.leagues,
      required this.clubs, required this.fixtures, required this.players, required this.models,
      this.prospects = const [], this.managers = const []});

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
      prospects: [for (final e in _maps(j['prospects'])) Prospect.fromJson(e)],
      managers: [for (final e in _maps(j['managers'])) Manager.fromJson(e)],
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
  final List<Prospect> prospects;
  final List<Manager> managers;

  late final Map<int, Club> clubById = {for (final c in clubs) c.id: c};
  late final Map<int, Player> playerById = {for (final p in players) p.id: p};
  late final Map<String, League> leagueById = {for (final l in leagues) l.id: l};
  late final Map<int, Manager> managerByClub = {for (final m in managers) m.club: m};

  Map<String, dynamic>? _model(String k) =>
      models[k] == null ? null : _m(models[k]);

  /// True when the Big Five list is ranked by price because the model didn't beat it.
  bool get prospectsByPrice => _model('prospects')?['chosen'] != 'model';

  /// Split-half correlation of the manager effect: odd games vs even games (near zero = luck).
  double? get managerSplitHalf => _d(_model('manager_effect')?['split_half_r']);

  late final Bounce? bounce = () {
    final b = _model('manager_effect')?['bounce'];
    if (b == null) return null;
    final m = _m(b);
    if (m['first10'] == null) return null;
    return Bounce(changes: _i(m['n_changes'])!, before: _d(m['last10_before'])!,
        first10: _d(m['first10'])!, next20: _d(m['next20']),
        control: _d(m['control_next10']),
        gapCi: m['gap_ci'] == null ? null : _ds(m['gap_ci']));
  }();
}
