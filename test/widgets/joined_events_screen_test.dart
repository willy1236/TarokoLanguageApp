// 我參加的活動：兩個分頁、往下捲分頁到 total 為止、自己發起的標示。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/screens/events/joined_events_screen.dart';
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

  testWidgets('超過 20 筆往下捲載入下一頁，到 total 為止不再請求', (tester) async {
    final pages = <String?>[];
    // installMockClient 依 path 固定回應，分頁要依 page 參數回不同內容，直接換 MockClient。
    ApiClient.httpClient = MockClient((r) async {
      final page = r.url.queryParameters['page'];
      pages.add(page);
      return jsonResponse({
        'total': 25,
        'events': page == '1'
            ? [for (var i = 1; i <= 20; i++) _event(i)]
            : [for (var i = 21; i <= 25; i++) _event(i)],
      });
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
  });

  testWidgets('載入下一頁途中下拉重新整理，之後仍能載入下一頁', (tester) async {
    final pages = <String?>[];
    var slowPage2 = true;
    ApiClient.httpClient = MockClient((r) async {
      final page = r.url.queryParameters['page'];
      pages.add(page);
      if (page == '2' && slowPage2) {
        slowPage2 = false;
        await Future<void>.delayed(const Duration(seconds: 3));
      }
      return jsonResponse({
        'total': 25,
        'events': page == '1'
            ? [for (var i = 1; i <= 20; i++) _event(i)]
            : [for (var i = 21; i <= 25; i++) _event(i)],
      });
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
      final page = r.url.queryParameters['page'];
      pages.add(page);
      return jsonResponse({
        'total': 25,
        'events': page == '1'
            ? [for (var i = 1; i <= 20; i++) _event(i)]
            : [for (var i = 21; i <= 25; i++) _event(i)],
      });
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
      final page = r.url.queryParameters['page'];
      pages.add(page);
      if (page == '2' && failPage2) {
        failPage2 = false;
        return errorResponse('X', status: 500, message: '壞了');
      }
      return jsonResponse({
        'total': 25,
        'events': page == '1'
            ? [for (var i = 1; i <= 20; i++) _event(i)]
            : [for (var i = 21; i <= 25; i++) _event(i)],
      });
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
}
