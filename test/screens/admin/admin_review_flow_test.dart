// 一審（檢舉詳情）與二審（案件詳情）的操作流程與錯誤呈現。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/main.dart' show scaffoldMessengerKey;
import 'package:flutter_application_1/models/admin_models.dart';
import 'package:flutter_application_1/screens/admin/admin_case_detail_screen.dart';
import 'package:flutter_application_1/screens/admin/admin_error.dart';
import 'package:flutter_application_1/screens/admin/admin_report_detail_screen.dart';

import '../../helpers/fixtures.dart';
import '../../helpers/widget_test_helpers.dart';

/// 從一個首頁按鈕 push 詳情頁，回傳結果記在 [result]。
Widget _host(Widget Function() screen, List<Object?> result) => MaterialApp(
  scaffoldMessengerKey: scaffoldMessengerKey,
  home: Builder(
    builder: (context) => Scaffold(
      body: TextButton(
        onPressed: () async =>
            result.add(await pushAdmin<bool>(context, screen())),
        child: const Text('開啟'),
      ),
    ),
  ),
);

AdminReport _report(String type, {Map<String, dynamic>? extra}) =>
    AdminReport.fromJson({
      'id': 5,
      'target_type': type,
      'target_id': 1,
      'reason': '理由',
      'status': 'pending',
      'reporter_nickname': '檢舉人',
      ...?extra,
    });

AdminCase _case({String targetType = 'post', bool contentRemoved = true}) =>
    AdminCase.fromJson({
      'id': 7,
      'target_type': targetType,
      'target_id': 1,
      'offender_uid': 3,
      'offender_nickname': '作者',
      'source': 'admin_delete',
      'reason': '理由',
      'content_removed': contentRemoved,
      'status': 'pending',
      'preview': {'title': '標題', 'body': '內文'},
    });

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('開啟'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(stubCommonChannels);
  tearDown(restoreHttp);

  group('檢舉詳情（一審）', () {
    testWidgets('判定成立：二次確認後顯示案件編號與連帶結案數，並回報列表重抓', (tester) async {
      final result = <Object?>[];
      installMockClient({
        '/api/admin/forum/reports/5/resolve': loadSpecFixtureMap(
          'post_api_admin_report_resolve_action.json',
        ),
      });
      await tester.pumpWidget(
        _host(() => AdminReportDetailScreen(report: _report('post')), result),
      );
      await _open(tester);

      await tester.tap(find.text('判定成立'));
      await tester.pumpAndSettle();
      expect(find.text('判定成立？'), findsOneWidget, reason: '送出前二次確認');
      await tester.tap(find.text('判定成立').last);
      await tester.pumpAndSettle();

      expect(find.textContaining('案件編號 7'), findsOneWidget);
      expect(find.textContaining('另有 2 筆檢舉一併結案'), findsOneWidget);
      await tester.tap(find.text('知道了'));
      await tester.pumpAndSettle();
      expect(result, [true]);
    });

    testWidgets('個人檔案：預設全選、至少選一項才能送出、只送勾選的欄位', (tester) async {
      Object? sent;
      installMockClient({
        '/api/admin/forum/reports/5/resolve': loadSpecFixtureMap(
          'post_api_admin_report_resolve_action.json',
        ),
      }, onRequest: (r) => sent = r.body);
      await tester.pumpWidget(
        _host(
          () => AdminReportDetailScreen(report: _report('profile')),
          <Object?>[],
        ),
      );
      await _open(tester);

      FilledButton submit() => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '判定成立'),
      );
      expect(submit().onPressed, isNotNull);
      for (final label in ['暱稱', '自我介紹', '頭像']) {
        expect(
          tester
              .widget<CheckboxListTile>(
                find.widgetWithText(CheckboxListTile, label),
              )
              .value,
          isTrue,
        );
      }

      await tester.tap(find.text('暱稱'));
      await tester.tap(find.text('自我介紹'));
      await tester.tap(find.text('頭像'));
      await tester.pump();
      expect(submit().onPressed, isNull, reason: '一項都沒選不能送出');

      await tester.tap(find.text('頭像'));
      await tester.pump();
      await tester.tap(find.text('判定成立'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('判定成立').last);
      await tester.pumpAndSettle();

      expect(sent, contains('"reset_fields":["avatar"]'));
    });

    testWidgets('駁回且自動解除禁言：提示已解除檢舉禁言', (tester) async {
      installMockClient({
        '/api/admin/forum/reports/5/resolve': {
          'ok': true,
          'status': 'dismissed',
          'case': null,
          'auto_closed_report_ids': [],
          'auto_lifted_mute_id': 4,
        },
      });
      await tester.pumpWidget(
        _host(
          () => AdminReportDetailScreen(report: _report('post')),
          <Object?>[],
        ),
      );
      await _open(tester);

      await tester.tap(find.text('駁回'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('駁回').last);
      await tester.pumpAndSettle();

      expect(find.textContaining('已自動解除該使用者的檢舉禁言'), findsOneWidget);
    });

    testWidgets('SELF_INVOLVED：顯示後端訊息、留在本頁、不回報變動', (tester) async {
      final result = <Object?>[];
      installMockClient({
        '/api/admin/forum/reports/5/resolve': errorResponse(
          'SELF_INVOLVED',
          status: 403,
          message: '這個案件的當事人是你自己，請交給其他管理員審核',
        ),
      });
      await tester.pumpWidget(
        _host(() => AdminReportDetailScreen(report: _report('post')), result),
      );
      await _open(tester);

      await tester.tap(find.text('判定成立'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('判定成立').last);
      await tester.pumpAndSettle();

      expect(find.text('這個案件的當事人是你自己，請交給其他管理員審核'), findsOneWidget);
      expect(find.text('檢舉詳情'), findsOneWidget);
      expect(result, isEmpty);
    });

    testWidgets('ALREADY_REVIEWED：顯示訊息並回列表重抓', (tester) async {
      final result = <Object?>[];
      installMockClient({
        '/api/admin/forum/reports/5/resolve': errorResponse(
          'ALREADY_REVIEWED',
          status: 409,
          message: '這筆檢舉已被審核',
        ),
      });
      await tester.pumpWidget(
        _host(() => AdminReportDetailScreen(report: _report('post')), result),
      );
      await _open(tester);

      await tester.tap(find.text('駁回'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('駁回').last);
      await tester.pumpAndSettle();

      expect(find.text('這筆檢舉已被審核'), findsOneWidget);
      expect(result, [true]);
    });

    testWidgets('TARGET_NOT_FOUND：顯示訊息、提示改用駁回並停用判定成立', (tester) async {
      installMockClient({
        '/api/admin/forum/reports/5/resolve': errorResponse(
          'TARGET_NOT_FOUND',
          status: 409,
          message: '檢舉對象已不存在',
        ),
      });
      await tester.pumpWidget(
        _host(
          () => AdminReportDetailScreen(report: _report('call')),
          <Object?>[],
        ),
      );
      await _open(tester);

      await tester.tap(find.text('判定成立'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('判定成立').last);
      await tester.pumpAndSettle();

      expect(find.text('檢舉對象已不存在'), findsOneWidget);
      expect(find.textContaining('改用「駁回」'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '判定成立'))
            .onPressed,
        isNull,
      );
    });
  });

  group('案件詳情（二審）', () {
    testWidgets('確認違規：顯示第幾次、鎖帳號與連帶取消活動', (tester) async {
      final result = <Object?>[];
      Object? sent;
      installMockClient({
        '/api/admin/moderation/cases/7/review': loadSpecFixtureMap(
          'post_api_admin_case_review_confirm.json',
        ),
      }, onRequest: (r) => sent = r.body);
      await tester.pumpWidget(
        _host(() => AdminCaseDetailScreen(adminCase: _case()), result),
      );
      await _open(tester);

      await tester.enterText(find.byType(TextField), '  查證屬實  ');
      await tester.tap(find.text('確認違規'));
      await tester.pumpAndSettle();
      expect(find.text('確認違規？'), findsOneWidget, reason: '送出前二次確認');
      await tester.tap(find.text('確認違規').last);
      await tester.pumpAndSettle();

      expect(sent, contains('"note":"查證屬實"'));
      expect(find.textContaining('第 3 次違規'), findsOneWidget);
      expect(find.textContaining('帳號已鎖定'), findsOneWidget);
      expect(find.textContaining('連帶取消 2 個'), findsOneWidget);
      await tester.tap(find.text('知道了'));
      await tester.pumpAndSettle();
      expect(result, [true]);
    });

    testWidgets('撤銷：說明已恢復內容，並提到自動解除的禁言', (tester) async {
      installMockClient({
        '/api/admin/moderation/cases/7/review': {
          'case': {
            'id': 7,
            'target_type': 'post',
            'target_id': 1,
            'offender_uid': 3,
            'source': 'admin_delete',
            'reason': '理由',
            'status': 'overturned',
          },
          'strike': null,
          'auto_lifted_mute_id': 9,
        },
      });
      await tester.pumpWidget(
        _host(() => AdminCaseDetailScreen(adminCase: _case()), <Object?>[]),
      );
      await _open(tester);

      await tester.tap(find.text('撤銷'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('撤銷').last);
      await tester.pumpAndSettle();

      expect(find.textContaining('已恢復內容'), findsOneWidget);
      expect(find.textContaining('自動解除'), findsOneWidget);
    });

    for (final code in ['SAME_ADMIN', 'SELF_INVOLVED']) {
      testWidgets('$code：顯示後端訊息、案件留在原處', (tester) async {
        final result = <Object?>[];
        installMockClient({
          '/api/admin/moderation/cases/7/review': errorResponse(
            code,
            status: 403,
            message: '$code 的後端訊息',
          ),
        });
        await tester.pumpWidget(
          _host(() => AdminCaseDetailScreen(adminCase: _case()), result),
        );
        await _open(tester);

        await tester.tap(find.text('確認違規'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('確認違規').last);
        await tester.pumpAndSettle();

        expect(find.text('$code 的後端訊息'), findsOneWidget);
        expect(find.text('案件詳情'), findsOneWidget);
        expect(result, isEmpty);
      });
    }

    testWidgets('CASE_ALREADY_REVIEWED：顯示訊息並回列表重抓', (tester) async {
      final result = <Object?>[];
      installMockClient({
        '/api/admin/moderation/cases/7/review': errorResponse(
          'CASE_ALREADY_REVIEWED',
          status: 409,
          message: '這個案件已審核過',
        ),
      });
      await tester.pumpWidget(
        _host(() => AdminCaseDetailScreen(adminCase: _case()), result),
      );
      await _open(tester);

      await tester.tap(find.text('撤銷'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('撤銷').last);
      await tester.pumpAndSettle();

      expect(find.text('這個案件已審核過'), findsOneWidget);
      expect(result, [true]);
    });

    testWidgets('解鎖帳號：只有 locked 才有按鈕；成功後狀態改為正常', (tester) async {
      installMockClient({
        '/api/admin/users/3/unlock': {'ok': true, 'status': 'active'},
      });
      final locked = AdminCase.fromJson({
        'id': 7,
        'target_type': 'post',
        'target_id': 1,
        'offender_uid': 3,
        'offender_nickname': '作者',
        'offender_status': 'locked',
        'source': 'admin_delete',
        'reason': '理由',
        'status': 'confirmed',
        'preview': {'title': '標題', 'body': '內文'},
      });
      await tester.pumpWidget(
        _host(() => AdminCaseDetailScreen(adminCase: locked), <Object?>[]),
      );
      await _open(tester);
      expect(
        find.textContaining('作者（locked）', findRichText: true),
        findsOneWidget,
      );

      await tester.tap(find.text('解鎖帳號'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('下一步'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('解鎖').last);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('作者（active）', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('解鎖帳號'), findsNothing, reason: '已不是鎖定狀態');
    });

    testWidgets('未鎖定的案件不顯示解鎖帳號', (tester) async {
      await tester.pumpWidget(
        _host(() => AdminCaseDetailScreen(adminCase: _case()), <Object?>[]),
      );
      await _open(tester);
      expect(find.text('解鎖帳號'), findsNothing);
    });

    testWidgets('NOT_LOCKED：顯示訊息並回列表重抓', (tester) async {
      final result = <Object?>[];
      installMockClient({
        '/api/admin/users/3/unlock': errorResponse(
          'NOT_LOCKED',
          status: 404,
          message: '該帳號未被鎖定',
        ),
      });
      final locked = AdminCase.fromJson({
        'id': 7,
        'target_type': 'post',
        'target_id': 1,
        'offender_uid': 3,
        'offender_nickname': '作者',
        'offender_status': 'locked',
        'source': 'admin_delete',
        'reason': '理由',
        'status': 'confirmed',
      });
      await tester.pumpWidget(
        _host(() => AdminCaseDetailScreen(adminCase: locked), result),
      );
      await _open(tester);

      await tester.tap(find.text('解鎖帳號'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('下一步'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('解鎖').last);
      await tester.pumpAndSettle();

      expect(find.text('該帳號未被鎖定'), findsOneWidget);
      expect(result, [true]);
    });

    testWidgets('備註超過 500 字：不送出', (tester) async {
      var requests = 0;
      installMockClient({
        '/api/admin/moderation/cases/7/review': {},
      }, onRequest: (_) => requests++);
      await tester.pumpWidget(
        _host(() => AdminCaseDetailScreen(adminCase: _case()), <Object?>[]),
      );
      await _open(tester);

      // formatter 會截斷輸入，直接寫 controller 模擬輸入法組字中放行的超長內容。
      tester.widget<TextField>(find.byType(TextField)).controller!.text =
          '字' * 501;
      await tester.tap(find.text('確認違規'));
      await tester.pumpAndSettle();

      expect(find.textContaining('備註不能超過 500 字'), findsOneWidget);
      expect(requests, 0);
    });
  });
}
