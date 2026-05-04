class League {
  final String code, name;
  final int id;
  const League({required this.code, required this.name, required this.id});
  factory League.fromJson(Map<String, dynamic> j) =>
      League(code: j['code'], name: j['name'], id: j['id']);
}

class TeamModel {
  final int id;
  final String name, crest, tla;
  const TeamModel(
      {required this.id,
      required this.name,
      required this.crest,
      required this.tla});
  factory TeamModel.fromJson(Map<String, dynamic> j) => TeamModel(
      id: j['id'],
      name: j['name'],
      crest: j['crest'] ?? '',
      tla: j['tla'] ?? '');
}

class PlayerSummary {
  final int id;
  final String name, position, nationality;
  final int? shirtNumber;
  const PlayerSummary(
      {required this.id,
      required this.name,
      required this.position,
      required this.nationality,
      this.shirtNumber});
  factory PlayerSummary.fromJson(Map<String, dynamic> j) => PlayerSummary(
      id: j['id'],
      name: j['name'],
      position: j['position'] ?? 'Midfielder',
      nationality: j['nationality'] ?? '',
      shirtNumber: j['shirt_number']);
}

class RecentMatch {
  final String opponent, score, result, date, homeAway;
  final int passesMade, defActions;
  final double completionPct, matchRating;
  const RecentMatch({
    required this.opponent,
    required this.score,
    required this.result,
    required this.date,
    required this.homeAway,
    required this.passesMade,
    required this.defActions,
    required this.completionPct,
    required this.matchRating,
  });
  factory RecentMatch.fromJson(Map<String, dynamic> j) => RecentMatch(
      opponent: j['opponent'],
      score: j['score'],
      result: j['result'],
      date: j['date'],
      homeAway: j['home_away'],
      passesMade: j['passes_made'],
      defActions: j['def_actions'],
      completionPct: (j['completion_pct'] as num).toDouble(),
      matchRating: (j['match_rating'] as num?)?.toDouble() ?? 6.0);
}

class NextFixture {
  final String opponent, date, competition, homeAway, difficulty;
  final int difficultyScore;
  final int? opponentRank;
  const NextFixture({
    required this.opponent,
    required this.date,
    required this.competition,
    required this.homeAway,
    required this.difficulty,
    required this.difficultyScore,
    this.opponentRank,
  });
  factory NextFixture.fromJson(Map<String, dynamic> j) => NextFixture(
      opponent: j['opponent'],
      date: j['date'],
      competition: j['competition'],
      homeAway: j['home_away'],
      difficulty: j['difficulty'],
      difficultyScore: j['difficulty_score'],
      opponentRank: j['opponent_rank']);
}

class SeasonStats {
  final int goals, assists, yellowCards, redCards, appearances;
  final double avgRating;
  const SeasonStats({
    required this.goals,
    required this.assists,
    required this.yellowCards,
    required this.redCards,
    required this.appearances,
    required this.avgRating,
  });
  factory SeasonStats.fromJson(Map<String, dynamic> j) => SeasonStats(
      goals: j['goals'] ?? 0,
      assists: j['assists'] ?? 0,
      yellowCards: j['yellow_cards'] ?? 0,
      redCards: j['red_cards'] ?? 0,
      appearances: j['appearances'] ?? 0,
      avgRating: (j['avg_rating'] as num?)?.toDouble() ?? 6.0);
}

class PlayerProfile {
  final int id;
  final String name, position, posGroup, nationality, team, teamCrest;
  final String? dateOfBirth;
  final List<RecentMatch> recentMatches;
  final NextFixture? nextFixture;
  final SeasonStats? seasonStats;

  const PlayerProfile({
    required this.id,
    required this.name,
    required this.position,
    required this.posGroup,
    required this.nationality,
    required this.team,
    required this.teamCrest,
    this.dateOfBirth,
    required this.recentMatches,
    this.nextFixture,
    this.seasonStats,
  });

  factory PlayerProfile.fromJson(Map<String, dynamic> j) => PlayerProfile(
      id: j['id'],
      name: j['name'],
      position: j['position'],
      posGroup: j['pos_group'],
      nationality: j['nationality'] ?? '',
      team: j['team'] ?? '',
      teamCrest: j['team_crest'] ?? '',
      dateOfBirth: j['date_of_birth'],
      recentMatches: (j['recent_matches'] as List)
          .map((m) => RecentMatch.fromJson(m))
          .toList(),
      nextFixture: j['next_fixture'] != null
          ? NextFixture.fromJson(j['next_fixture'])
          : null,
      seasonStats: j['season_stats'] != null
          ? SeasonStats.fromJson(j['season_stats'])
          : null);
}

class PredictionResult {
  final double predictedAccuracy, performanceDrop, baselinePct;
  final double injuryRiskPct, formMomentumPct, fitnessScore;
  final String fatigueLevel, position, injuryLabel, formLabel;

  const PredictionResult({
    required this.predictedAccuracy,
    required this.performanceDrop,
    required this.baselinePct,
    required this.fatigueLevel,
    required this.position,
    required this.injuryRiskPct,
    required this.formMomentumPct,
    required this.fitnessScore,
    required this.injuryLabel,
    required this.formLabel,
  });

  factory PredictionResult.fromJson(Map<String, dynamic> j) =>
      PredictionResult(
          predictedAccuracy:
              (j['predicted_accuracy_pct'] as num).toDouble(),
          performanceDrop:
              (j['performance_drop_pct'] as num).toDouble(),
          baselinePct: (j['baseline_pct'] as num).toDouble(),
          fatigueLevel: j['fatigue_level'],
          position: j['position'],
          injuryRiskPct: (j['injury_risk_pct'] as num).toDouble(),
          formMomentumPct: (j['form_momentum_pct'] as num).toDouble(),
          fitnessScore: (j['fitness_score'] as num).toDouble(),
          injuryLabel: j['injury_label'],
          formLabel: j['form_label']);
}