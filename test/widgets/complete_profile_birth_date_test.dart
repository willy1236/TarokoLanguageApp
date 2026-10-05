// 完善資料頁的出生日期（POL-01）：必填，送出時帶 YYYY-MM-DD。

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_application_1/screens/auth/complete_profile_screen.dart';
import 'package:flutter_application_1/services/user_service.dart';

import '../helpers/birth_date_test_helpers.dart';
import '../helpers/fixtures.dart';
import '../helpers/widget_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(stubCommonChannels);
  tearDown(() {
    restoreHttp();
    UserService.clearCache();
  });

  late List<http.Request> requests;

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    requests = [];
    installMockClient({
      '/api/me/complete-profile': loadFixtureMap('get_api_me.json'),
    }, onRequest: requests.add);
    await tester.pumpWidget(
      wrapScreen(
        CompleteProfileScreen(readGoogleName: () => '阿華'),
        routes: {'/home': (_) => const Text('HOME')},
      ),
    );
    await tester.enterText(
      find.widgetWithText(TextField, '論壇、視訊、好友都會顯示這個名字'),
      '小華',
    );
  }

  testWidgets('沒選出生日期不能送出', (tester) async {
    await open(tester);

    await tester.tap(find.text('完　成'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(SnackBar, '請選擇出生日期'), findsOneWidget);
    expect(requests, isEmpty);
  });

  testWidgets('送出時帶選到的日期 YYYY-MM-DD', (tester) async {
    await open(tester);
    await pickBirthDate(tester, year: 2000, day: 5);

    await tester.tap(find.text('完　成'));
    await tester.pumpAndSettle();
    expect(requests, isEmpty, reason: '確認前不能送出');
    await confirmBirthDateDialog(tester);

    final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
    expect(body['birth_date'], matches(RegExp(r'^2000-\d{2}-05$')));
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('確認框按取消不送出，選的日期保留', (tester) async {
    await open(tester);
    await pickBirthDate(tester, year: 2000, day: 5);
    final picked = find.textContaining(RegExp(r'^2000/\d{2}/05$'));
    expect(picked, findsOneWidget);

    await tester.tap(find.text('完　成'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(find.text('確認出生日期'), findsNothing);
    expect(requests, isEmpty);
    expect(picked, findsOneWidget);
  });
}
