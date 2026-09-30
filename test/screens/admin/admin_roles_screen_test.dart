// 角色管理：清單、以好友碼查人、選角色＋理由＋確認後送出，錯誤直接顯示後端 message。

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/main.dart' show scaffoldMessengerKey;
import 'package:flutter_application_1/screens/admin/admin_roles_screen.dart';

import '../../helpers/fixtures.dart';
import '../../helpers/widget_test_helpers.dart';

Widget _app() => MaterialApp(
  scaffoldMessengerKey: scaffoldMessengerKey,
  home: const AdminRolesScreen(),
);

final _roles = {
  'users': [
    {'uid': 21, 'nickname': '阿明', 'friend_code': 'ADMIN021', 'role': 'admin'},
    {
      'uid': 43,
      'nickname': '小華',
      'friend_code': 'ORGA0043',
      'role': 'organizer',
    },
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(stubCommonChannels);
  tearDown(restoreHttp);

  /// [patch] 回傳 PATCH 的回應；[lookup] 回傳查人的回應。
  List<http.Request> install({
    http.Response Function(http.Request)? lookup,
    http.Response Function(http.Request)? patch,
  }) {
    final requests = <http.Request>[];
    ApiClient.httpClient = MockClient((r) async {
      requests.add(r);
      if (r.method == 'PATCH') {
        return patch?.call(r) ??
            jsonResponse({'ok': true, 'role': 'organizer', 'changed': true});
      }
      if (r.url.path == '/api/admin/users/lookup') {
        return lookup?.call(r) ??
            jsonResponse(loadFixtureMap('get_api_admin_users_lookup.json'));
      }
      return jsonResponse(_roles);
    });
    return requests;
  }

  Future<void> lookUp(WidgetTester tester, String code) async {
    await tester.enterText(find.byType(TextField), code);
    await tester.tap(find.text('查詢'));
    await tester.pumpAndSettle();
  }

  Future<void> pickRoleAndConfirm(WidgetTester tester, String role) async {
    await tester.tap(find.text(role).last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '部落活動負責人');
    await tester.pump();
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('確定'));
    await tester.pumpAndSettle();
  }

  testWidgets('列出管理員與活動發起人，管理員在前', (tester) async {
    install();
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('阿明'), findsOneWidget);
    expect(find.text('小華'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('阿明')).dy,
      lessThan(tester.getTopLeft(find.text('小華')).dy),
    );
    expect(find.text('設定角色'), findsNothing);
  });

  testWidgets('以好友碼查人後設定角色：送出 uid、角色與理由，成功後重抓清單', (tester) async {
    final requests = install();
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await lookUp(tester, 'testcode');
    expect(
      requests.last.url.queryParameters['friend_code'],
      'testcode',
      reason: '大小寫交給後端處理',
    );
    expect(find.text('測試暱稱'), findsOneWidget);
    expect(
      find.textContaining('2000', findRichText: true),
      findsNothing,
      reason: '查人卡不顯示生日',
    );

    await tester.tap(find.text('設定角色'));
    await tester.pumpAndSettle();
    await pickRoleAndConfirm(tester, '活動發起人');

    final patch = requests.singleWhere((r) => r.method == 'PATCH');
    expect(patch.url.path, '/api/admin/users/20/role');
    expect(jsonDecode(patch.body), {'role': 'organizer', 'reason': '部落活動負責人'});
    expect(find.text('已將「測試暱稱」設為活動發起人'), findsOneWidget);
    expect(
      requests.where((r) => r.url.path == '/api/admin/users/roles'),
      hasLength(2),
    );
    expect(find.text('設定角色'), findsNothing, reason: '設定完清掉查到的對象');
  });

  testWidgets('查無此人：顯示後端 message，不進入設定', (tester) async {
    install(
      lookup: (_) =>
          errorResponse('USER_NOT_FOUND', status: 404, message: '找不到這個好友碼的使用者'),
    );
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await lookUp(tester, 'NOPE2345');

    expect(find.text('找不到這個好友碼的使用者'), findsOneWidget);
    expect(find.text('設定角色'), findsNothing);
  });

  testWidgets('查到後改了輸入就清掉對象，避免對舊 uid 操作', (tester) async {
    install();
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await lookUp(tester, 'TESTCODE');
    expect(find.text('設定角色'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'OTHER');
    await tester.pump();
    expect(find.text('設定角色'), findsNothing);
  });

  testWidgets('清單上改角色：changed false 時提示「角色未變更」', (tester) async {
    final requests = install(
      patch: (_) =>
          jsonResponse({'ok': true, 'role': 'admin', 'changed': false}),
    );
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('改角色').first);
    await tester.pumpAndSettle();
    await pickRoleAndConfirm(tester, '管理員');

    expect(
      requests.singleWhere((r) => r.method == 'PATCH').url.path,
      '/api/admin/users/21/role',
    );
    expect(find.text('角色未變更'), findsOneWidget);
  });

  testWidgets('SELF_ROLE_CHANGE 直接顯示後端 message', (tester) async {
    install(
      patch: (_) =>
          errorResponse('SELF_ROLE_CHANGE', status: 403, message: '不能變更自己的角色'),
    );
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('改角色').first);
    await tester.pumpAndSettle();
    await pickRoleAndConfirm(tester, '一般使用者');

    expect(find.text('不能變更自己的角色'), findsOneWidget);
  });
}
