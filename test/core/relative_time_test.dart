// formatRelativeTime（論壇、收件匣共用）：超過 7 天改顯示日期，格式與 formatDate 相同（補零），以本地時區計算。
// 後端給的是 UTC，台灣凌晨 0～8 點發的文在 UTC 仍是前一天，直接取年月日會差一天。

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/utils/date_format.dart';

void main() {
  setUpAll(() {
    // UTC 時區下 toLocal() 等於沒轉，下面兩個跨日測試拿掉修正也會過。
    // CI 以 TZ=Asia/Taipei 執行，這裡擋住在 UTC 環境誤以為有測到的情況。
    expect(
      DateTime(2026, 9, 1).timeZoneOffset,
      isNot(Duration.zero),
      reason: '這組測試要在非 UTC 時區執行，例如 TZ=Asia/Taipei',
    );
  });

  test('超過 7 天：以本地日期顯示，UTC 跨日邊界不差一天', () {
    // 本地 9/1 03:00，在 UTC+8 時是 UTC 8/31 19:00。
    final localEarlyMorning = DateTime(2026, 9, 1, 3);
    final fromBackend = localEarlyMorning.toUtc();

    expect(formatRelativeTime(fromBackend), '2026/09/01');
  });

  test('本地 23:59 與隔天 00:00 顯示不同日期', () {
    expect(
      formatRelativeTime(DateTime(2026, 8, 31, 23, 59).toUtc()),
      '2026/08/31',
    );
    expect(formatRelativeTime(DateTime(2026, 9, 1).toUtc()), '2026/09/01');
  });

  test('7 天內仍顯示相對時間', () {
    final threeDaysAgo = DateTime.now().toUtc().subtract(
      const Duration(days: 3),
    );
    expect(formatRelativeTime(threeDaysAgo), '3 天前');
  });
}
