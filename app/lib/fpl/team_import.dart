/// Import a manager's team by FPL team ID (not on the web: FPL's API sends no CORS headers).
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'squad.dart';

const fplApi = 'https://fantasy.premierleague.com/api';

class ImportFailure implements Exception {
  const ImportFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

Future<Map<String, dynamic>> _get(http.Client c, String path) async {
  final http.Response r;
  try {
    r = await c.get(Uri.parse('$fplApi/$path'),
        headers: {'User-Agent': 'Touchline'}).timeout(const Duration(seconds: 20));
  } catch (_) {
    throw const ImportFailure('FPL is not responding. Try again in a minute.');
  }
  if (r.statusCode == 404) throw const ImportFailure('No FPL team with that ID.');
  if (r.statusCode != 200) {
    throw ImportFailure('FPL returned an error (${r.statusCode}). Try again later.');
  }
  return jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
}

/// Pulls the latest picks, bank, chips used this half of the season and an estimate of free
/// transfers. FPL only shares selling prices with the manager, so current prices stand in.
Future<Squad> importTeam(int id, http.Client client) async {
  final entry = await _get(client, 'entry/$id/');
  final gw = (entry['current_event'] as num?)?.toInt();
  if (gw == null) throw const ImportFailure('That team has not played a gameweek yet.');
  final picks = await _get(client, 'entry/$id/event/$gw/picks/');
  final history = await _get(client, 'entry/$id/history/');
  final ids = [for (final p in picks['picks'] as List) ((p as Map)['element'] as num).toInt()];
  final bank = ((picks['entry_history'] as Map)['bank'] as num).toInt();
  return Squad(
    ids: ids,
    bank: bank,
    freeTransfers: estimateFreeTransfers(history, gw),
    chipsAvailable: chipsLeft(history, gw + 1),
    teamId: id,
    teamName: entry['name'] as String?,
  );
}

/// Chips not yet used in the half of the season that [nextGw] falls in (each chip is
/// available once per half: gameweeks 1-19 and 20-38).
Set<String> chipsLeft(Map<String, dynamic> history, int nextGw) {
  final secondHalf = nextGw >= 20;
  final used = {
    for (final c in (history['chips'] as List? ?? const []))
      if ((((c as Map)['event'] as num).toInt() >= 20) == secondHalf) c['name'] as String
  };
  return {for (final c in allChips) if (!used.contains(c)) c};
}

/// One free transfer per gameweek after the first, banked up to five; transfers spend them,
/// and Wildcard / Free Hit weeks neither spend nor add. An estimate the manager can edit.
int estimateFreeTransfers(Map<String, dynamic> history, int currentGw) {
  final chipWeeks = {
    for (final c in (history['chips'] as List? ?? const []))
      if (const {'wildcard', 'freehit'}.contains((c as Map)['name']))
        (c['event'] as num).toInt()
  };
  final made = {
    for (final h in (history['current'] as List? ?? const []))
      ((h as Map)['event'] as num).toInt(): ((h['event_transfers'] as num?) ?? 0).toInt()
  };
  var ft = 0;
  for (var g = 2; g <= currentGw; g++) {
    if (chipWeeks.contains(g)) continue;
    ft = (ft + 1 - (made[g] ?? 0)).clamp(0, 5);
  }
  return (ft + 1).clamp(1, 5); // the transfer gained for the coming gameweek
}
