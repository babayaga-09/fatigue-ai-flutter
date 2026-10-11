import 'package:flutter_test/flutter_test.dart';
import 'package:touchline/format.dart';

void main() {
  test('money', () {
    expect(money(null), '–');
    expect(money(750000), '€750K');
    expect(money(2400000), '€2.4M');
    expect(money(45000000), '€45M');
    expect(money(180000000), '€180M');
    expect(signedMoney(12000000), '+€12M');
    expect(signedMoney(-3500000), '−€3.5M');
  });

  test('pct and dates', () {
    expect(pct(0.706), '71%');
    expect(shortDate(DateTime(2026, 5, 24)), '24 May');
    final now = DateTime(2026, 10, 5, 9); // Monday
    expect(kickoffLabel(DateTime(2026, 10, 5, 15), now), 'Today 15:00');
    expect(kickoffLabel(DateTime(2026, 10, 6, 20, 45), now), 'Tomorrow 20:45');
    expect(kickoffLabel(DateTime(2026, 10, 10, 15), now), 'Sat 15:00');
    expect(kickoffLabel(DateTime(2026, 10, 20, 15), now), '20 Oct');
  });

  test('thousands and ordinal', () {
    expect(thousands(4498), '4,498');
    expect(thousands(980), '980');
    expect(thousands(1234567), '1,234,567');
    expect([1, 2, 3, 4, 11, 12, 13, 21, 22, 23].map(ordinal),
        ['1st', '2nd', '3rd', '4th', '11th', '12th', '13th', '21st', '22nd', '23rd']);
  });

  test('monthYear keeps the year', () {
    expect(monthYear(DateTime(2019, 12, 22)), 'Dec 2019');
  });
}
