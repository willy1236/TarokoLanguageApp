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

  test('下架貼文／留言／活動與置頂、解鎖：端點與 body', () async {
    final calls = <String, Map<String, dynamic>>{};
    installMockClient({
      '/api/admin/forum/posts/1/remove': {'case': null},
      '/api/admin/forum/comments/2/remove': {'case': null},
      '/api/admin/events/3/remove': {'case': null},
      '/api/admin/forum/posts/1/pin': {'id': 1, 'is_pinned': true},
      '/api/admin/users/9/unlock': {'ok': true, 'status': 'active'},
    }, onRequest: (r) => calls[r.url.path] = jsonDecode(r.body));

    await AdminService.removePost(1, '  廣告  ');
    await AdminService.removeComment(2, '洗版');
    await AdminService.removeEvent(3, '不實');
    final pinned = await AdminService.pinPost(1, pinned: true);
    await AdminService.unlockUser(9, note: '誤判');

    expect(calls['/api/admin/forum/posts/1/remove'], {'reason': '廣告'});
    expect(calls['/api/admin/forum/comments/2/remove'], {'reason': '洗版'});
    expect(calls['/api/admin/events/3/remove'], {'reason': '不實'});
    expect(calls['/api/admin/forum/posts/1/pin'], {'pinned': true});
    expect(pinned, isTrue);
    expect(calls['/api/admin/users/9/unlock'], {'admin_note': '誤判'});
  });

  test('resetProfile：勾選欄位才送 fields，空集合交給後端預設；unlock 空備註不送', () async {
    final bodies = <Map<String, dynamic>>[];
    installMockClient(
      {
        '/api/admin/users/9/profile/reset': {'case': null},
        '/api/admin/users/9/unlock': {'ok': true},
      },
      onRequest: (r) => bodies.add(jsonDecode(r.body) as Map<String, dynamic>),
    );

    await AdminService.resetProfile(9, '不雅', fields: {'video_nickname'});
    await AdminService.resetProfile(9, '不雅');
    await AdminService.unlockUser(9, note: '  ');

    expect(bodies[0], {
      'reason': '不雅',
      'fields': ['video_nickname'],
    });
    expect(bodies[1], {'reason': '不雅'});
    expect(bodies[2], isEmpty);
  });

  test('後端沒有 page_info 時視為沒有下一頁', () async {
    respond('/api/admin/forum/reports', {'reports': []});
    final page = await AdminService.fetchReports();
    expect(page.items, isEmpty);
    expect(page.pageInfo.hasMore, isFalse);
    expect(seen.single.url.queryParameters['status'], 'pending');
    expect(seen.single.url.queryParameters.containsKey('cursor'), isFalse);
  });

  group('使用者與角色', () {
    test('lookupUser 帶去空白的好友碼，解析錄製的回應', () async {
      respond(
        '/api/admin/users/lookup',
        loadFixtureMap('get_api_admin_users_lookup.json'),
      );

      final user = await AdminService.lookupUser('  testcode ');

      expect(seen.single.url.queryParameters, {'friend_code': 'testcode'});
      expect(user.uid, 20);
      expect(user.role, 'admin');
      expect(user.status, 'active');
      expect(user.birthDate, DateTime(2000, 1, 1));
      expect(user.tribeId, 31);
      expect(user.millet, 350);
    });

    test('fetchRoleUsers 解析錄製的角色清單', () async {
      respond(
        '/api/admin/users/roles',
        loadFixtureMap('get_api_admin_users_roles.json'),
      );

      final users = await AdminService.fetchRoleUsers();

      expect(users, hasLength(8));
      expect(users.first.role, 'admin');
      expect(users.last.role, 'organizer');
      expect(users[4].nickname, isEmpty, reason: '暱稱為 null 時不炸');
    });

    test('setRole 送角色與去空白理由，解析 changed', () async {
      final bodies = <Map<String, dynamic>>[];
      installMockClient(
        {
          '/api/admin/users/12/role': {
            'ok': true,
            'uid': 12,
            'role': 'organizer',
            'previous_role': 'organizer',
            'changed': false,
          },
        },
        onRequest: (r) {
          expect(r.method, 'PATCH');
          bodies.add(jsonDecode(r.body) as Map<String, dynamic>);
        },
      );

      final result = await AdminService.setRole(12, 'organizer', ' 部落負責人 ');

      expect(bodies.single, {'role': 'organizer', 'reason': '部落負責人'});
      expect(result.changed, isFalse);
      expect(result.role, 'organizer');
    });
  });
}
