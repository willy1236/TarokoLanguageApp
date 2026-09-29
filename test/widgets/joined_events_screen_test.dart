// 我參加的活動：兩個分頁、往下捲分頁到 has_more 為 false 為止、自己發起的標示。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/screens/events/joined_events_screen.dart';
import 'package:flutter_application_1/services/fcm_service.dart';
import 'package:flutter_application_1/shared/widgets/async_state_view.dart';

import '../helpers/flow_test_helpers.dart';
import '../helpers/widget_test_helpers.dart';

Map<String, dynamic> _event(
  int id, {
  String status = 'active',
  bool isHost = false,
}) => {
  'id': id,
  'title': '活動 $id',
  'starts_at': '2026-12-01T10:00:00Z',
  'status': status == 'cancelled' ? 'cancelled' : 'active',
  'effective_status': status,
  'participant_count': 3,
  'is_host': isHost,
  'joined_at': '2026-11-01T00:00:00Z',
  'is_joined': true,
};

/// 兩頁的假分頁：第 1 頁 20 筆、游標 '2' 取第 2 頁 5 筆後到底。
/// 第 2 頁多帶一筆第 1 頁已有的活動 20，模擬翻頁期間有新活動插入。
Map<String, dynamic> _page(String page) => page == '1'
    ? {
        'events': [for (var i = 1; i <= 20; i++) _event(i)],
        'page_info': {'next_cursor': '2', 'has_more': true},
      }
    : {
        'events': [for (var i = 20; i <= 25; i++) _event(i)],
        'page_info': {'next_cursor': null, 'has_more': false},
      };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(stubCommonChannels);
  tearDown(restoreHttp);

  Widget app() => const MaterialApp(home: JoinedEventsScreen());

  testWidgets('進行中分頁：狀態標籤、自己發起的標示', (tester) async {
    installMockClient({
      '/api/events/joined': {
        'total': 2,
        'events': [_event(1), _event(2, status: 'ongoing', isHost: true)],
      },
    });

    await tester.pumpWidget(app());
    await pumpFrames(tester);

    expect(find.text('即將開始'), findsOneWidget);
    expect(find.text('進行中'), findsWidgets); // 分頁標題＋狀態標籤
    expect(find.text('我發起的'), findsOneWidget); // 只有 is_host 那筆
  });

  testWidgets('超過 20 筆往下捲帶游標載入下一頁，has_more 為 false 後不再請求', (tester) async {
    final pages = <String?>[];
    // installMockClient 依 path 固定回應，分頁要依 cursor 參數回不同內容，直接換 MockClient。
    ApiClient.httpClient = MockClient((r) async {
      final page = r.url.queryParameters['cursor'] ?? '1';
      pages.add(page);
      return jsonResponse(_page(page));
    });

    await tester.pumpWidget(app());
    await pumpFrames(tester);
    expect(pages, ['1']);

    await tester.fling(
      find.byType(ListView).first,
      const Offset(0, -3000),
      3000,
    );
    await pumpFrames(tester, times: 10);
    await tester.fling(
      find.byType(ListView).first,
      const Offset(0, -3000),
      3000,
    );
    await pumpFrames(tester, times: 10);

    expect(pages, ['1', '2']);
    expect(find.text('活動 25', skipOffstage: false), findsOneWidget);
    // 第 2 頁重複的活動 20 只出現一次。
    expect(find.text('活動 20', skipOffstage: false), findsOneWidget);
  });

  testWidgets('載入下一頁途中下拉重新整理，之後仍能載入下一頁', (tester) async {
    final pages = <String?>[];
    var slowPage2 = true;
    ApiClient.httpClient = MockClient((r) async {
      final page = r.url.queryParameters['cursor'] ?? '1';
      pages.add(page);
      if (page == '2' && slowPage2) {
        slowPage2 = false;
        await Future<void>.delayed(const Duration(seconds: 3));
      }
      return jsonResponse(_page(page));
    });

    await tester.pumpWidget(app());
    await pumpFrames(tester);
    await tester.fling(
      find.byType(ListView).first,
      const Offset(0, -3000),
      3000,
    );
    await pumpFrames(tester, times: 10);
    expect(pages, ['1', '2']); // 第 2 頁還在路上

    // 整頁重載（下拉重新整理或從詳情頁返回都走這裡），讓慢的第 2 頁被丟棄。
    final state = tester.state(find.byType(RefreshIndicator).first);
    unawaited((state as RefreshIndicatorState).show());
    await tester.pump(const Duration(seconds: 4));
    await pumpFrames(tester, times: 10);

    await tester.fling(
      find.byType(ListView).first,
      const Offset(0, -3000),
      3000,
    );
    await pumpFrames(tester, times: 10);
    expect(pages, ['1', '2', '1', '2']);
    expect(find.text('活動 25', skipOffstage: false), findsOneWidget);
  });

  testWidgets('第 1 頁填不滿畫面時，不用捲動就載入下一頁', (tester) async {
    final pages = <String?>[];
    ApiClient.httpClient = MockClient((r) async {
      final page = r.url.queryParameters['cursor'] ?? '1';
      pages.add(page);
      return jsonResponse(_page(page));
    });

    // 畫面夠高，20 筆全部放得下，不會有捲動事件。
    usePhoneSurface(tester, size: const Size(414, 4000));
    await tester.pumpWidget(app());
    await pumpFrames(tester, times: 10);

    expect(pages, ['1', '2']);
    expect(find.text('活動 25'), findsOneWidget);
  });

  testWidgets('載入下一頁失敗：底部顯示重試，點了才重新載入', (tester) async {
    final pages = <String?>[];
    var failPage2 = true;
    ApiClient.httpClient = MockClient((r) async {
      final page = r.url.queryParameters['cursor'] ?? '1';
      pages.add(page);
      if (page == '2' && failPage2) {
        failPage2 = false;
        return errorResponse('X', status: 500, message: '壞了');
      }
      return jsonResponse(_page(page));
    });

    await tester.pumpWidget(app());
    await pumpFrames(tester);
    await tester.fling(
      find.byType(ListView).first,
      const Offset(0, -3000),
      3000,
    );
    await pumpFrames(tester, times: 10);
    expect(pages, ['1', '2']);

    // 失敗後再捲也不會自動重打，避免一直失敗一直打。
    await tester.fling(
      find.byType(ListView).first,
      const Offset(0, -3000),
      3000,
    );
    await pumpFrames(tester, times: 10);
    expect(pages, ['1', '2']);

    await tester.tap(find.text('載入失敗，點此重試'));
    await pumpFrames(tester, times: 10);
    expect(pages, ['1', '2', '2']);
    expect(find.text('活動 25', skipOffstage: false), findsOneWidget);
    expect(find.text('載入失敗，點此重試'), findsNothing);
  });

  testWidgets('從詳情頁返回、沒有變動：不重載，停在原本的位置', (tester) async {
    final pages = <String?>[];
    ApiClient.httpClient = MockClient((r) async {
      final path = r.url.path;
      if (path == '/api/events/joined') {
        final page = r.url.queryParameters['cursor'] ?? '1';
        pages.add(page);
        return jsonResponse(_page(page));
      }
      if (path == '/api/events/25') {
        return jsonResponse({
          ..._event(25),
          'host_uid': 100,
          'description': '說明',
          'registration_open': true,
          'like_count': 0,
        });
      }
      if (path == '/api/events/25/reminders') {
        return jsonResponse({'reminders': <dynamic>[]});
      }
      if (path == '/api/me') {
        return jsonResponse({'uid': 1, 'created_at': '2026-01-01T00:00:00Z'});
      }
      if (path == '/api/shop/items') {
        return jsonResponse({'items': <dynamic>[]});
      }
      fail('沒有準備 $path');
    });

    await tester.pumpWidget(app());
    await pumpFrames(tester);
    await tester.fling(
      find.byType(ListView).first,
      const Offset(0, -3000),
      3000,
    );
    await pumpFrames(tester, times: 10);
    expect(pages, ['1', '2']);

    await tester.tap(find.text('活動 25'));
    await pumpFrames(tester, times: 10);
    await tester.binding.handlePopRoute();
    await pumpFrames(tester, times: 10);

    expect(pages, ['1', '2']);
    expect(find.text('活動 25'), findsOneWidget);
  });

  testWidgets('結束分頁載入失敗顯示錯誤狀態', (tester) async {
    installMockClient({
      '/api/events/joined': errorResponse('X', status: 500, message: '壞了'),
    });

    await tester.pumpWidget(app());
    await pumpFrames(tester);
    await tester.tap(find.text('結束'));
    await pumpFrames(tester, times: 10);

    expect(find.byType(TrukuErrorView), findsOneWidget);
  });

  testWidgets('前景收到活動被刪除的推播：兩個分頁自動重新整理，該活動消失', (tester) async {
    var deleted = false;
    final tabsRequested = <String?>[];
    ApiClient.httpClient = MockClient((r) async {
      tabsRequested.add(r.url.queryParameters['tab']);
      return jsonResponse({
        'total': 2,
        'events': [_event(1), if (!deleted) _event(2)],
      });
    });

    await tester.pumpWidget(app());
    await pumpFrames(tester);
    expect(find.text('活動 2'), findsOneWidget);
    expect(tabsRequested, ['active']);

    deleted = true;
    FcmService.dispatchEventDeleted(2);
    await pumpFrames(tester, times: 10);

    expect(find.text('活動 2'), findsNothing);
    expect(find.text('活動 1'), findsOneWidget);
    // 分頁保持存活，「結束」分頁也一併重載。
    expect(tabsRequested, ['active', 'active']);
  });

  testWidgets('離開畫面後不再回應刪除推播', (tester) async {
    var requests = 0;
    ApiClient.httpClient = MockClient((r) async {
      requests++;
      return jsonResponse({'total': 0, 'events': <dynamic>[]});
    });
    await tester.pumpWidget(app());
    await pumpFrames(tester);
    expect(requests, 1);

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    FcmService.dispatchEventDeleted(2);
    await pumpFrames(tester);

    expect(requests, 1);
  });
}
