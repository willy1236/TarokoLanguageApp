// 禁言、髒話詞庫、題目回報三個後台畫面。

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/main.dart' show scaffoldMessengerKey;
import 'package:flutter_application_1/screens/admin/admin_banned_words_screen.dart';
import 'package:flutter_application_1/screens/admin/admin_mutes_screen.dart';
import 'package:flutter_application_1/screens/admin/admin_question_reports_screen.dart';

import '../../helpers/fixtures.dart';
import '../../helpers/widget_test_helpers.dart';

Widget _app(Widget home) =>
    MaterialApp(scaffoldMessengerKey: scaffoldMessengerKey, home: home);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(stubCommonChannels);
  tearDown(restoreHttp);

  group('禁言', () {
    testWidgets('列出對象、範圍、來源；解除前二次確認，成功後重抓', (tester) async {
      final mutes = loadSpecFixtureMap('get_api_admin_mutes.json');
      var lifted = false;
      final requests = <String>[];
      ApiClient.httpClient = MockClient((r) async {
        requests.add('${r.method} ${r.url.path}');
        if (r.method == 'POST') {
          lifted = true;
          return jsonResponse({'ok': true, 'id': 31, 'uid': 6});
        }
        return jsonResponse(
          lifted ? {'mutes': (mutes['mutes'] as List).skip(1).toList()} : mutes,
        );
      });

      await tester.pumpWidget(_app(const AdminMutesScreen()));
      await tester.pumpAndSettle();
      expect(find.text('被禁言者'), findsOneWidget);
      expect(
        find.textContaining('FFFF2345', findRichText: true),
        findsOneWidget,
      );
      expect(find.textContaining('檢舉滿門檻', findRichText: true), findsOneWidget);
      expect(find.text('文字類'), findsOneWidget);

      await tester.tap(find.text('解除').first);
      await tester.pumpAndSettle();
      expect(find.text('解除禁言？'), findsOneWidget);
      await tester.tap(find.text('解除').last);
      await tester.pumpAndSettle();

      expect(requests, contains('POST /api/admin/mutes/31/lift'));
      expect(find.text('被禁言者'), findsNothing, reason: '解除後從列表移除');
      expect(find.text('另一位'), findsOneWidget);
    });

    testWidgets('404（已被別人解除）：顯示後端訊息並重抓', (tester) async {
      var gets = 0;
      ApiClient.httpClient = MockClient((r) async {
        if (r.method == 'POST') {
          return errorResponse('NOT_FOUND', status: 404, message: '禁言不存在或已解除');
        }
        gets++;
        return jsonResponse(loadSpecFixtureMap('get_api_admin_mutes.json'));
      });

      await tester.pumpWidget(_app(const AdminMutesScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('解除').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('解除').last);
      await tester.pumpAndSettle();

      expect(find.text('禁言不存在或已解除'), findsOneWidget);
      expect(gets, 2);
    });
  });

  testWidgets('禁言：解除送出中只停用那一筆，連點只送一次；失敗後恢復', (tester) async {
    final gate = Completer<http.Response>();
    var posts = 0;
    ApiClient.httpClient = MockClient((r) async {
      if (r.method == 'POST') {
        posts++;
        return gate.future;
      }
      return jsonResponse(loadSpecFixtureMap('get_api_admin_mutes.json'));
    });
    await tester.pumpWidget(_app(const AdminMutesScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('解除').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('解除').last);
    await tester.pumpAndSettle();

    List<TextButton> buttons() => tester
        .widgetList<TextButton>(find.widgetWithText(TextButton, '解除'))
        .toList();
    expect(buttons()[0].onPressed, isNull);
    expect(buttons()[1].onPressed, isNotNull, reason: '其他筆不受影響');
    await tester.tap(find.text('解除').first, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('解除禁言？'), findsNothing);

    gate.complete(errorResponse('INTERNAL', status: 500));
    await tester.pumpAndSettle();
    expect(posts, 1);
    expect(buttons()[0].onPressed, isNotNull);
  });

  group('髒話詞庫', () {
    Future<void> pumpWords(
      WidgetTester tester, {
      Object? addResponse,
      void Function(http.Request)? onRequest,
    }) async {
      var words =
          (loadSpecFixtureMap('get_api_admin_banned_words.json')['words']
                  as List)
              .toList();
      ApiClient.httpClient = MockClient((r) async {
        onRequest?.call(r);
        if (r.method == 'POST') {
          final created = (addResponse as Map)['created'] == true;
          if (created) {
            words = [
              ...words,
              {'id': 9, 'word': jsonDecode(r.body)['word']},
            ];
          }
          return jsonResponse(addResponse, status: 201);
        }
        if (r.method == 'DELETE') {
          words = words
              .where((w) => '/api/admin/banned-words/${w['id']}' != r.url.path)
              .toList();
          return jsonResponse({'ok': true});
        }
        return jsonResponse({'words': words});
      });
      await tester.pumpWidget(_app(const AdminBannedWordsScreen()));
      await tester.pumpAndSettle();
    }

    testWidgets('搜尋在前端過濾', (tester) async {
      await pumpWords(tester);
      expect(find.text('測試詞甲'), findsOneWidget);
      expect(find.text('abc'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, '搜尋詞庫'), '詞甲');
      await tester.pump();

      expect(find.text('測試詞甲'), findsOneWidget);
      expect(find.text('測試詞乙'), findsNothing);
      expect(find.text('abc'), findsNothing);
    });

    testWidgets('新增：成功後出現在列表；重複新增不報錯、提示已有', (tester) async {
      final bodies = <String>[];
      await pumpWords(
        tester,
        addResponse: {'ok': true, 'word': '新詞', 'created': true},
        onRequest: (r) {
          if (r.method == 'POST') bodies.add(r.body);
        },
      );

      await tester.enterText(find.widgetWithText(TextField, '新增詞'), ' 新詞 ');
      await tester.tap(find.byTooltip('新增'));
      await tester.pumpAndSettle();
      expect(bodies.single, '{"word":"新詞"}');
      expect(find.text('新詞'), findsOneWidget);
      expect(find.text('已新增'), findsOneWidget);

      await pumpWords(
        tester,
        addResponse: {'ok': true, 'word': '測試詞甲', 'created': false},
      );
      await tester.enterText(find.widgetWithText(TextField, '新增詞'), '測試詞甲');
      await tester.tap(find.byTooltip('新增'));
      await tester.pumpAndSettle();
      expect(find.text('詞庫已有這個詞'), findsOneWidget);
    });

    testWidgets('刪除：二次確認後移除', (tester) async {
      await pumpWords(tester);

      await tester.tap(find.byTooltip('移除').first);
      await tester.pumpAndSettle();
      expect(find.text('移除這個詞？'), findsOneWidget);
      await tester.tap(find.text('移除').last);
      await tester.pumpAndSettle();

      expect(find.text('測試詞甲'), findsNothing);
      expect(find.text('測試詞乙'), findsOneWidget);
    });
  });

  testWidgets('髒話詞庫：刪除送出中只停用那一列，連點只送一次；完成後恢復', (tester) async {
    final gate = Completer<http.Response>();
    var deletes = 0;
    ApiClient.httpClient = MockClient((r) async {
      if (r.method == 'DELETE') {
        deletes++;
        return gate.future;
      }
      return jsonResponse(
        loadSpecFixtureMap('get_api_admin_banned_words.json'),
      );
    });
    await tester.pumpWidget(_app(const AdminBannedWordsScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('移除').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('移除').last);
    await tester.pumpAndSettle();

    List<IconButton> buttons() => tester
        .widgetList<IconButton>(
          find.ancestor(
            of: find.byIcon(Icons.delete_outline),
            matching: find.byType(IconButton),
          ),
        )
        .toList();
    expect(buttons()[0].onPressed, isNull);
    expect(buttons()[1].onPressed, isNotNull, reason: '其他列不受影響');
    await tester.tap(find.byTooltip('移除').first, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('移除這個詞？'), findsNothing);

    gate.complete(errorResponse('INTERNAL', status: 500));
    await tester.pumpAndSettle();
    expect(deletes, 1);
    expect(buttons()[0].onPressed, isNotNull);
  });

  group('題目回報', () {
    testWidgets('預設「全部」不帶 status；顯示題型、內容、回報人', (tester) async {
      final statuses = <String?>[];
      installMockClient({
        '/api/admin/question-reports': loadSpecFixtureMap(
          'get_api_admin_question_reports.json',
        ),
      }, onRequest: (r) => statuses.add(r.url.queryParameters['status']));

      await tester.pumpWidget(_app(const AdminQuestionReportsScreen()));
      await tester.pumpAndSettle();

      expect(statuses, [null]);
      expect(find.text('這題答案好像標錯了'), findsOneWidget);
      expect(
        find.textContaining('Bsuring', findRichText: true),
        findsOneWidget,
      );
      expect(find.textContaining('秀林', findRichText: true), findsOneWidget);
      expect(find.textContaining('小明', findRichText: true), findsOneWidget);
      expect(find.text('單字測驗'), findsOneWidget);
      expect(find.text('聽力測驗'), findsOneWidget);
    });

    testWidgets('篩選狀態會帶 status', (tester) async {
      final statuses = <String?>[];
      installMockClient({
        '/api/admin/question-reports': {'reports': []},
      }, onRequest: (r) => statuses.add(r.url.queryParameters['status']));

      await tester.pumpWidget(_app(const AdminQuestionReportsScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('已解決'));
      await tester.pumpAndSettle();

      expect(statuses, [null, 'resolved']);
    });

    testWidgets('標為已解決：PATCH 後列表更新', (tester) async {
      final base = loadSpecFixtureMap('get_api_admin_question_reports.json');
      var resolved = false;
      final patches = <String>[];
      ApiClient.httpClient = MockClient((r) async {
        if (r.method == 'PATCH') {
          patches.add('${r.url.path} ${r.body}');
          resolved = true;
          return jsonResponse({'id': 1, 'status': 'resolved'});
        }
        final reports = (base['reports'] as List)
            .map((e) => {...(e as Map<String, dynamic>)})
            .toList();
        if (resolved) reports[0]['status'] = 'resolved';
        return jsonResponse({'reports': reports});
      });

      await tester.pumpWidget(_app(const AdminQuestionReportsScreen()));
      await tester.pumpAndSettle();
      expect(find.text('待處理'), findsWidgets);

      await tester.tap(find.text('標為已解決').first);
      await tester.pumpAndSettle();

      expect(patches, ['/api/admin/question-reports/1 {"status":"resolved"}']);
      expect(find.text('已標記為已解決'), findsOneWidget);
      // 第一張已解決不再有這顆按鈕；第二張（已查看）仍有。
      expect(find.text('標為已解決'), findsOneWidget);
    });
  });

  testWidgets('題目回報：標記送出中這一筆的標記鈕停用，連點只送一次；失敗後恢復', (tester) async {
    final gate = Completer<http.Response>();
    var patches = 0;
    ApiClient.httpClient = MockClient((r) async {
      if (r.method == 'PATCH') {
        patches++;
        return gate.future;
      }
      return jsonResponse(
        loadSpecFixtureMap('get_api_admin_question_reports.json'),
      );
    });
    await tester.pumpWidget(_app(const AdminQuestionReportsScreen()));
    await tester.pumpAndSettle();

    TextButton resolveFirst() => tester
        .widgetList<TextButton>(find.widgetWithText(TextButton, '標為已解決'))
        .first;
    await tester.tap(find.text('標為已解決').first);
    await tester.pump();
    expect(resolveFirst().onPressed, isNull);
    expect(
      tester
          .widgetList<TextButton>(find.widgetWithText(TextButton, '標為已查看'))
          .first
          .onPressed,
      isNull,
      reason: '同一筆的另一顆也停用',
    );
    await tester.tap(find.text('標為已解決').first, warnIfMissed: false);
    await tester.pump();

    gate.complete(errorResponse('INTERNAL', status: 500));
    await tester.pumpAndSettle();
    expect(patches, 1);
    expect(resolveFirst().onPressed, isNotNull);
  });
}
