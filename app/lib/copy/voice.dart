import '../data/bundle.dart';
import '../format.dart';

String fixtureVerdict(String home, String away, List<double> p) {
  final homeFav = p[0] >= p[2];
  final fav = homeFav ? home : away;
  final dog = homeFav ? away : home;
  final top = homeFav ? p[0] : p[2];
  final low = homeFav ? p[2] : p[0];
  if (top >= 0.65 && low <= 0.12) return '$fav should handle this. $dog need a miracle.';
  if (top >= 0.65) return '$fav should handle this.';
  if (top >= 0.5) return '$fav are favourites, not certainties.';
  if ((p[0] - p[2]).abs() < 0.08) return 'Too close to call. Expect nerves.';
  return '$fav shade it, but a draw is live.';
}

String formVerdict(List<String> form) {
  if (form.isEmpty) return 'No games yet.';
  final w = form.where((r) => r == 'W').length;
  final l = form.where((r) => r == 'L').length;
  if (w == 5) return 'Five from five. Somebody stop them.';
  if (w >= 4) return 'Flying.';
  if (l >= 4) return 'Grim viewing.';
  if (l >= 3) return 'Wobbling.';
  return 'Mixed bag.';
}

String workloadVerdict(String band) => switch (band) {
      'Heavy' => 'Legs are being asked a lot.',
      'High' => 'Busy schedule.',
      'Normal' => 'Load looks normal.',
      _ => 'Fresh legs.',
    };

String playerVerdict(Player p) {
  if (!p.qualified) return 'Not enough minutes yet to judge.';
  final gap = p.valueGapPct;
  final mv = p.marketValue ?? 0;
  if (gap != null && gap >= 0.5 && mv >= 2000000) {
    return 'Priced like a backup, plays like a starter.';
  }
  if (gap != null && gap <= -0.35) return 'Paying for the name more than the numbers.';
  if (p.trendReasons.isNotEmpty) {
    final r = p.trendReasons.first;
    return 'Running hot: ${r[0].toLowerCase()}${r.substring(1)}.';
  }
  final f = p.forecastGa5;
  if (f != null && f >= 2.5) {
    return 'Due a big week: about ${f.toStringAsFixed(1)} goal involvements in the next five.';
  }
  return 'Steady. Does the job, rarely the headline.';
}

String clubVerdict(Club c) {
  final p = c.proj;
  if (p == null) return formVerdict(c.form);
  if (p.pTitle >= 0.4) return 'In the title race: ${pct(p.pTitle)} to win it.';
  if (p.pTop4 >= 0.5) return 'Top four looks likely.';
  if (p.pReleg >= 0.5) return 'In real trouble at the bottom.';
  if (p.pReleg >= 0.2) return 'Looking over their shoulder.';
  return 'Mid-table and comfortable.';
}
