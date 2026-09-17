// EventSearchScreen（活動搜尋）的畫面層測試。
//
// 這支取代的人工測試：打關鍵字搜尋、切時間區間、捲到底看有沒有續載、
// 找不到時有沒有空狀態。其中「快速切換篩選時舊回應不能覆蓋新結果」
// 人工幾乎測不出來（要剛好卡在兩個請求交錯的時機），但真的會讓使用者看到錯的清單。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/screens/events/event_search_screen.dart';

import '../helpers/widget_test_helpers.dart';

Map<String, dynamic> _event({required int id, required String title}) => {
      'id': id,
      'title': title,
      'starts_at': '2026-12-01T10:00:00Z',
      'status': 'active',
      'effective_status': 'active',
      'registration_open': true,
    };

/// 搜尋頁一進來會先打搜尋建議（歷史／熱門），先備好空回應。
Map<String, Object?> _suggestionRoutes() => {
      '/api/search/history': {'history': <dynamic>[]},
      '/api/search/popular': {'popular': <dynamic>[]},
    };

Widget _app() => const MaterialApp(home: EventSearchScreen());

/// 有結果時清單尾端會掛一顆「載入更多」的轉圈，pumpAndSettle 永遠等不到靜止，
/// 所以這裡推固定幾幀就好。
Future<void> _searchFor(WidgetTester tester, String q) async {
  await tester.enterText(find.byType(TextField).first, q);
  await tester.testTextInput.receiveAction(TextInputAction.search);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(stubCommonChannels);
  tearDown(restoreHttp);

  testWidgets('還沒搜尋前顯示建議區，不顯示結果清單', (tester) async {
    installMockClient(_suggestionRoutes());

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('找不到符合的活動'), findsNothing);
  });

  testWidgets('搜尋後顯示結果', (tester) async {
    installMockClient({
      ..._suggestionRoutes(),
      '/api/events/search': {
        'events': [_event(id: 1, title: '族語共學')],
      },
    });

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await _searchFor(tester, '族語');

    expect(find.text('族語共學'), findsWidgets);
  });

  testWidgets('搜尋關鍵字會送進 query', (tester) async {
    String? sentQ;
    installMockClient(
      {
        ..._suggestionRoutes(),
        '/api/events/search': {'events': <dynamic>[]},
      },
      onRequest: (req) {
        if (req.url.path == '/api/events/search') {
          sentQ = req.url.queryParameters['q'];
        }
      },
    );

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await _searchFor(tester, '豐年祭');

    expect(sentQ, '豐年祭');
  });

  testWidgets('沒有結果時顯示找不到', (tester) async {
    installMockClient({
      ..._suggestionRoutes(),
      '/api/events/search': {'events': <dynamic>[]},
    });

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await _searchFor(tester, '不存在的活動');

    expect(find.text('找不到符合的活動'), findsOneWidget);
  });

  testWidgets('搜尋失敗時顯示錯誤訊息', (tester) async {
    installMockClient({
      ..._suggestionRoutes(),
      '/api/events/search': errorResponse('SERVER_ERROR', status: 500),
    });

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await _searchFor(tester, '族語');

    expect(find.textContaining('SERVER_ERROR'), findsOneWidget);
  });

  testWidgets('回應晚到的舊查詢不會覆蓋新查詢的結果', (tester) async {
    // 第一次搜尋刻意延遲 500ms，期間再送第二次（立即回應）。
    // 舊回應晚到時必須被 _reqGen 擋掉，否則使用者會看到跟關鍵字對不上的清單。
    var searchCalls = 0;
    final routes = <String, Object?>{
      ..._suggestionRoutes(),
      '/api/events/search': {
        'events': [_event(id: 1, title: '舊查詢結果')],
      },
    };

    installMockClient(
      routes,
      onRequest: (req) {
        if (req.url.path != '/api/events/search') return;
        searchCalls++;
        if (searchCalls == 1) {
          // 第一次的回應還在路上時，就把第二次要回的內容換掉。
          routes['/api/events/search'] = {
            'events': [_event(id: 2, title: '新查詢結果')],
          };
        }
      },
      // onRequest 先跑，所以第一次進到這裡時 searchCalls 已經是 1。
      delayFor: (req) => req.url.path == '/api/events/search' && searchCalls == 1
          ? const Duration(milliseconds: 500)
          : Duration.zero,
    );

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '舊');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump(const Duration(milliseconds: 50));

    await tester.enterText(find.byType(TextField).first, '新');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    // 推過第一次請求的 500ms 延遲，讓晚到的舊回應有機會（錯誤地）蓋掉新結果。
    await tester.pump(const Duration(seconds: 1));

    expect(searchCalls, 2);
    expect(find.text('新查詢結果'), findsWidgets);
    expect(find.text('舊查詢結果'), findsNothing);
  });
}
