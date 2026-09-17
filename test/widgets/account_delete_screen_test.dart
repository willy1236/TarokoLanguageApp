// AccountDeleteScreen / AccountDeletedScreen 的畫面層測試。
//
// 這支取代的人工測試：確認頁的四項說明有沒有齊、沒勾同意時按鈕是不是真的按不下去、
// 送出後成功頁有沒有顯示永久刪除日期。
// 人工要測這些必須真的刪掉一個帳號，等 45 天才能再測一次，所以特別值得自動化。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/screens/account/account_delete_screen.dart';
import 'package:flutter_application_1/services/user_service.dart';

import '../helpers/widget_test_helpers.dart';

Widget _app(Widget screen) => MaterialApp(
      home: screen,
      routes: {'/login': (_) => const Scaffold(body: Text('LOGIN'))},
    );

/// 取確認頁底部那顆送出鈕。
/// AppBar 標題同樣是「刪除帳號」，所以要限定在 ElevatedButton 底下找。
ElevatedButton _submitButton(WidgetTester tester) => tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, '刪除帳號'),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    stubCommonChannels();
    UserService.clearCache();
  });

  tearDown(() {
    restoreHttp();
    UserService.clearCache();
  });

  testWidgets('確認頁列出四項不可逆後果', (tester) async {
    await tester.pumpWidget(_app(const AccountDeleteScreen()));

    expect(find.text('45 天內可以反悔'), findsOneWidget);
    expect(find.text('45 天後永久刪除'), findsOneWidget);
    expect(find.text('活動會立即取消，重新啟用也不會恢復'), findsOneWidget);
    expect(find.text('到期提醒不一定收得到'), findsOneWidget);
  });

  testWidgets('未勾選同意時送出鈕停用，勾選後才啟用', (tester) async {
    await tester.pumpWidget(_app(const AccountDeleteScreen()));

    expect(_submitButton(tester).onPressed, isNull);

    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();

    expect(_submitButton(tester).onPressed, isNotNull);
  });

  testWidgets('送出後導向成功頁並顯示永久刪除日期', (tester) async {
    Map<String, String>? sentBody;
    installMockClient(
      {
        '/api/account': {
          'status': 'pending_deletion',
          'purge_at': '2026-11-01T00:00:00Z',
        },
      },
      onRequest: (req) {
        if (req.url.path == '/api/account') {
          sentBody = {'body': req.body};
        }
      },
    );

    await tester.pumpWidget(_app(const AccountDeleteScreen()));
    await tester.enterText(find.byType(TextField), '不想用了');
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, '刪除帳號'));
    await tester.pumpAndSettle();

    expect(find.text('已申請刪除帳號'), findsOneWidget);
    expect(find.text('永久刪除日期'), findsOneWidget);
    expect(find.text('2026 年 11 月 1 日'), findsOneWidget);
    // 離開原因要真的送出去，否則這個欄位只是裝飾。
    expect(sentBody?['body'], contains('不想用了'));
  });

  testWidgets('後端拒絕時留在確認頁並顯示錯誤，按鈕恢復可按', (tester) async {
    installMockClient({
      '/api/account': errorResponse(
        'RATE_LIMITED',
        status: 429,
        message: '操作太頻繁，請稍後再試',
      ),
    });

    await tester.pumpWidget(_app(const AccountDeleteScreen()));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, '刪除帳號'));
    await tester.pumpAndSettle();

    expect(find.text('已申請刪除帳號'), findsNothing);
    expect(find.text('操作太頻繁，請稍後再試'), findsOneWidget);
    expect(_submitButton(tester).onPressed, isNotNull);
  });

  testWidgets('成功頁沒有 purge_at 時不顯示日期區塊（後端沒回也不能崩）', (tester) async {
    await tester.pumpWidget(_app(const AccountDeletedScreen()));

    expect(find.text('已申請刪除帳號'), findsOneWidget);
    expect(find.text('永久刪除日期'), findsNothing);
  });

  testWidgets('成功頁「我知道了」回登入頁', (tester) async {
    await tester.pumpWidget(_app(
      AccountDeletedScreen(purgeAt: DateTime(2026, 11, 1)),
    ));

    await tester.tap(find.text('我知道了'));
    await tester.pumpAndSettle();

    expect(find.text('LOGIN'), findsOneWidget);
  });
}
