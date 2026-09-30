// MyEventsScreen（我發起的活動）的畫面層測試。
//
// 這兩頁人工測起來特別囉唆：要先有「我發起過的活動」和「別人發給我的提醒」
// 才看得到非空狀態，而且取消／結束狀態的標籤要湊齊三種活動才驗得完。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

import 'package:flutter_application_1/core/network/api_client.dart';

import 'package:flutter_application_1/screens/events/my_events_screen.dart';
import 'package:flutter_application_1/shared/widgets/async_state_view.dart';

import '../helpers/flow_test_helpers.dart';
import '../helpers/widget_test_helpers.dart';

Map<String, dynamic> _event({
  required int id,
  required String title,
  String effectiveStatus = 'active',
}) => {
  'id': id,
  'title': title,
  'starts_at': '2026-12-01T10:00:00Z',
  'status': effectiveStatus == 'cancelled' ? 'cancelled' : 'active',
  'effective_status': effectiveStatus,
  'participant_count': 3,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(stubCommonChannels);
  tearDown(restoreHttp);

  group('MyEventsScreen', () {
    testWidgets('顯示我發起的活動與四種狀態標籤', (tester) async {
      installMockClient({
        '/api/events/mine': {
          'events': [
            _event(id: 1, title: '即將舉行的活動'),
            _event(id: 4, title: '進行中的活動', effectiveStatus: 'ongoing'),
            _event(id: 2, title: '結束的活動', effectiveStatus: 'ended'),
            _event(id: 3, title: '取消的活動', effectiveStatus: 'cancelled'),
          ],
        },
      });

      await tester.pumpWidget(const MaterialApp(home: MyEventsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('進行中的活動'), findsOneWidget);
      expect(find.text('即將舉行'), findsOneWidget);
      expect(find.text('進行中'), findsOneWidget);
      expect(find.text('已結束'), findsOneWidget);
      expect(find.text('已取消'), findsOneWidget);
    });

    testWidgets('載入失敗時顯示錯誤並可重試', (tester) async {
      var calls = 0;
      installMockClient({
        '/api/events/mine': errorResponse('SERVER_ERROR', status: 500),
      }, onRequest: (_) => calls++);

      await tester.pumpWidget(const MaterialApp(home: MyEventsScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(TrukuErrorView), findsOneWidget);

      await tester.tap(find.text('重試'));
      await tester.pumpAndSettle();

      expect(calls, 2);
    });
  });

  group('MyEventsScreen 往下捲分頁', () {
    /// 第 1 頁 20 場、游標 '20' 取第 2 頁 5 場後到底。
    Map<String, dynamic> page(String? cursor) => cursor == null
        ? {
            'events': [
              for (var i = 1; i <= 20; i++) _event(id: i, title: '活動 $i'),
            ],
            'page_info': {'next_cursor': '20', 'has_more': true},
          }
        : {
            'events': [
              for (var i = 21; i <= 25; i++) _event(id: i, title: '活動 $i'),
            ],
            'page_info': {'next_cursor': null, 'has_more': false},
          };

    Future<void> scrollToBottom(WidgetTester tester) async {
      await tester.fling(find.byType(ListView), const Offset(0, -5000), 3000);
      await pumpFrames(tester, times: 10);
    }

    testWidgets('超過 20 場時往下捲載入下一頁，到底後不再請求', (tester) async {
      final cursors = <String?>[];
      ApiClient.httpClient = MockClient((r) async {
        final cursor = r.url.queryParameters['cursor'];
        cursors.add(cursor);
        return jsonResponse(page(cursor));
      });

      await tester.pumpWidget(const MaterialApp(home: MyEventsScreen()));
      await pumpFrames(tester);
      await scrollToBottom(tester);
      await scrollToBottom(tester);

      expect(cursors, [null, '20']);
      expect(find.text('活動 25'), findsOneWidget);
    });

    testWidgets('載入下一頁失敗：底部顯示重試，點了才重新載入', (tester) async {
      final cursors = <String?>[];
      var failNext = true;
      ApiClient.httpClient = MockClient((r) async {
        final cursor = r.url.queryParameters['cursor'];
        cursors.add(cursor);
        if (cursor != null && failNext) {
          failNext = false;
          return errorResponse('X', status: 500, message: '壞了');
        }
        return jsonResponse(page(cursor));
      });

      await tester.pumpWidget(const MaterialApp(home: MyEventsScreen()));
      await pumpFrames(tester);
      await scrollToBottom(tester);
      expect(cursors, [null, '20']);

      await scrollToBottom(tester);
      expect(cursors, [null, '20']);

      await tester.tap(find.text('載入失敗，點此重試'));
      await pumpFrames(tester, times: 10);
      expect(cursors, [null, '20', '20']);
      expect(find.text('活動 25', skipOffstage: false), findsOneWidget);
    });
  });
}
