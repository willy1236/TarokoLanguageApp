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
}
