// DELETE /api/events/:id 回應的 notified（通知了幾位報名者）。
// 欄位依 前端待辦 §A2 手寫，未錄 fixture——錄製會真的刪掉一場活動。

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/services/event_service.dart';

import '../helpers/widget_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(stubCommonChannels);
  tearDown(restoreHttp);

  test('回傳後端通知的報名者人數', () async {
    installMockClient({
      '/api/events/9': {'success': true, 'notified': 3},
    });

    expect(await EventService.deleteEvent(9), 3);
  });

  test('回應沒有 notified 欄位時視為 0', () async {
    installMockClient({
      '/api/events/9': {'success': true},
    });

    expect(await EventService.deleteEvent(9), 0);
  });

  test('notified 型別不對時視為 0', () async {
    installMockClient({
      '/api/events/9': {'success': true, 'notified': 'abc'},
    });

    expect(await EventService.deleteEvent(9), 0);
  });
}
