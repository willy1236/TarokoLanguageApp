// MyEventsScreen（我發起的活動）與 EventNotificationsScreen（活動通知）的畫面層測試。
//
// 這兩頁人工測起來特別囉唆：要先有「我發起過的活動」和「別人發給我的提醒」
// 才看得到非空狀態，而且取消／結束狀態的標籤要湊齊三種活動才驗得完。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/screens/events/event_notifications_screen.dart';
import 'package:flutter_application_1/screens/events/my_events_screen.dart';
import 'package:flutter_application_1/shared/widgets/async_state_view.dart';
import 'package:flutter_application_1/shared/widgets/truku_empty_state.dart';

import '../helpers/widget_test_helpers.dart';

Map<String, dynamic> _event({
  required int id,
  required String title,
  String effectiveStatus = 'active',
}) =>
    {
      'id': id,
      'title': title,
      'starts_at': '2026-12-01T10:00:00Z',
      'status': effectiveStatus == 'cancelled' ? 'cancelled' : 'active',
      'effective_status': effectiveStatus,
      'participant_count': 3,
    };

Map<String, dynamic> _notification({
  required int id,
  required String message,
  bool isRead = false,
}) =>
    {
      'id': id,
      'event_id': 1,
      'event_title': '部落豐年祭',
      'message': message,
      'sent_at': DateTime.now().toIso8601String(),
      'is_read': isRead,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(stubCommonChannels);
  tearDown(restoreHttp);

  group('MyEventsScreen', () {
    testWidgets('顯示我發起的活動與三種狀態標籤', (tester) async {
      installMockClient({
        '/api/events/mine': {
          'events': [
            _event(id: 1, title: '進行中的活動'),
            _event(id: 2, title: '結束的活動', effectiveStatus: 'ended'),
            _event(id: 3, title: '取消的活動', effectiveStatus: 'cancelled'),
          ],
        },
      });

      await tester.pumpWidget(const MaterialApp(home: MyEventsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('進行中的活動'), findsOneWidget);
      expect(find.text('進行中'), findsOneWidget);
      expect(find.text('已結束'), findsOneWidget);
      expect(find.text('已取消'), findsOneWidget);
    });

    testWidgets('沒發起過活動時顯示空狀態', (tester) async {
      installMockClient({
        '/api/events/mine': {'events': <dynamic>[]},
      });

      await tester.pumpWidget(const MaterialApp(home: MyEventsScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(TrukuEmptyState), findsOneWidget);
      expect(find.text('你還沒發起過活動'), findsOneWidget);
    });

    testWidgets('載入失敗時顯示錯誤並可重試', (tester) async {
      var calls = 0;
      installMockClient(
        {'/api/events/mine': errorResponse('SERVER_ERROR', status: 500)},
        onRequest: (_) => calls++,
      );

      await tester.pumpWidget(const MaterialApp(home: MyEventsScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(TrukuErrorView), findsOneWidget);

      await tester.tap(find.text('重試'));
      await tester.pumpAndSettle();

      expect(calls, 2);
    });
  });

  group('EventNotificationsScreen', () {
    testWidgets('顯示收到的提醒', (tester) async {
      installMockClient({
        '/api/events/notifications': {
          'notifications': [
            _notification(id: 1, message: '記得帶雨具'),
            _notification(id: 2, message: '集合地點改在活動中心', isRead: true),
          ],
          'unread_count': 1,
          'next_cursor': null,
        },
      });

      await tester.pumpWidget(
        const MaterialApp(home: EventNotificationsScreen()),
      );
      await tester.pumpAndSettle();

      // 副標題把訊息與相對時間串成同一個 Text（「記得帶雨具 · 剛剛」）。
      expect(find.textContaining('記得帶雨具'), findsOneWidget);
      expect(find.textContaining('集合地點改在活動中心'), findsOneWidget);
      expect(find.text('部落豐年祭'), findsNWidgets(2));
    });

    testWidgets('沒有通知時顯示空狀態', (tester) async {
      installMockClient({
        '/api/events/notifications': {
          'notifications': <dynamic>[],
          'unread_count': 0,
          'next_cursor': null,
        },
      });

      await tester.pumpWidget(
        const MaterialApp(home: EventNotificationsScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TrukuEmptyState), findsOneWidget);
      expect(find.text('還沒有收到活動通知'), findsOneWidget);
    });

    testWidgets('載入失敗時顯示錯誤', (tester) async {
      installMockClient({
        '/api/events/notifications':
            errorResponse('SERVER_ERROR', status: 500, message: '伺服器忙碌中'),
      });

      await tester.pumpWidget(
        const MaterialApp(home: EventNotificationsScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('伺服器忙碌中'), findsWidgets);
    });
  });
}
