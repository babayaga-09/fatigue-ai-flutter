/// Typed view of the FPL bundle (docs/fpl-bundle-schema.md, schema 1).
library;

import 'dart:convert';

import 'package:archive/archive.dart';

const supportedFplSchema = 1;

class FplGameweek {
  const FplGameweek(this.id, this.name, this.deadline);
  final int id;
  final String name;
  final DateTime deadline;
}

class FplTeam {
  const FplTeam(this.id, this.name, this.short, this.clubId);
  final int id;
  final String name, short;
  final int clubId;
}

class FplPlayer {
  const FplPlayer({required this.id, required this.name, required this.full,
      required this.team, required this.pos, required this.price, required this.status,
      required this.news, required this.chance, required this.sel, required this.pPlay,
      required this.xpts, required this.why});
  final int id;
  final String name, full, pos, status;
  final int team, price;
  final String? news;
  final int? chance;
  final double sel, pPlay;
  final List<double> xpts;
  final Map<String, double>? why;

  double get next => xpts.isEmpty ? 0 : xpts.first;
  double horizon([int n = 5]) => xpts.take(n).fold(0.0, (a, b) => a + b);
  bool get flagged => status != 'a';
}

class FplSquadOption {
  const FplSquadOption(this.budget, this.squad, {this.gw});
  final int budget;
  final List<int> squad;
  final int? gw;
}

class FplBundle {
  FplBundle({required this.generatedAt, required this.season, required this.source,
      required this.nextGw, required this.gameweeks, required this.teams,
      required this.players, required this.wildcard, required this.freeHit,
      required this.models});

  factory FplBundle.fromJson(Map<String, dynamic> j) {
    if (j['fpl_schema_version'] != supportedFplSchema) {
      throw FormatException('Unsupported FPL bundle: ${j['fpl_schema_version']}');
    }
    List<Map<String, dynamic>> maps(Object? v) =>
        [for (final e in (v as List? ?? const [])) (e as Map).cast<String, dynamic>()];
    return FplBundle(
      generatedAt: DateTime.parse(j['generated_at'] as String),
      season: j['season'] as String,
      source: j['source'] as String,
      nextGw: (j['next_gw'] as num).toInt(),
      gameweeks: [for (final g in maps(j['gameweeks']))
        FplGameweek((g['id'] as num).toInt(), g['name'] as String,
            DateTime.parse(g['deadline'] as String))],
      teams: [for (final t in maps(j['teams']))
        FplTeam((t['id'] as num).toInt(), t['name'] as String, t['short'] as String,
            (t['club_id'] as num).toInt())],
      players: [for (final p in maps(j['players']))
        FplPlayer(
          id: (p['id'] as num).toInt(), name: p['name'] as String,
          full: (p['full'] ?? p['name']) as String, team: (p['team'] as num).toInt(),
          pos: p['pos'] as String, price: (p['price'] as num).toInt(),
          status: (p['status'] ?? 'a') as String, news: p['news'] as String?,
          chance: (p['chance'] as num?)?.toInt(), sel: (p['sel'] as num? ?? 0).toDouble(),
          pPlay: (p['p_play'] as num? ?? 0).toDouble(),
          xpts: [for (final x in (p['xpts'] as List)) (x as num).toDouble()],
          why: p['why'] == null ? null : {
            for (final e in (p['why'] as Map).entries)
              e.key as String: (e.value as num).toDouble()
          },
        )],
      wildcard: [for (final w in maps(j['wildcard']))
        FplSquadOption((w['budget'] as num).toInt(),
            [for (final i in w['squad'] as List) (i as num).toInt()])],
      freeHit: [for (final w in maps(j['free_hit']))
        FplSquadOption((w['budget'] as num).toInt(),
            [for (final i in w['squad'] as List) (i as num).toInt()],
            gw: (w['gw'] as num).toInt())],
      models: (j['models'] as Map? ?? const {}).cast<String, dynamic>(),
    );
  }

  final DateTime generatedAt;
  final String season;

  /// "ours" when Touchline's model passed its test against FPL's own numbers, else "fpl".
  final String source;
  final int nextGw;
  final List<FplGameweek> gameweeks;
  final List<FplTeam> teams;
  final List<FplPlayer> players;
  final List<FplSquadOption> wildcard, freeHit;
  final Map<String, dynamic> models;

  late final Map<int, FplPlayer> byId = {for (final p in players) p.id: p};
  late final Map<int, FplTeam> teamById = {for (final t in teams) t.id: t};
  List<int> get gws => [for (final g in gameweeks) g.id];
  FplGameweek? get nextGameweek =>
      gameweeks.isEmpty ? null : gameweeks.firstWhere((g) => g.id == nextGw,
          orElse: () => gameweeks.first);
}

FplBundle decodeFplGz(List<int> bytes) => FplBundle.fromJson(
    jsonDecode(utf8.decode(const GZipDecoder().decodeBytes(bytes))) as Map<String, dynamic>);
