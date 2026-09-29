// 後台 service：端點、query、body 與回應解析。

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_application_1/services/admin_service.dart';

import '../helpers/fixtures.dart';
import '../helpers/widget_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(stubCommonChannels);
  tearDown(restoreHttp);

  late List<http.Request> seen;

  void respond(String path, Object? body) {
    seen = [];
    installMockClient({path: body}, onRequest: seen.add);
  }

  test('fetchReports 帶狀態與游標，解析清單與 page_info', () async {
    final fixture = loadSpecFixtureMap('get_api_admin_forum_reports.json');
    respond('/api/admin/forum/reports', {
      ...fixture,
      'page_info': {'next_cursor': 'c2', 'has_more': true},
    });

    final page = await AdminService.fetchReports(
      status: 'actioned',
      cursor: 'c1',
    );

    final query = seen.single.url.queryParameters;
    expect(query['status'], 'actioned');
    expect(query['cursor'], 'c1');
    expect(page.items, hasLength(4));
    expect(page.pageInfo.nextCursor, 'c2');
  });

  test('後端沒有 page_info 時視為沒有下一頁', () async {
    respond('/api/admin/forum/reports', {'reports': []});
    final page = await AdminService.fetchReports();
    expect(page.items, isEmpty);
    expect(page.pageInfo.hasMore, isFalse);
    expect(seen.single.url.queryParameters['status'], 'pending');
    expect(seen.single.url.queryParameters.containsKey('cursor'), isFalse);
  });
}
