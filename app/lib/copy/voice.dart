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

String signed(double v, {int digits = 1}) {
  final s = v.abs().toStringAsFixed(digits);
  if (double.parse(s) == 0) return s; // no sign on a zero
  return '${v > 0 ? '+' : '−'}$s';
}

/// Plain words for a manager's luck-adjusted record.
String managerLine(double per38) => per38.abs() < 1
    ? 'Getting about what the squad should'
    : per38 > 0
        ? 'Getting more than the squad should'
        : 'Getting less than the squad should';

/// Plain words for results with and without a player.
String dependencyLine(double index) => index.abs() < 0.1
    ? 'Results barely change without him'
    : index > 0
        ? 'Results drop when he misses out'
        : 'Results hold up, even improve, without him';

/// The sacking-bounce finding in plain words, decided by the numbers and their interval.
String bounceVerdict(Bounce b) {
  final lead = 'Points per game against what the squad should have taken, across '
      '${b.changes} mid-season manager changes in the top five leagues.';
  final c = b.control;
  if (c == null) return lead;
  final gap = b.first10 - c;
  final drift = c - b.before; // what clubs that kept their manager recovered anyway
  final ci = b.gapCi;
  final first = drift > gap.abs()
      ? '$lead Clubs on an equally bad run that kept their manager bounced back too: most '
          'of the "new-manager bounce" is a team drifting back to its level.'
      : '$lead Clubs on an equally bad run that kept their manager recovered '
          '${signed(drift, digits: 2)} a game.';
  if (ci == null) {
    return '$first New managers did ${signed(gap, digits: 2)} a game better than that.';
  }
  if (ci[0] <= 0 && ci[1] >= 0) {
    return '$first New managers did ${signed(gap, digits: 2)} a game better than that, '
        'which is within the noise.';
  }
  return ci[0] > 0
      ? '$first New managers added a small real edge on top: ${signed(gap, digits: 2)} '
          'a game.'
      : '$first Clubs that changed did ${signed(gap, digits: 2)} a game worse than those '
          'that kept theirs.';
}

/// How much to trust a manager figure, from the split-half check.
String managerTrust(double? r) => r == null || r < 0.05
    ? "Mostly luck: a manager's odd and even games don't agree."
    : r < 0.3
        ? "Mostly luck with some skill underneath: a manager's odd and even games agree "
            'only weakly (r = ${r.toStringAsFixed(2)}).'
        : "A real but noisy signal: a manager's odd and even games agree "
            '(r = ${r.toStringAsFixed(2)}).';
