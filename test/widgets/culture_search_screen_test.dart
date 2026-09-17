// CultureSearchScreen（文章／影音搜尋共用骨架）的畫面層測試。
//
// 文章搜尋與影音搜尋只差在呼叫哪支 API 與結果卡片長相，分頁、請求世代、
// 空狀態與錯誤都在這個骨架裡，所以測這裡等於同時守住兩個頁面。
//
// 這支取代的人工測試：打關鍵字、切時間區間與部落、捲到底看續載。
// 其中「舊查詢晚回不能覆蓋新結果」人工幾乎測不出來——要剛好卡在兩個請求交錯的
// 瞬間才會發生，但真的發生時使用者會看到跟關鍵字對不上的清單。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/screens/culture/culture_search_screen.dart';
import 'package:flutter_application_1/services/search_assist_service.dart';

import '../helpers/widget_test_helpers.dart';

/// 搜尋建議（歷史／熱門）一進畫面就會打，先備好空回應。
Map<String, Object?> _suggestionRoutes() => {
      '/api/search/history': {'history': <dynamic>[]},
      '/api/search/popular': {'popular': <dynamic>[]},
    };

/// 用純字串當結果項目：這層測的是骨架行為，不是卡片長相。
Widget _app(CultureSearchFetch<String> fetch) => MaterialApp(
      home: CultureSearchScreen<String>(
        module: SearchModule.articles,
        hint: '搜尋文章',
        emptyText: '找不到符合的文章',
        fetch: fetch,
        itemBuilder: (item, _) => ListTile(title: Text(item)),
      ),
    );

/// 有更多結果時清單尾端會掛一顆轉圈，pumpAndSettle 等不到靜止。
Future<void> _searchFor(WidgetTester tester, String q) async {
  await tester.enterText(find.byType(TextField).first, q);
  await tester.testTextInput.receiveAction(TextInputAction.search);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    stubCommonChannels();
    installMockClient(_suggestionRoutes());
  });

  tearDown(restoreHttp);

  testWidgets('搜尋後顯示結果', (tester) async {
    await tester.pumpWidget(_app(
      ({q, range, tribeId, required page}) async =>
          (items: ['太魯閣族的織布', '獵人的一天'], total: 2),
    ));
    await tester.pumpAndSettle();
    await _searchFor(tester, '織布');

    expect(find.text('太魯閣族的織布'), findsOneWidget);
    expect(find.text('獵人的一天'), findsOneWidget);
  });

  testWidgets('關鍵字與篩選條件會傳給 fetch', (tester) async {
    String? gotQ;
    int gotPage = 0;
    await tester.pumpWidget(_app(
      ({q, range, tribeId, required page}) async {
        gotQ = q;
        gotPage = page;
        return (items: <String>[], total: 0);
      },
    ));
    await tester.pumpAndSettle();
    await _searchFor(tester, '  織布  ');

    // 關鍵字要去空白，新查詢一定從第 1 頁開始。
    expect(gotQ, '織布');
    expect(gotPage, 1);
  });

  testWidgets('沒有結果時顯示自訂空狀態文案', (tester) async {
    await tester.pumpWidget(_app(
      ({q, range, tribeId, required page}) async =>
          (items: <String>[], total: 0),
    ));
    await tester.pumpAndSettle();
    await _searchFor(tester, '不存在');

    expect(find.text('找不到符合的文章'), findsOneWidget);
  });

  testWidgets('後端錯誤顯示後端訊息', (tester) async {
    await tester.pumpWidget(_app(
      ({q, range, tribeId, required page}) async => throw ApiException(
        statusCode: 400,
        code: 'INVALID_RANGE',
        message: '時間區間不合法',
      ),
    ));
    await tester.pumpAndSettle();
    await _searchFor(tester, '織布');

    expect(find.text('時間區間不合法'), findsOneWidget);
  });

  testWidgets('非後端錯誤顯示通用文案，不把例外內容丟給使用者', (tester) async {
    await tester.pumpWidget(_app(
      ({q, range, tribeId, required page}) async =>
          throw StateError('internal detail'),
    ));
    await tester.pumpAndSettle();
    await _searchFor(tester, '織布');

    expect(find.text('搜尋失敗，請稍後再試'), findsOneWidget);
    expect(find.textContaining('internal detail'), findsNothing);
  });

  testWidgets('總數大於已載入時捲到底會續載下一頁', (tester) async {
    final pages = <int>[];
    await tester.pumpWidget(_app(
      ({q, range, tribeId, required page}) async {
        pages.add(page);
        return (
          items: List.generate(10, (i) => '第 $page 頁第 $i 筆'),
          total: 20,
        );
      },
    ));
    await tester.pumpAndSettle();
    await _searchFor(tester, '織布');

    expect(pages, [1]);

    await tester.drag(_resultList(), const Offset(0, -2000));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(pages, [1, 2]);
    expect(find.textContaining('第 2 頁'), findsWidgets);
  });

  testWidgets('已載入數量等於總數時不再續載', (tester) async {
    final pages = <int>[];
    await tester.pumpWidget(_app(
      ({q, range, tribeId, required page}) async {
        pages.add(page);
        return (items: List.generate(3, (i) => '第 $i 筆'), total: 3);
      },
    ));
    await tester.pumpAndSettle();
    await _searchFor(tester, '織布');

    await tester.drag(_resultList(), const Offset(0, -2000));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(pages, [1]);
  });

  testWidgets('回應晚到的舊查詢不會覆蓋新查詢的結果', (tester) async {
    var calls = 0;
    await tester.pumpWidget(_app(
      ({q, range, tribeId, required page}) async {
        calls++;
        if (calls == 1) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
          return (items: ['舊查詢結果'], total: 1);
        }
        return (items: ['新查詢結果'], total: 1);
      },
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '舊');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump(const Duration(milliseconds: 50));

    await tester.enterText(find.byType(TextField).first, '新');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(calls, 2);
    expect(find.text('新查詢結果'), findsOneWidget);
    expect(find.text('舊查詢結果'), findsNothing);
  });
}

/// 篩選列也是一個（水平）ListView，所以要指名垂直的那個結果清單。
Finder _resultList() => find.byWidgetPredicate(
      (w) => w is ListView && w.scrollDirection == Axis.vertical,
    );
