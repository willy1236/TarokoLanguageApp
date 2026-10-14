// 後台 service：端點、query、body 與回應解析。

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/models/admin_video_meta.dart';
import 'package:flutter_application_1/models/content_category.dart';
import 'package:flutter_application_1/models/video_upload.dart';
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

  test('小米幣查帳：明細與對帳都帶 uid，明細帶游標', () async {
    final requests = <http.Request>[];
    installMockClient({
      '/api/admin/millet/transactions': loadFixtureMap(
        'get_api_admin_millet_transactions.json',
      ),
      '/api/admin/millet/reconcile': loadFixtureMap(
        'get_api_admin_millet_reconcile.json',
      ),
    }, onRequest: requests.add);

    final page = await AdminService.fetchMilletTransactions(20, cursor: 'c1');
    final reconcile = await AdminService.reconcileMillet(20);

    expect(requests[0].url.queryParameters, {'uid': '20', 'cursor': 'c1'});
    expect(requests[1].url.queryParameters, {'uid': '20'});
    expect(page.transactions, isNotEmpty);
    expect(reconcile.ledgerSum, -150);
    expect(reconcile.userMillet, 350);
    expect(reconcile.ok, isFalse);
  });

  group('分類管理', () {
    test('fetchCategories：路徑帶模組名，解析全部分類（含 count 0）', () async {
      final requests = <http.Request>[];
      installMockClient({
        '/api/admin/categories/articles': loadFixtureMap(
          'get_api_admin_categories_articles.json',
        ),
        '/api/admin/categories/events': loadFixtureMap(
          'get_api_admin_categories_events.json',
        ),
      }, onRequest: requests.add);

      final articles = await AdminService.fetchCategories(
        CategoryModule.articles,
      );
      await AdminService.fetchCategories(CategoryModule.events);

      expect(requests.map((r) => '${r.method} ${r.url.path}'), [
        'GET /api/admin/categories/articles',
        'GET /api/admin/categories/events',
      ]);
      expect(articles.first.value, 'tribal_intro');
      expect(articles.first.label, '部落宣傳');
      expect(articles.first.count, 0);
      expect(articles.last.sortOrder, 1000);
    });

    test('createCategory：label 去空白，sort_order 不填不送；解析 201 回應', () async {
      final requests = <http.Request>[];
      installMockClient({
        '/api/admin/categories/videos': jsonResponse({
          'category': {
            'value': '祭儀',
            'label': '祭儀',
            'sort_order': 100,
            'count': 0,
          },
        }, status: 201),
      }, onRequest: requests.add);

      final created = await AdminService.createCategory(
        CategoryModule.videos,
        ' 祭儀 ',
      );
      await AdminService.createCategory(
        CategoryModule.videos,
        '祭儀',
        sortOrder: 0,
      );

      expect(requests[0].method, 'POST');
      expect(jsonDecode(requests[0].body), {'label': '祭儀'});
      expect(jsonDecode(requests[1].body), {'label': '祭儀', 'sort_order': 0});
      expect(created.value, '祭儀');
      expect(created.count, 0);
    });

    test('updateCategory：value 編碼進路徑（中文、/），只送有給的欄位', () async {
      final requests = <http.Request>[];
      final ok = {
        'category': {'value': 'x', 'label': 'x', 'sort_order': 1},
      };
      installMockClient({
        '/api/admin/categories/articles/cultural': ok,
        '/api/admin/categories/events/%E9%87%A3%E9%AD%9A%2F%E7%8B%A9%E7%8D%B5':
            ok,
      }, onRequest: requests.add);

      await AdminService.updateCategory(
        CategoryModule.articles,
        'cultural',
        label: ' 文化 ',
      );
      await AdminService.updateCategory(
        CategoryModule.events,
        '釣魚/狩獵',
        sortOrder: 20,
      );

      expect(requests[0].method, 'PATCH');
      expect(jsonDecode(requests[0].body), {'label': '文化'});
      expect(
        requests[1].url.path,
        '/api/admin/categories/events/%E9%87%A3%E9%AD%9A%2F%E7%8B%A9%E7%8D%B5',
      );
      expect(jsonDecode(requests[1].body), {'sort_order': 20});
    });
  });
  group('createUploadVideo', () {
    test('送 source: upload、檔案資訊與影片資訊，解析影片與上傳工作階段', () async {
      final fixture = loadSpecFixtureMap('post_api_admin_videos_upload.json');
      seen = [];
      installMockClient({
        '/api/admin/videos': jsonResponse(fixture, status: 201),
      }, onRequest: seen.add);

      final result = await AdminService.createUploadVideo(
        const UploadFileInfo(
          name: 'IMG_0001.MOV',
          size: 431864320,
          contentType: 'video/quicktime',
        ),
        const AdminVideoMeta(title: ' 部落祭典紀錄 ', category: 'cultural'),
      );

      expect(seen.single.method, 'POST');
      expect(jsonDecode(seen.single.body), {
        'source': 'upload',
        'file_name': 'IMG_0001.MOV',
        'file_size': 431864320,
        'content_type': 'video/quicktime',
        'title': '部落祭典紀錄',
        'category': 'cultural',
      });
      expect(result.video.id, 107);
      expect(result.video.status, 'processing');
      expect(result.session.sessionUrl.host, 'storage.googleapis.com');
      expect(result.session.size, 431864320);
      expect(result.session.chunkMultiple, 262144);
    });

    test('UploadFileInfo.contentTypeOf 只認 mp4／mov（不分大小寫）', () {
      expect(UploadFileInfo.contentTypeOf('a.mp4'), 'video/mp4');
      expect(UploadFileInfo.contentTypeOf('IMG_0001.MOV'), 'video/quicktime');
      expect(UploadFileInfo.contentTypeOf('a.webm'), isNull);
      expect(UploadFileInfo.contentTypeOf('mp4'), isNull);
    });
  });
  group('retryVideo', () {
    test('對 /api/admin/videos/:id/retry 送檔案資訊，解析影片（處理中）與新的上傳工作階段', () async {
      final fixture = loadSpecFixtureMap('post_api_admin_videos_retry.json');
      seen = [];
      installMockClient({
        '/api/admin/videos/98/retry': jsonResponse(fixture),
      }, onRequest: seen.add);

      final result = await AdminService.retryVideo(
        98,
        const UploadFileInfo(
          name: 'weaving.mp4',
          size: 299892736,
          contentType: 'video/mp4',
        ),
      );

      expect(seen.single.method, 'POST');
      expect(jsonDecode(seen.single.body), {
        'file_name': 'weaving.mp4',
        'file_size': 299892736,
        'content_type': 'video/mp4',
      });
      expect(result.video.id, 98);
      expect(result.video.status, 'processing');
      expect(result.video.failReason, isNull);
      expect(result.session.sessionUrl.host, 'storage.googleapis.com');
      expect(result.session.size, 299892736);
      expect(result.session.chunkMultiple, 262144);
    });

    test('不是失敗的自家影片：409 VIDEO_NOT_FAILED 原樣丟出', () async {
      installMockClient({
        '/api/admin/videos/98/retry': errorResponse(
          'VIDEO_NOT_FAILED',
          status: 409,
          message: '只有失敗的自家影片可以重新上傳',
        ),
      });

      await expectLater(
        AdminService.retryVideo(
          98,
          const UploadFileInfo(
            name: 'weaving.mp4',
            size: 1,
            contentType: 'video/mp4',
          ),
        ),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'VIDEO_NOT_FAILED'),
        ),
      );
    });
  });
}
