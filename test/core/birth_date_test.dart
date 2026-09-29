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

    test('解析 YYYY-MM-DD，其他格式或 null 回 null', () {
      expect(parseApiDate('1995-03-15'), DateTime(1995, 3, 15));
      expect(parseApiDate(null), isNull);
      expect(parseApiDate('1995-03-15T00:00:00Z'), isNull);
      expect(parseApiDate(19950315), isNull);
    });
  });
}
