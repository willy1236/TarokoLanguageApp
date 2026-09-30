// 收件匣 service：查詢參數、標已讀的 body，以及標完重抓未讀數。

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_application_1/services/inbox_service.dart';
import 'package:flutter_application_1/services/notification_summary_service.dart';

import '../helpers/fixtures.dart';
import '../helpers/widget_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<http.Request> seen;

  setUp(() {
    stubCommonChannels();
    seen = [];
    installMockClient({
      '/api/inbox': loadFixtureMap('get_api_inbox.json'),
      '/api/inbox/read': {'ok': true, 'marked': 1},
      '/api/notifications/summary': {
        'inbox': {'forum': 0, 'event': 0, 'total': 0},
        'total': 0,
      },
    }, onRequest: seen.add);
  });
  tearDown(() {
    restoreHttp();
    NotificationSummaryService.clear();
  });

  http.Request only(String path) => seen.singleWhere((r) => r.url.path == path);

  test('全部分類的第一頁不帶 category 與 cursor', () async {
    final page = await InboxService.fetch();

    expect(only('/api/inbox').url.queryParameters, isEmpty);
    expect(page.items, isNotEmpty);
  });

  test('帶分類與上一頁的游標原字串', () async {
    await InboxService.fetch(category: 'announcement', cursor: '880');

    expect(only('/api/inbox').url.queryParameters, {
      'category': 'announcement',
      'cursor': '880',
    });
  });

  test('標一則已讀送 ids，完成後重抓未讀數', () async {
    await InboxService.markRead([901]);
    await NotificationSummaryService.refresh();

    expect(jsonDecode(only('/api/inbox/read').body), {
      'ids': [901],
    });
    expect(
      seen.where((r) => r.url.path == '/api/notifications/summary'),
      isNotEmpty,
    );
  });

  test('全部已讀：全部分類只送 all，單一分類多帶 category', () async {
    await InboxService.markAllRead();
    expect(jsonDecode(only('/api/inbox/read').body), {'all': true});
    await NotificationSummaryService.refresh();

    seen.clear();
    await InboxService.markAllRead(category: 'forum');
    expect(jsonDecode(only('/api/inbox/read').body), {
      'all': true,
      'category': 'forum',
    });
    await NotificationSummaryService.refresh();
  });
}
