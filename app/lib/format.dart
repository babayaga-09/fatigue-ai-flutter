const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov',
    'Dec'];
const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String money(int? eur) {
  if (eur == null) return '–';
  final m = eur / 1e6;
  if (m >= 10) return '€${m.round()}M';
  if (m >= 1) return '€${m.toStringAsFixed(1)}M';
  return '€${(eur / 1e3).round()}K';
}

String signedMoney(int eur) => '${eur >= 0 ? '+' : '−'}${money(eur.abs())}';

String pct(double p) => '${(p * 100).round()}%';

String shortDate(DateTime d) => '${d.day} ${_months[d.month - 1]}';

String _hm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String kickoffLabel(DateTime utc, DateTime now) {
  final k = utc.toLocal();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(k.year, k.month, k.day);
  final diff = day.difference(today).inDays;
  if (diff == 0) return 'Today ${_hm(k)}';
  if (diff == 1) return 'Tomorrow ${_hm(k)}';
  if (diff > 1 && diff < 7) return '${_days[k.weekday - 1]} ${_hm(k)}';
  return shortDate(k);
}
String thousands(int n) {
  final s = n.abs().toString();
  final b = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

String ordinal(int n) {
  final t = n % 100;
  if (t >= 11 && t <= 13) return '${n}th';
  return '$n${switch (n % 10) { 1 => 'st', 2 => 'nd', 3 => 'rd', _ => 'th' }}';
}

String count(int n, String word) => '$n $word${n == 1 ? '' : 's'}';
