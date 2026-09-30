// 更正出生日期：查人後預帶目前生日，選日期、填理由、確認後送出，顯示是否滿 18 歲。
// PATCH 回應依 內部管理.md §8.3a 手寫（錄製會真的改資料）。

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/main.dart' show scaffoldMessengerKey;
import 'package:flutter_application_1/screens/admin/admin_birth_date_screen.dart';

import '../../helpers/widget_test_helpers.dart';

Widget _app() => MaterialApp(
  scaffoldMessengerKey: scaffoldMessengerKey,
  home: const AdminBirthDateScreen(),
);

Map<String, dynamic> _lookup({String? birthDate}) => {
  'user': {
    'uid': 12,
    'friend_code': 'ABCD2345',
    'nickname': '阿華',
    'status': 'active',
    'role': 'user',
    'birth_date': birthDate,
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(stubCommonChannels);
  tearDown(restoreHttp);

  List<http.Request> install({
    String? birthDate = '2001-05-20',
    http.Response Function(http.Request)? patch,
  }) {
    final requests = <http.Request>[];
    ApiClient.httpClient = MockClient((r) async {
      requests.add(r);
      if (r.method == 'PATCH') {
        return patch?.call(r) ??
            jsonResponse({
              'uid': 12,
              'birth_date': '2001-05-21',
              'adult': true,
            });
      }
      return jsonResponse(_lookup(birthDate: birthDate));
    });
    return requests;
  }

  Future<void> lookUp(WidgetTester tester) async {
    await tester.pumpWidget(_app());
    await tester.enterText(find.byType(TextField), 'ABCD2345');
    await tester.tap(find.text('查詢'));
    await tester.pumpAndSettle();
  }

  Future<void> fillReasonAndConfirm(WidgetTester tester) async {
    await tester.tap(find.text('送出更正'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '使用者來信說打錯一天');
    await tester.pump();
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('更正').last);
    await tester.pumpAndSettle();
  }

  testWidgets('預帶目前生日；送出 uid、日期與理由，顯示已滿 18 歲', (tester) async {
    final requests = install();
    await lookUp(tester);

    expect(find.textContaining('2001', findRichText: true), findsWidgets);
    expect(find.textContaining('更正為'), findsOneWidget);

    await fillReasonAndConfirm(tester);

    final patch = requests.singleWhere((r) => r.method == 'PATCH');
    expect(patch.url.path, '/api/admin/users/12/birth-date');
    expect(jsonDecode(patch.body), {
      'birth_date': '2001-05-20',
      'reason': '使用者來信說打錯一天',
    });
    expect(find.text('已滿 18 歲'), findsOneWidget);
    expect(find.textContaining('移出隨機配對佇列'), findsNothing);
  });

  testWidgets('未填寫時顯示「未填寫」，選好日期前不能送出', (tester) async {
    install(birthDate: null);
    await lookUp(tester);

    expect(find.textContaining('未填寫', findRichText: true), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '送出更正'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('更正後未滿 18 歲：說明已移出隨機配對', (tester) async {
    install(
      patch: (_) =>
          jsonResponse({'uid': 12, 'birth_date': '2012-01-01', 'adult': false}),
    );
    await lookUp(tester);
    await fillReasonAndConfirm(tester);

    expect(find.text('未滿 18 歲'), findsOneWidget);
    expect(find.textContaining('移出隨機配對佇列'), findsOneWidget);
  });

  testWidgets('INVALID_REQUEST 顯示後端 message', (tester) async {
    install(
      patch: (_) =>
          errorResponse('INVALID_REQUEST', status: 400, message: '出生日期不可晚於今天'),
    );
    await lookUp(tester);
    await fillReasonAndConfirm(tester);

    expect(find.text('出生日期不可晚於今天'), findsOneWidget);
    expect(find.text('已滿 18 歲'), findsNothing);
  });

  testWidgets('USER_NOT_FOUND 顯示後端 message', (tester) async {
    install(
      patch: (_) =>
          errorResponse('USER_NOT_FOUND', status: 404, message: '找不到這位使用者'),
    );
    await lookUp(tester);
    await fillReasonAndConfirm(tester);

    expect(find.text('找不到這位使用者'), findsOneWidget);
  });

  testWidgets('送出途中換對象：新對象的送出鈕不會卡住，舊的成功仍有提示', (tester) async {
    final pending = Completer<http.Response>();
    ApiClient.httpClient = MockClient((r) async {
      if (r.method == 'PATCH') return pending.future;
      return jsonResponse(_lookup(birthDate: '2001-05-20'));
    });
    await lookUp(tester);
    await fillReasonAndConfirm(tester);

    await tester.enterText(find.byType(TextField).first, 'OTHER234');
    await tester.tap(find.text('查詢'));
    await tester.pumpAndSettle();
    pending.complete(
      jsonResponse({'uid': 12, 'birth_date': '2001-05-20', 'adult': true}),
    );
    await tester.pumpAndSettle();

    expect(find.text('已更正出生日期'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '送出更正'))
          .onPressed,
      isNotNull,
    );
  });
}
