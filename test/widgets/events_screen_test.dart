// EventsScreen（活動列表）的畫面層測試。
//
// 這支取代的人工測試：進活動頁看列表有沒有出來、切「全部／近期」有沒有重打 API、
// 切分類是不是前端篩選、沒有發起權限的帳號發起鈕是不是真的按不動、
// 後端掛掉時有沒有錯誤畫面與重試。
// 人工要驗「非 organizer 看不到發起」還得換帳號登入，特別麻煩。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/main.dart' show scaffoldMessengerKey;
import 'package:flutter_application_1/screens/events/events_screen.dart';
import 'package:flutter_application_1/services/account_lock_controller.dart';
import 'package:flutter_application_1/services/notification_summary_service.dart';
import 'package:flutter_application_1/services/user_service.dart';
import 'package:flutter_application_1/shared/widgets/async_state_view.dart';
import 'package:flutter_application_1/shared/widgets/module_header_actions.dart';
import 'package:flutter_application_1/shared/widgets/truku_empty_state.dart';

import '../helpers/widget_test_helpers.dart';

Map<String, dynamic> _event({
  int id = 1,
  String title = '部落豐年祭',
  String? category,
}) =>
    {
      'id': id,
      'title': title,
      'starts_at': '2026-12-01T10:00:00Z',
      'category': category,
      'status': 'active',
      'effective_status': 'active',
      'registration_open': true,
    };

Map<String, dynamic> _me({String role = 'user'}) => {
      'uid': 1,
      'created_at': '2026-01-01T00:00:00Z',
      'role': role,
    };

Widget _app() => MaterialApp(
      scaffoldMessengerKey: scaffoldMessengerKey,
      home: const Scaffold(body: EventsScreen()),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    stubCommonChannels();
    accountLockController.setLocked(false);
    UserService.clearCache();
    NotificationSummaryService.clear();
  });

  tearDown(() {
    restoreHttp();
    accountLockController.setLocked(false);
    UserService.clearCache();
    NotificationSummaryService.clear();
  });

  testWidgets('載入成功後顯示活動', (tester) async {
    installMockClient({
      '/api/events': {
        'events': [_event(title: '部落豐年祭'), _event(id: 2, title: '族語共學')],
      },
      '/api/me': _me(),
    });

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('部落豐年祭'), findsWidgets);
    expect(find.text('族語共學'), findsWidgets);
  });

  testWidgets('沒有活動時顯示空狀態', (tester) async {
    installMockClient({
      '/api/events': {'events': <dynamic>[]},
      '/api/me': _me(),
    });

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byType(TrukuEmptyState), findsOneWidget);
    expect(find.text('目前沒有活動'), findsOneWidget);
  });

  testWidgets('載入失敗顯示錯誤畫面，重試會再打一次 API', (tester) async {
    var calls = 0;
    installMockClient(
      {
        '/api/events': errorResponse('SERVER_ERROR', status: 500),
        '/api/me': _me(),
      },
      onRequest: (req) {
        if (req.url.path == '/api/events') calls++;
      },
    );

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byType(TrukuErrorView), findsOneWidget);
    expect(calls, 1);

    await tester.tap(find.text('重試'));
    await tester.pumpAndSettle();

    expect(calls, 2);
  });

  testWidgets('切到「近期」會用 scope=upcoming 重打 API', (tester) async {
    final scopes = <String?>[];
    installMockClient(
      {
        '/api/events': {'events': [_event()]},
        '/api/me': _me(),
      },
      onRequest: (req) {
        if (req.url.path == '/api/events') {
          scopes.add(req.url.queryParameters['scope']);
        }
      },
    );

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(scopes, ['all']);

    await tester.tap(find.text('近期'));
    await tester.pumpAndSettle();

    expect(scopes, ['all', 'upcoming']);
  });

  testWidgets('切分類是前端篩選，不會重打 API', (tester) async {
    var calls = 0;
    installMockClient(
      {
        '/api/events': {
          'events': [
            _event(title: '族語共學', category: '族語'),
            _event(id: 2, title: '陶藝工作坊', category: '工藝'),
          ],
        },
        '/api/me': _me(),
      },
      onRequest: (req) {
        if (req.url.path == '/api/events') calls++;
      },
    );

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(calls, 1);

    await tester.tap(find.text('族語'));
    await tester.pumpAndSettle();

    expect(calls, 1, reason: '分類篩選只在已載入資料上做，不該再打 API');
    expect(find.text('族語共學'), findsWidgets);
    expect(find.text('陶藝工作坊'), findsNothing);
  });

  testWidgets('分類篩選後沒有符合的活動時顯示空狀態', (tester) async {
    installMockClient({
      '/api/events': {
        'events': [_event(title: '族語共學', category: '族語')],
      },
      '/api/me': _me(),
    });

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('工藝'));
    await tester.pumpAndSettle();

    expect(find.byType(TrukuEmptyState), findsOneWidget);
  });

  testWidgets('一般使用者的發起鈕停用（沒有 organizer 權限）', (tester) async {
    installMockClient({
      '/api/events': {'events': [_event()]},
      '/api/me': _me(role: 'user'),
    });

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(
      tester.widget<ModuleComposeButton>(find.byType(ModuleComposeButton)).enabled,
      isFalse,
    );
  });

  testWidgets('organizer 的發起鈕啟用', (tester) async {
    installMockClient({
      '/api/events': {'events': [_event()]},
      '/api/me': _me(role: 'organizer'),
    });

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(
      tester.widget<ModuleComposeButton>(find.byType(ModuleComposeButton)).enabled,
      isTrue,
    );
  });

  testWidgets('查不到身分時保守擋下發起（不能因為 API 失敗就放行）', (tester) async {
    installMockClient({
      '/api/events': {'events': [_event()]},
      '/api/me': errorResponse('SERVER_ERROR', status: 500),
    });

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(
      tester.widget<ModuleComposeButton>(find.byType(ModuleComposeButton)).enabled,
      isFalse,
    );
  });

  testWidgets('唯讀模式下 organizer 按發起會被擋並顯示提示', (tester) async {
    installMockClient({
      '/api/events': {'events': [_event()]},
      '/api/me': _me(role: 'organizer'),
    });

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    accountLockController.setLocked(true);
    await tester.tap(find.byType(ModuleComposeButton));
    await tester.pump();

    expect(find.text(readOnlyMessage), findsOneWidget);
  });
}
