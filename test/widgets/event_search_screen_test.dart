// EventSearchScreen（活動搜尋）的畫面層測試。
//
// 這支取代的人工測試：打關鍵字搜尋、切時間區間、捲到底看有沒有續載、
// 找不到時有沒有空狀態。其中「快速切換篩選時舊回應不能覆蓋新結果」
// 人工幾乎測不出來（要剛好卡在兩個請求交錯的時機），但真的會讓使用者看到錯的清單。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

import 'package:flutter_application_1/core/network/api_client.dart';

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
      delayFor: (req) =>
          req.url.path == '/api/events/search' && searchCalls == 1
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

  testWidgets('捲到底帶上一頁的游標載入下一頁，重複的活動只出現一次，到底後不再請求', (tester) async {
    final cursors = <String?>[];
    ApiClient.httpClient = MockClient((r) async {
      if (r.url.path != '/api/events/search') {
        return jsonResponse({'history': <dynamic>[], 'popular': <dynamic>[]});
      }
      final cursor = r.url.queryParameters['cursor'];
      cursors.add(cursor);
      return jsonResponse(
        cursor == null
            ? {
                'events': [
                  for (var i = 1; i <= 20; i++) _event(id: i, title: '活動$i'),
                ],
                'page_info': {'next_cursor': '20', 'has_more': true},
              }
            : {
                'events': [
                  for (var i = 20; i <= 22; i++) _event(id: i, title: '活動$i'),
                ],
                'page_info': {'next_cursor': null, 'has_more': false},
              },
      );
    });

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await _searchFor(tester, '祭');
    for (var i = 0; i < 3; i++) {
      await tester.fling(
        find.byType(ListView).last,
        const Offset(0, -5000),
        3000,
      );
      for (var f = 0; f < 10; f++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    expect(cursors, [null, '20']);
    expect(find.text('活動22'), findsOneWidget);
    expect(find.text('活動20', skipOffstage: false), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
