// 共用日期函式：後端給的是 UTC，函式內部要先轉本地再取年月日，呼叫端不必記得轉。
// 台灣凌晨 0～8 點的時間在 UTC 仍是前一天，沒轉就會差一天。

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/utils/date_format.dart';

void main() {
  setUpAll(() {
    // UTC 時區下 toLocal() 等於沒轉，拿掉修正也會過。
    // CI 以 TZ=Asia/Taipei 執行，這裡擋住在 UTC 環境誤以為有測到的情況。
    expect(
      DateTime(2026, 9, 1).timeZoneOffset,
      isNot(Duration.zero),
      reason: '這組測試要在非 UTC 時區執行，例如 TZ=Asia/Taipei',
    );
  });

  // 本地 9/1（週二）03:05，在 UTC+8 時是 UTC 8/31（週一）19:05。
  final fromBackend = DateTime(2026, 9, 1, 3, 5).toUtc();

  test('傳入 UTC 時間，以本地日期時間顯示', () {
    expect(formatDateTime(fromBackend), '2026/09/01 03:05');
    expect(formatDate(fromBackend), '2026/09/01');
    expect(formatTime(fromBackend), '03:05');
    expect(weekdayLabel(fromBackend), '週二');
  });

  test('本地月初凌晨，月份不退回上個月', () {
    expect(monthLabel(fromBackend), '9月');
  });

  test('本地 23:59 與隔天 00:00 顯示不同日期', () {
    expect(formatDate(DateTime(2026, 8, 31, 23, 59).toUtc()), '2026/08/31');
    expect(formatDate(DateTime(2026, 9, 1).toUtc()), '2026/09/01');
  });

  test('已是本地時間時結果不變', () {
    final local = DateTime(2026, 9, 1, 3, 5);
    expect(formatDateTime(local), '2026/09/01 03:05');
  });

  group('24 小時制邊界', () {
    test('午夜是 00:00，不是 12:00 或 24:00', () {
      expect(formatTime(DateTime(2026, 9, 1).toUtc()), '00:00');
      expect(formatDateTime(DateTime(2026, 9, 1).toUtc()), '2026/09/01 00:00');
    });

    test('中午是 12:00，下午兩點是 14:05', () {
      expect(formatTime(DateTime(2026, 9, 1, 12).toUtc()), '12:00');
      expect(formatTime(DateTime(2026, 9, 1, 14, 5).toUtc()), '14:05');
      expect(formatTime(DateTime(2026, 9, 1, 23, 59).toUtc()), '23:59');
    });
  });

  test('本地跨年凌晨：年份、月份、日都不退回前一天', () {
    final newYear = DateTime(2027, 1, 1, 0, 30).toUtc();
    expect(formatDateTime(newYear), '2027/01/01 00:30');
    expect(monthLabel(newYear), '1月');
    expect(dayLabel(newYear), '01');
    expect(weekdayLabel(newYear), '週五');
  });

  test('月、日、時、分個位數都補零，兩位數不變', () {
    expect(formatDateTime(DateTime(2026, 1, 2, 3, 4)), '2026/01/02 03:04');
    expect(formatDateTime(DateTime(2026, 12, 31, 10, 59)), '2026/12/31 10:59');
  });

  test('日期塊：月份不補零、日補零', () {
    expect(monthLabel(fromBackend), '9月');
    expect(dayLabel(fromBackend), '01');
    expect(dayLabel(DateTime(2026, 9, 30)), '30');
  });

  test('星期一週七天都對得上，週日是「週日」', () {
    // 2026/09/06 是週日。
    final sunday = DateTime(2026, 9, 6);
    expect(
      List.generate(7, (i) => weekdayLabel(sunday.add(Duration(days: i)))),
      ['週日', '週一', '週二', '週三', '週四', '週五', '週六'],
    );
  });

  group('聊天室日期分隔', () {
    // 今天是本地 2026/10/13（週二）上午 9 點。
    final now = DateTime(2026, 10, 13, 9);

    test('今天、昨天以本地日期判斷，凌晨的 UTC 時間不算成前一天', () {
      expect(
        chatDayLabel(DateTime(2026, 10, 13, 0, 5).toUtc(), now: now),
        '今天',
      );
      expect(
        chatDayLabel(DateTime(2026, 10, 12, 23, 59).toUtc(), now: now),
        '昨天',
      );
      expect(
        chatDayLabel(DateTime(2026, 10, 12, 0, 1).toUtc(), now: now),
        '昨天',
      );
    });

    test('今年更早顯示月日與單字星期，往年加年份', () {
      expect(chatDayLabel(DateTime(2026, 10, 9, 15), now: now), '10月9日（五）');
      expect(
        chatDayLabel(DateTime(2025, 10, 9, 15), now: now),
        '2025年10月9日（四）',
      );
    });

    test('元旦的昨天是前一年的 12/31', () {
      final newYear = DateTime(2027, 1, 1, 9);
      expect(chatDayLabel(DateTime(2026, 12, 31, 20), now: newYear), '昨天');
      expect(
        chatDayLabel(DateTime(2026, 12, 30, 20), now: newYear),
        '2026年12月30日（三）',
      );
    });

    test('單字星期', () {
      expect(weekdayShortLabel(DateTime(2026, 9, 6)), '日');
      expect(weekdayShortLabel(fromBackend), '二');
    });
  });

  group('好友列表最後活動時間', () {
    final now = DateTime(2026, 10, 13, 9);

    test('今天顯示時分、昨天顯示「昨天」，以本地日期判斷', () {
      expect(
        formatActivityTime(DateTime(2026, 10, 13, 0, 5).toUtc(), now: now),
        '00:05',
      );
      expect(
        formatActivityTime(DateTime(2026, 10, 12, 23, 59).toUtc(), now: now),
        '昨天',
      );
    });

    test('今年更早「10/9」、往年「2025/10/9」，月日不補零', () {
      expect(formatActivityTime(DateTime(2026, 10, 9, 15), now: now), '10/9');
      expect(formatActivityTime(DateTime(2026, 1, 2, 15), now: now), '1/2');
      expect(
        formatActivityTime(DateTime(2025, 10, 9, 15), now: now),
        '2025/10/9',
      );
    });
  });
}
