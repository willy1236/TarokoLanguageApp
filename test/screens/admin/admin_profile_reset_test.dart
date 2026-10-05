// 公開個人頁的「重設個人檔案」：公開個人頁不回 uid（FRIEND_CODE_ENFORCE 開啟），
// 管理員選了之後先填理由並確認，確認後才用好友碼查 uid 再送出（查人會留稽核紀錄）。

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_application_1/main.dart' show scaffoldMessengerKey;
import 'package:flutter_application_1/models/user_model.dart';
import 'package:flutter_application_1/screens/friends/public_profile_screen.dart';
import 'package:flutter_application_1/services/user_service.dart';

import '../../helpers/fixtures.dart';
import '../../helpers/widget_test_helpers.dart';

void _login(String role) {
  UserService.currentUid = 1;
  UserService.cacheUser(
    UserModel(
      uid: 1,
      email: '',
      createdAt: DateTime(2026),
      friendCode: 'ADMIN001',
      role: role,
    ),
  );
}

Widget _app() => MaterialApp(
  scaffoldMessengerKey: scaffoldMessengerKey,
  home: const PublicProfileScreen(friendCode: 'A3K9XM7P'),
);

List<http.Request> _mock({Object? lookup}) {
  final requests = <http.Request>[];
  installMockClient({
    '/api/users/A3K9XM7P': loadSpecFixtureMap('get_api_users_friend_code.json'),
    '/api/friends': {'friends': <Object>[]},
    '/api/friends/blocks': {'blocks': <Object>[]},
    '/api/shop/items': {'items': <Object>[]},
    '/api/admin/users/lookup':
        lookup ??
        {
          'user': {'uid': 77, 'friend_code': 'A3K9XM7P', 'nickname': '小明'},
        },
    '/api/admin/users/77/profile/reset': {'case': null},
  }, onRequest: requests.add);
  return requests;
}

Future<void> _openReset(WidgetTester tester) async {
  await tester.pumpWidget(_app());
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.more_vert));
  await tester.pumpAndSettle();
  await tester.tap(find.text('重設個人檔案'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(stubCommonChannels);
  tearDown(() {
    restoreHttp();
    UserService.clearCache();
  });

  testWidgets('一般使用者看不到重設', (tester) async {
    _login('user');
    _mock();
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('檢舉'), findsOneWidget);
    expect(find.text('重設個人檔案'), findsNothing);
  });

  testWidgets('管理員看自己的公開個人頁沒有選單，也就沒有重設', (tester) async {
    UserService.currentUid = 1;
    UserService.cacheUser(
      UserModel(
        uid: 1,
        email: '',
        createdAt: DateTime(2026),
        friendCode: 'A3K9XM7P',
        role: 'admin',
      ),
    );
    _mock();
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('小明'), findsWidgets, reason: '頁面確實載入了');
    expect(find.byIcon(Icons.more_vert), findsNothing);
  });

  Future<void> confirmReason(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField).last, '暱稱不雅');
    await tester.pump();
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('重設').last);
    await tester.pumpAndSettle();
  }

  testWidgets('管理員：公開個人頁沒有 uid 也看得到，確認理由後才查 uid 再重設', (tester) async {
    _login('admin');
    final requests = _mock();
    await _openReset(tester);

    expect(
      requests.where((r) => r.url.path == '/api/admin/users/lookup'),
      isEmpty,
      reason: '理由框出現時還沒查人',
    );
    await confirmReason(tester);

    final lookup = requests.singleWhere(
      (r) => r.url.path == '/api/admin/users/lookup',
    );
    expect(lookup.url.queryParameters['friend_code'], 'A3K9XM7P');
    final reset = requests.singleWhere((r) => r.method == 'POST');
    expect(reset.url.path, '/api/admin/users/77/profile/reset');
    expect(jsonDecode(reset.body)['reason'], '暱稱不雅');
    expect(find.text('已重設，等待其他管理員二審'), findsOneWidget);
  });

  testWidgets('打開理由框後取消：不打任何後台 API', (tester) async {
    _login('admin');
    final requests = _mock();
    await _openReset(tester);
    final before = requests.length;

    await tester.tap(find.text('返回'));
    await tester.pumpAndSettle();

    expect(find.text('下一步'), findsNothing, reason: '理由框已關閉');
    expect(requests.length, before);
    expect(requests.where((r) => r.url.path.startsWith('/api/admin')), isEmpty);
  });

  testWidgets('查 uid 失敗：顯示後端 message，不送出重設', (tester) async {
    _login('admin');
    final requests = _mock(
      lookup: errorResponse(
        'USER_NOT_FOUND',
        status: 404,
        message: '找不到這個好友碼的使用者',
      ),
    );
    await _openReset(tester);
    await confirmReason(tester);

    expect(find.text('找不到這個好友碼的使用者'), findsOneWidget);
    expect(requests.where((r) => r.method == 'POST'), isEmpty);
  });
}
