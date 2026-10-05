// 檢舉佇列畫面：預覽呈現、下一頁、狀態切換、ADMIN_ONLY 退出後台。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/main.dart' show scaffoldMessengerKey;
import 'package:flutter_application_1/screens/admin/admin_error.dart';
import 'package:flutter_application_1/screens/admin/admin_reports_screen.dart';
import 'package:flutter_application_1/services/user_service.dart';

import '../../helpers/fixtures.dart';
import '../../helpers/widget_test_helpers.dart';

Widget _app(Widget home) =>
    MaterialApp(scaffoldMessengerKey: scaffoldMessengerKey, home: home);

Map<String, dynamic> _report(int id) => {
  'id': id,
  'target_type': 'post',
  'target_id': id,
  'reason': '理由$id',
  'status': 'pending',
  'reporter_nickname': '檢舉人',
  'target_preview': '預覽$id',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(stubCommonChannels);
  tearDown(() {
    restoreHttp();
    UserService.clearCache();
  });

  testWidgets('顯示各類型預覽，已刪除內容標示「內容已刪除」', (tester) async {
    installMockClient({
      '/api/admin/forum/reports': loadSpecFixtureMap(
        'get_api_admin_forum_reports.json',
      ),
    });

    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(const AdminReportsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('被檢舉貼文的標題'), findsOneWidget);
    expect(find.text('被檢舉的留言'), findsOneWidget);
    expect(find.text('內容已刪除'), findsOneWidget);
    expect(
      find.textContaining('6 → 7', findRichText: true),
      findsOneWidget,
      reason: '通話用 target_call',
    );
    expect(
      find.textContaining('不雅暱稱', findRichText: true),
      findsOneWidget,
      reason: '個人檔案用 target_profile',
    );
    expect(find.textContaining('小明', findRichText: true), findsWidgets);
  });

  testWidgets('切換狀態會以新狀態重抓', (tester) async {
    final statuses = <String?>[];
    installMockClient({
      '/api/admin/forum/reports': {'reports': []},
    }, onRequest: (r) => statuses.add(r.url.queryParameters['status']));

    await tester.pumpWidget(_app(const AdminReportsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('這個狀態目前沒有檢舉'), findsOneWidget);

    await tester.tap(find.text('已駁回'));
    await tester.pumpAndSettle();

    expect(statuses, ['pending', 'dismissed']);
  });

  testWidgets('捲到底以 next_cursor 載下一頁', (tester) async {
    final cursors = <String?>[];
    ApiClient.httpClient = MockClient((request) async {
      final cursor = request.url.queryParameters['cursor'];
      cursors.add(cursor);
      return jsonResponse(
        cursor == null
            ? {
                'reports': [for (var i = 1; i <= 12; i++) _report(i)],
                'page_info': {'next_cursor': 'p2', 'has_more': true},
              }
            : {
                'reports': [_report(99)],
                'page_info': {'next_cursor': null, 'has_more': false},
              },
      );
    });

    await tester.pumpWidget(_app(const AdminReportsScreen()));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -5000));
    await tester.pumpAndSettle();

    expect(cursors, [null, 'p2']);
    expect(find.text('預覽99'), findsOneWidget);
  });

  testWidgets('下一頁載入失敗：顯示重試列，再捲動不自動重打，點重試才重送', (tester) async {
    final cursors = <String?>[];
    var failNext = true;
    ApiClient.httpClient = MockClient((request) async {
      final cursor = request.url.queryParameters['cursor'];
      cursors.add(cursor);
      if (cursor == null) {
        return jsonResponse({
          'reports': [for (var i = 1; i <= 12; i++) _report(i)],
          'page_info': {'next_cursor': 'p2', 'has_more': true},
        });
      }
      if (failNext) return errorResponse('INTERNAL', status: 500);
      return jsonResponse({
        'reports': [_report(99)],
        'page_info': {'next_cursor': null, 'has_more': false},
      });
    });

    await tester.pumpWidget(_app(const AdminReportsScreen()));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -5000));
    await tester.pumpAndSettle();
    expect(cursors, [null, 'p2']);
    expect(find.text('載入失敗，點此重試'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, 300));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -5000));
    await tester.pumpAndSettle();
    expect(cursors, [null, 'p2'], reason: '失敗後捲動不自動重打');

    failNext = false;
    await tester.tap(find.text('載入失敗，點此重試'));
    await tester.pumpAndSettle();
    expect(cursors, [null, 'p2', 'p2']);
    expect(find.text('預覽99'), findsOneWidget);
    expect(find.text('載入失敗，點此重試'), findsNothing);
  });

  testWidgets('403 ADMIN_ONLY：顯示訊息、重抓 /api/me、退出後台', (tester) async {
    var meFetched = 0;
    installMockClient(
      {
        '/api/admin/forum/reports': errorResponse(
          'ADMIN_ONLY',
          status: 403,
          message: '只有管理員可以使用',
        ),
        '/api/me': {
          'uid': 1,
          'created_at': '2026-01-01T00:00:00Z',
          'role': 'user',
        },
      },
      onRequest: (r) {
        if (r.url.path == '/api/me') meFetched++;
      },
    );
    UserService.currentUid = 1;

    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => pushAdmin(context, const AdminReportsScreen()),
              child: const Text('進後台'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('進後台'));
    await tester.pumpAndSettle();

    expect(find.text('進後台'), findsOneWidget, reason: '已退回進入後台前的畫面');
    expect(find.text('檢舉佇列'), findsNothing);
    expect(find.text('只有管理員可以使用'), findsOneWidget);
    expect(meFetched, 1);
    expect(UserService.cachedUser?.role, 'user');
  });
}
