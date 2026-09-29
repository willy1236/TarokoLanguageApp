// 後台 service：端點、query、body 與回應解析。

import 'dart:convert';

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

  test('resolveReport：個人檔案判定成立帶 reset_fields，駁回不帶', () async {
    final bodies = <Map<String, dynamic>>[];
    installMockClient(
      {
        '/api/admin/forum/reports/9/resolve': {
          'ok': true,
          'status': 'dismissed',
        },
      },
      onRequest: (r) => bodies.add(jsonDecode(r.body) as Map<String, dynamic>),
    );

    await AdminService.resolveReport(
      9,
      'action',
      resetFields: ['video_nickname', 'avatar'],
    );
    await AdminService.resolveReport(9, 'dismiss');

    expect(bodies[0], {
      'action': 'action',
      'reset_fields': ['video_nickname', 'avatar'],
    });
    expect(bodies[1], {'action': 'dismiss'});
  });

  test('fetchCases 帶狀態；reviewCase 備註去空白、空備註不送', () async {
    final requests = <http.Request>[];
    installMockClient({
      '/api/admin/moderation/cases': loadSpecFixtureMap(
        'get_api_admin_moderation_cases.json',
      ),
      '/api/admin/moderation/cases/7/review': loadSpecFixtureMap(
        'post_api_admin_case_review_confirm.json',
      ),
    }, onRequest: requests.add);

    final page = await AdminService.fetchCases(status: 'confirmed');
    await AdminService.reviewCase(7, 'confirm', note: '  同意  ');
    await AdminService.reviewCase(7, 'overturn', note: '   ');

    expect(requests[0].url.queryParameters['status'], 'confirmed');
    expect(page.items, hasLength(7));
    expect(jsonDecode(requests[1].body), {'decision': 'confirm', 'note': '同意'});
    expect(jsonDecode(requests[2].body), {'decision': 'overturn'});
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
