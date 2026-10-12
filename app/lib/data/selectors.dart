import 'bundle.dart';

bool inLeague(String league, String? filter) => filter == null || league == filter;

const _accents = {
  'á': 'a', 'à': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a', 'ą': 'a', 'æ': 'ae',
  'ç': 'c', 'ć': 'c', 'č': 'c', 'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', 'ę': 'e', 'ě': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i', 'ı': 'i', 'ñ': 'n', 'ń': 'n', 'ň': 'n',
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o', 'ø': 'o', 'ő': 'o', 'œ': 'oe',
  'ś': 's', 'š': 's', 'ş': 's', 'ß': 'ss', 'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', 'ű': 'u',
  'ů': 'u', 'ý': 'y', 'ÿ': 'y', 'ž': 'z', 'ź': 'z', 'ż': 'z', 'ł': 'l', 'đ': 'd', 'ğ': 'g',
  'ř': 'r', 'ť': 't',
};

/// Lowercase, accents removed, invisible characters dropped: "Mbappé" matches "mbappe".
String fold(String s) {
  final b = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    if (ch == '­' || ch == '​') continue;
    b.write(_accents[ch] ?? ch);
  }
  return b.toString();
}

List<T> _top<T>(Iterable<T> xs, double Function(T) key, int n) {
  final l = xs.toList()..sort((a, c) => key(c).compareTo(key(a)));
  return l.take(n).toList();
}

List<Fixture> weekFixtures(Bundle b, String? league, DateTime now) => b.fixtures
    .where((f) =>
        !f.finished &&
        inLeague(f.league, league) &&
        f.kickoff.isAfter(now.subtract(const Duration(hours: 2))) &&
        f.kickoff.isBefore(now.add(const Duration(days: 7))))
    .toList()
  ..sort((a, c) => a.kickoff.compareTo(c.kickoff));

Fixture? featuredFixture(Bundle b, String? league, DateTime now) {
  final week = weekFixtures(b, league, now);
  if (week.isEmpty) return null;
  double weight(Fixture f) =>
      (b.clubById[f.home]?.elo ?? 1500) + (b.clubById[f.away]?.elo ?? 1500);
  return week.reduce((a, c) => weight(c) > weight(a) ? c : a);
}

List<Fixture> recentResults(Bundle b, String? league) =>
    b.fixtures.where((f) => f.finished && inLeague(f.league, league)).toList()
      ..sort((a, c) => c.kickoff.compareTo(a.kickoff));

List<Player> trendingPlayers(Bundle b, String? league, {int n = 12}) => _top(
    b.players.where((p) => p.trendScore != null && inLeague(p.league, league)),
    (p) => p.trendScore!, n);

List<Club> clubsInForm(Bundle b, String? league, {int n = 5}) => _top(
    b.clubs.where((c) => c.table.played > 0 && inLeague(c.league, league)),
    (c) => c.eloChange30d, n);

List<Club> powerRankings(Bundle b, String? league, {int n = 10}) =>
    _top(b.clubs.where((c) => inLeague(c.league, league)), (c) => c.elo, n);

const bargainFloor = 5000000;

List<Player> bargains(Bundle b, String? league, {int n = 10}) => _top(
    b.players.where((p) =>
        p.fairValue != null &&
        p.marketValue != null &&
        p.marketValue! >= bargainFloor &&
        p.fairValue! > p.marketValue! &&
        inLeague(p.league, league)),
    (p) => (p.fairValue! - p.marketValue!).toDouble(), n);

List<Player> overworked(Bundle b, String? league, {int n = 10}) => _top(
    b.players.where((p) => p.workload != null && inLeague(p.league, league)),
    (p) => (p.workload!.flag ? 1000 : 0) + p.workload!.index.toDouble(), n);

List<Club> leagueTable(Bundle b, String league) =>
    b.clubs.where((c) => c.league == league).toList()
      ..sort((a, c) => a.table.pos.compareTo(c.table.pos));

List<Player> squad(Bundle b, int clubId) => b.players.where((p) => p.club == clubId).toList()
  ..sort((a, c) => (c.marketValue ?? -1).compareTo(a.marketValue ?? -1));

List<Fixture> clubFixtures(Bundle b, int clubId) =>
    b.fixtures.where((f) => f.home == clubId || f.away == clubId).toList()
      ..sort((a, c) => a.kickoff.compareTo(c.kickoff));

List<Player> similarCheaper(Bundle b, Player p) => [
      for (final id in p.similar)
        if (b.playerById[id] case final s?)
          if ((s.marketValue ?? 0) < (p.marketValue ?? 0)) s
    ];

enum PlayerSort { trending, valueGap, forecast, marketValue, name }

class PlayerQuery {
  const PlayerQuery({this.text = '', this.league, this.pos, this.maxAge, this.maxPrice,
      this.sort = PlayerSort.trending});
  final String text;
  final String? league;
  final String? pos;
  final double? maxAge;
  final int? maxPrice;
  final PlayerSort sort;
}

List<Player> searchPlayers(Bundle b, PlayerQuery q) {
  final needle = fold(q.text.trim());
  final out = b.players.where((p) =>
      (needle.isEmpty || fold(p.name).contains(needle)) &&
      inLeague(p.league, q.league) &&
      (q.pos == null || p.pos == q.pos) &&
      (q.maxAge == null || (p.age != null && p.age! <= q.maxAge!)) &&
      (q.maxPrice == null || (p.marketValue != null && p.marketValue! <= q.maxPrice!)));
  const low = -1e18;
  final double Function(Player) key = switch (q.sort) {
    PlayerSort.trending => (p) => p.trendScore ?? low,
    PlayerSort.valueGap => (p) => p.fairValue != null && p.marketValue != null
        ? (p.fairValue! - p.marketValue!).toDouble()
        : low,
    PlayerSort.forecast => (p) => p.forecastGa5 ?? low,
    PlayerSort.marketValue => (p) => (p.marketValue ?? low).toDouble(),
    PlayerSort.name => (p) => 0,
  };
  final list = out.toList();
  if (q.sort == PlayerSort.name) {
    list.sort((a, c) => fold(a.name).compareTo(fold(c.name)));
  } else {
    list.sort((a, c) => key(c).compareTo(key(a)));
  }
  return list;
}

/// Current managers in a league (all leagues when null), best luck-adjusted record first.
List<Manager> managersIn(Bundle b, String? league) =>
    b.managers.where((m) => league == null || m.league == league).toList()
      ..sort((a, x) => x.pae.compareTo(a.pae));

/// Squad players with a with/without record, the most-played first. Deliberately not ordered
/// by the figure itself: it barely repeats from one half-season to the next, so it must not
/// read as a ranking.
List<Player> teamSheet(Bundle b, int clubId, {int n = 5}) =>
    (b.players.where((p) => p.club == clubId && p.dependency != null).toList()
          ..sort((a, x) => x.dependency!.played.compareTo(a.dependency!.played)))
        .take(n)
        .toList();
