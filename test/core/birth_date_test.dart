import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/shared/utils/birth_date.dart';

void main() {
  group('taiwanToday', () {
    test('UTC 15:59 仍是台灣當天，16:00 起是隔天', () {
      expect(
        taiwanToday(now: DateTime.utc(2026, 9, 29, 15, 59)),
        DateTime(2026, 9, 29),
      );
      expect(
        taiwanToday(now: DateTime.utc(2026, 9, 29, 16)),
        DateTime(2026, 9, 30),
      );
    });
  });

  test('最早可選 120 年前那一年的 1 月 1 日（後端只比年份）', () {
    expect(earliestBirthDate(now: DateTime.utc(2026, 9, 29)), DateTime(1906));
  });

  group('日期格式', () {
    test('送後端補零成 YYYY-MM-DD，顯示用 YYYY/MM/DD', () {
      expect(formatApiDate(DateTime(2001, 7, 4)), '2001-07-04');
      expect(formatDisplayDate(DateTime(2001, 7, 4)), '2001/07/04');
    });

    test('後端給的生日顯示同一天，不因時區差一天', () {
      expect(formatDisplayDate(parseApiDate('2001-01-01')!), '2001/01/01');
      expect(formatDisplayDate(parseApiDate('1999-12-31')!), '1999/12/31');
    });

    test('解析 YYYY-MM-DD，其他格式或 null 回 null', () {
      expect(parseApiDate('1995-03-15'), DateTime(1995, 3, 15));
      expect(parseApiDate(null), isNull);
      expect(parseApiDate('1995-03-15T00:00:00Z'), isNull);
      expect(parseApiDate(19950315), isNull);
      expect(parseApiDate('2026-02-30'), isNull);
    });
  });

  group('isAdultOn（生日當天算滿 18 歲）', () {
    final birth = DateTime(2008, 9, 29);

    test('生日前一天未滿', () {
      expect(isAdultOn(birth, DateTime(2026, 9, 28)), isFalse);
    });

    test('生日當天算滿', () {
      expect(isAdultOn(birth, DateTime(2026, 9, 29)), isTrue);
    });

    test('跨年：年底出生者隔年初才滿', () {
      final dec = DateTime(2008, 12, 31);
      expect(isAdultOn(dec, DateTime(2026, 12, 30)), isFalse);
      expect(isAdultOn(dec, DateTime(2026, 12, 31)), isTrue);
      expect(isAdultOn(DateTime(2009, 1, 1), DateTime(2026, 12, 31)), isFalse);
    });

    test('2/29 出生：非閏年 2/28 未滿、3/1 起算滿，與後端一致', () {
      final leap = DateTime(2008, 2, 29);
      expect(isAdultOn(leap, DateTime(2026, 2, 28)), isFalse);
      expect(isAdultOn(leap, DateTime(2026, 3, 1)), isTrue);
    });
  });
}
