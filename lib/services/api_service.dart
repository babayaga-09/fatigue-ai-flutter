import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class ApiService {
  static const _base = 'http://10.0.2.2:8000';

  Future<T> _get<T>(String path, T Function(dynamic) parse) async {
    final r = await http
        .get(Uri.parse('$_base$path'))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) return parse(jsonDecode(r.body));
    throw Exception('GET $path → ${r.statusCode}: ${r.body}');
  }

  Future<List<League>> getLeagues() => _get(
        '/leagues',
        (j) => (j as List).map((e) => League.fromJson(e)).toList(),
      );

  Future<List<TeamModel>> getTeams(String league) => _get(
        '/teams?league=$league',
        (j) => (j as List).map((e) => TeamModel.fromJson(e)).toList(),
      );

  Future<List<PlayerSummary>> getPlayers(int teamId) => _get(
        '/players?team_id=$teamId',
        (j) =>
            (j as List).map((e) => PlayerSummary.fromJson(e)).toList(),
      );

  Future<PlayerProfile> getPlayer(int playerId, String league) => _get(
        '/player/$playerId?league=$league',
        (j) => PlayerProfile.fromJson(j as Map<String, dynamic>),
      );

  Future<PredictionResult> predict({
    required List<List<double>> sequence,
    required String position,
  }) async {
    final r = await http
        .post(
          Uri.parse('$_base/predict'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'sequence': sequence,
            'position': position,
          }),
        )
        .timeout(const Duration(seconds: 10));
    if (r.statusCode == 200) {
      return PredictionResult.fromJson(
          jsonDecode(r.body) as Map<String, dynamic>);
    }
    throw Exception('Predict → ${r.statusCode}: ${r.body}');
  }

  Future<Map<String, PlayerProfile>> compare(
      int aId, int bId, String league) async {
    final r = await http
        .get(Uri.parse(
            '$_base/compare?player_a=$aId&player_b=$bId&league=$league'))
        .timeout(const Duration(seconds: 15));
    if (r.statusCode == 200) {
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      return {
        'a': PlayerProfile.fromJson(j['player_a']),
        'b': PlayerProfile.fromJson(j['player_b']),
      };
    }
    throw Exception('Compare → ${r.statusCode}: ${r.body}');
  }
}