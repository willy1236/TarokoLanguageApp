// 處置詳情頁：顯示處置、提出申訴、已申訴的狀態，以及被鎖帳號也能申訴。

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_application_1/screens/moderation/moderation_case_screen.dart';
import 'package:flutter_application_1/services/account_lock_controller.dart';

import '../helpers/fixtures.dart';
import '../helpers/widget_test_helpers.dart';

const _casePath = '/api/me/moderation/cases/31';
const _appealPath = '/api/me/moderation/cases/31/appeal';
const _reason = '這是部落活動的公告，不是廣告';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<http.Request> seen;

  setUp(() {
    stubCommonChannels();
    seen = [];
    accountLockController.setLocked(false);
  });
  tearDown(() {
    restoreHttp();
    accountLockController.setLocked(false);
  });

  Map<String, dynamic> caseJson() =>
      loadSpecFixtureMap('get_api_me_moderation_case.json');

  void install({Object? caseResponse, Object? appealResponse}) {
    installMockClient({
      _casePath: caseResponse ?? caseJson(),
      _appealPath:
          appealResponse ??
          jsonResponse(
            loadSpecFixtureMap('post_api_me_moderation_case_appeal.json'),
            status: 201,
          ),
    }, onRequest: seen.add);
  }

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(wrapScreen(const ModerationCaseScreen(caseId: 31)));
    await tester.pumpAndSettle();
  }

  Future<void> fillAndSubmit(WidgetTester tester) async {
    await tester.tap(find.text('對處置有疑問？提出申訴'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), _reason);
    await tester.pump();
    await tester.tap(find.text('送出申訴'));
    await tester.pumpAndSettle();
  }

  FilledButton submitButton(WidgetTester tester) =>
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, '送出申訴'));

  testWidgets('顯示被處置的內容、理由、狀態與處罰', (tester) async {
    install();
    await open(tester);

    expect(find.textContaining('貼文', findRichText: true), findsWidgets);
    expect(find.textContaining('已確認', findRichText: true), findsOneWidget);
    expect(find.textContaining('廣告洗版', findRichText: true), findsOneWidget);
    expect(find.text('違規標題'), findsOneWidget);
    expect(find.text('違規內文'), findsOneWidget);
    expect(find.textContaining('第 1 次違規', findRichText: true), findsOneWidget);
    expect(find.textContaining('沒有停權', findRichText: true), findsOneWidget);
    expect(find.textContaining('申訴期限', findRichText: true), findsOneWidget);
  });

  testWidgets('理由不到 10 字不能送；送出後改顯示申訴狀態', (tester) async {
    install();
    await open(tester);

    await tester.tap(find.text('對處置有疑問？提出申訴'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '太短了');
    await tester.pump();
    expect(submitButton(tester).onPressed, isNull);

    await tester.enterText(find.byType(TextField), '  $_reason  ');
    await tester.pump();
    await tester.tap(find.text('送出申訴'));
    await tester.pumpAndSettle();

    final post = seen.singleWhere((r) => r.method == 'POST');
    expect(jsonDecode(post.body), {'reason': _reason});
    expect(find.textContaining('處理中', findRichText: true), findsOneWidget);
    expect(find.textContaining(_reason, findRichText: true), findsOneWidget);
    expect(find.text('對處置有疑問？提出申訴'), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('已申訴：顯示申訴理由、狀態與管理員回覆，沒有申訴入口', (tester) async {
    install(
      caseResponse: caseJson()
        ..['can_appeal'] = false
        ..['appeal'] = {
          'id': 7,
          'status': 'rejected',
          'reason': _reason,
          'reply': '內容確實是商業廣告',
          'created_at': '2026-09-30T10:00:00Z',
          'handled_at': '2026-10-01T10:00:00Z',
        },
    );
    await open(tester);

    expect(find.textContaining('已駁回', findRichText: true), findsOneWidget);
    expect(
      find.textContaining('內容確實是商業廣告', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('對處置有疑問？提出申訴'), findsNothing);
  });

  testWidgets('不能申訴（逾期或已撤銷）時不顯示申訴入口', (tester) async {
    install(caseResponse: caseJson()..['can_appeal'] = false);
    await open(tester);

    expect(find.text('對處置有疑問？提出申訴'), findsNothing);
  });

  for (final code in ['APPEAL_EXISTS', 'APPEAL_CLOSED']) {
    testWidgets('409 $code 顯示後端訊息', (tester) async {
      install(
        appealResponse: errorResponse(code, status: 409, message: '後端說明：$code'),
      );
      await open(tester);
      await fillAndSubmit(tester);

      expect(find.text('後端說明：$code'), findsOneWidget);
    });
  }

  testWidgets('404 CASE_NOT_FOUND 顯示「找不到這筆處置紀錄」', (tester) async {
    install(
      caseResponse: errorResponse('CASE_NOT_FOUND', status: 404, message: 'x'),
    );
    await open(tester);

    expect(find.text('找不到這筆處置紀錄'), findsOneWidget);
  });

  testWidgets('被鎖（唯讀）帳號也能開這頁並送出申訴，不出現唯讀提示', (tester) async {
    accountLockController.setLocked(true);
    install();
    await open(tester);
    await fillAndSubmit(tester);

    expect(seen.where((r) => r.method == 'POST'), hasLength(1));
    expect(find.text(readOnlyMessage), findsNothing);
    expect(find.textContaining('處理中', findRichText: true), findsOneWidget);
  });
}
