// 未讀數刷新：進行中又被要求刷新時，完成後補抓一次，不讓舊結果留在紅點上。

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/services/notification_summary_service.dart';

import '../helpers/widget_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(stubCommonChannels);
  tearDown(() {
    restoreHttp();
    NotificationSummaryService.clear();
  });

  test('請求進行中又刷新：完成後再抓一次，採用新結果', () async {
    var gets = 0;
    final routes = <String, Object?>{
      '/api/notifications/summary': {'messages': 1, 'total': 1},
    };
    installMockClient(
      routes,
      onRequest: (_) => gets++,
      delayFor: (_) => const Duration(milliseconds: 20),
    );

    final first = NotificationSummaryService.refresh();
    // 第一個請求送出後才到的新訊息。
    routes['/api/notifications/summary'] = {'messages': 2, 'total': 2};
    final second = NotificationSummaryService.refresh();
    NotificationSummaryService.refresh();
    await Future.wait([first, second]);

    expect(gets, 2);
    expect(NotificationSummaryService.notifier.value.messages, 2);
  });

  test('沒有重疊時一次呼叫只打一次', () async {
    var gets = 0;
    installMockClient({
      '/api/notifications/summary': {'messages': 3, 'total': 3},
    }, onRequest: (_) => gets++);

    await NotificationSummaryService.refresh();

    expect(gets, 1);
    expect(NotificationSummaryService.notifier.value.messages, 3);
  });
}
