// 後台申訴：列表、接受／駁回、錯誤訊息。回應依 收件匣與申訴.md §4 手寫
// （錄製時沒有申訴；resolve 會真的撤銷處置，不錄）。

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/main.dart' show scaffoldMessengerKey;
import 'package:flutter_application_1/models/admin_models.dart';
import 'package:flutter_application_1/screens/admin/admin_appeals_screen.dart';

import '../../helpers/fixtures.dart';
import '../../helpers/widget_test_helpers.dart';

Widget _app() => MaterialApp(
  scaffoldMessengerKey: scaffoldMessengerKey,
  home: const AdminAppealsScreen(),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<http.Request> seen;
  late List<Map<String, dynamic>> all;

  setUp(() {
    stubCommonChannels();
    seen = [];
    all = (loadSpecFixtureMap('get_api_admin_appeals.json')['appeals'] as List)
        .cast<Map<String, dynamic>>();
  });
  tearDown(restoreHttp);

  void install({http.Response Function(http.Request)? resolve}) {
    ApiClient.httpClient = MockClient((r) async {
      seen.add(r);
      if (r.method == 'POST') {
        final response =
            resolve?.call(r) ??
            jsonResponse(
              loadSpecFixtureMap('post_api_admin_appeal_resolve.json'),
            );
        // 處理成功的那筆離開待處理列表。
        if (response.statusCode == 200) all[0]['status'] = 'accepted';
        return response;
      }
      final status = r.url.queryParameters['status'];
      return jsonResponse({
        'appeals': [
          for (final a in all)
            if (a['status'] == status) a,
        ],
      });
    });
  }

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
  }

  Future<void> fillReply(
    WidgetTester tester,
    String button,
    String reply,
  ) async {
    await tester.tap(
      find
          .widgetWithText(
            button == '接受' ? FilledButton : OutlinedButton,
            button,
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), reply);
    await tester.pump();
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();
  }

  test('模型：案件帶上當事人，預覽沿用違規區的解析', () {
    final appeals = all.map(AdminAppeal.fromJson).toList();

    expect(appeals[0].offender.friendCode, 'DDDD2345');
    expect(appeals[0].appealCase.id, 31);
    expect(appeals[0].appealCase.reason, '廣告洗版');
    expect(appeals[0].appealCase.offenderUid, 3);
    expect(appeals[0].appealCase.strikeNumber, 1);
    expect((appeals[0].appealCase.preview as PostCasePreview).title, '違規標題');
    expect(appeals[1].handledByNickname, '管理員丙');
    expect((appeals[1].appealCase.preview as CommentCasePreview).body, '違規留言');
  });

  testWidgets('待處理：顯示申訴理由、當事人暱稱與好友碼、案件原始理由、狀態與內容預覽', (tester) async {
    install();
    await open(tester);

    expect(seen.single.url.queryParameters, {'status': 'pending'});
    expect(find.text('這是部落活動的公告，不是廣告'), findsOneWidget);
    expect(
      find.textContaining('作者（DDDD2345）', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('廣告洗版', findRichText: true), findsOneWidget);
    expect(find.textContaining('已確認違規', findRichText: true), findsOneWidget);
    expect(find.text('違規標題'), findsOneWidget);
    expect(find.text('接受'), findsOneWidget);
    expect(find.text('駁回'), findsOneWidget);
  });

  testWidgets('接受：回覆必填、二次確認，成功後顯示是否退回違規次數與解除停權，列表移除', (tester) async {
    install();
    await open(tester);

    await tester.tap(find.widgetWithText(FilledButton, '接受'));
    await tester.pumpAndSettle();
    expect(find.text('給申訴人的回覆（必填）'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '下一步'))
          .onPressed,
      isNull,
      reason: '沒填回覆不能下一步',
    );
    await tester.enterText(find.byType(TextField), ' 經複查不是廣告 ');
    await tester.pump();
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();

    expect(find.textContaining('確定接受「作者」的申訴並撤銷處置？'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '接受').last);
    await tester.pumpAndSettle();

    final post = seen.singleWhere((r) => r.method == 'POST');
    expect(post.url.path, '/api/admin/appeals/7/resolve');
    expect(jsonDecode(post.body), {'decision': 'accept', 'reply': '經複查不是廣告'});
    expect(find.textContaining('違規次數已退回'), findsOneWidget);
    expect(find.textContaining('沒有解除停權'), findsOneWidget);

    await tester.tap(find.text('知道了'));
    await tester.pumpAndSettle();
    expect(find.text('這是部落活動的公告，不是廣告'), findsNothing);
  });

  testWidgets('處理完一筆後，補上來的下一筆仍可處理', (tester) async {
    all.add({
      ...all[0],
      'id': 9,
      'reason': '第二筆待處理的申訴',
      'offender': {...all[0]['offender'] as Map<String, dynamic>},
    });
    install();
    await open(tester);

    await fillReply(tester, '接受', '回覆');
    await tester.tap(find.widgetWithText(FilledButton, '接受').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('知道了'));
    await tester.pumpAndSettle();

    expect(find.text('第二筆待處理的申訴'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '接受'))
          .onPressed,
      isNotNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, '駁回'))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('通話、自動禁言案件沒有內容預覽：不顯示空的預覽列', (tester) async {
    all[0]['case'] = {
      ...all[0]['case'] as Map<String, dynamic>,
      'target_type': 'call',
      'preview': null,
    };
    install();
    await open(tester);

    expect(find.textContaining('通話雙方', findRichText: true), findsNothing);
    expect(find.text('這是部落活動的公告，不是廣告'), findsOneWidget);
  });

  testWidgets('個人檔案案件只有重設前的值：不顯示空的「目前」', (tester) async {
    all[0]['case'] = {
      ...all[0]['case'] as Map<String, dynamic>,
      'target_type': 'profile',
      'preview': {
        'before': {'video_nickname': '不雅暱稱'},
      },
    };
    install();
    await open(tester);

    expect(find.textContaining('不雅暱稱', findRichText: true), findsOneWidget);
    expect(find.text('目前'), findsNothing);
  });

  testWidgets('駁回：送 reject 與回覆', (tester) async {
    install(
      resolve: (_) => jsonResponse({
        'ok': true,
        'status': 'rejected',
        'strike_reverted': false,
        'unlocked': false,
      }),
    );
    await open(tester);
    await fillReply(tester, '駁回', '內容確實是廣告');
    await tester.tap(find.widgetWithText(FilledButton, '駁回').last);
    await tester.pumpAndSettle();

    expect(jsonDecode(seen.singleWhere((r) => r.method == 'POST').body), {
      'decision': 'reject',
      'reply': '內容確實是廣告',
    });
    expect(find.text('已駁回申訴'), findsOneWidget);
  });

  for (final (status, code) in [
    (403, 'SELF_INVOLVED'),
    (403, 'SAME_ADMIN'),
    (409, 'APPEAL_ALREADY_HANDLED'),
  ]) {
    testWidgets('$status $code：直接顯示後端 message，不加前綴', (tester) async {
      install(
        resolve: (_) =>
            errorResponse(code, status: status, message: '後端說明：$code'),
      );
      await open(tester);
      await fillReply(tester, '接受', '回覆');
      await tester.tap(find.widgetWithText(FilledButton, '接受').last);
      await tester.pumpAndSettle();

      expect(find.text('後端說明：$code'), findsOneWidget);
    });
  }

  testWidgets('已駁回分頁：顯示處理人與回覆，不能再處理', (tester) async {
    install();
    await open(tester);

    await tester.tap(find.text('已駁回'));
    await tester.pumpAndSettle();

    expect(seen.last.url.queryParameters, {'status': 'rejected'});
    expect(find.textContaining('管理員丙', findRichText: true), findsOneWidget);
    expect(
      find.textContaining('留言內容確實屬於人身攻擊', findRichText: true),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, '接受'), findsNothing);
    expect(find.widgetWithText(OutlinedButton, '駁回'), findsNothing);
  });
}
