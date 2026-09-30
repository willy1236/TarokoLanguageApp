// account_role 推播（管理員變更帳號角色）：payload 依 內部管理.md §8.9 手寫。
// 前景顯示內文並重抓 /api/me；背景點開只重抓。入口靠 userNotifier 跟著變。

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/main.dart' show scaffoldMessengerKey;
import 'package:flutter_application_1/services/fcm_service.dart';
import 'package:flutter_application_1/services/user_service.dart';

import '../helpers/widget_test_helpers.dart';

RemoteMessage _roleMessage() => const RemoteMessage(
  data: {'type': 'account_role', 'role': 'organizer'},
  notification: RemoteNotification(
    title: '帳號權限已更新',
    body: '你的帳號權限已變更為「活動發起人」。',
  ),
);

Map<String, dynamic> _me(String role) => {
  'uid': 1,
  'created_at': '2026-01-01T00:00:00Z',
  'role': role,
};

Widget _app() => MaterialApp(
  scaffoldMessengerKey: scaffoldMessengerKey,
  home: const Scaffold(body: SizedBox()),
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

  testWidgets('前景：顯示通知內文並重抓 /api/me，角色即時更新', (tester) async {
    final paths = <String>[];
    installMockClient({
      '/api/me': _me('organizer'),
    }, onRequest: (r) => paths.add(r.url.path));
    await tester.pumpWidget(_app());

    FcmService.handleForegroundMessage(_roleMessage());
    await tester.pumpAndSettle();

    expect(find.text('你的帳號權限已變更為「活動發起人」。'), findsOneWidget);
    expect(paths, ['/api/me']);
    expect(UserService.userNotifier.value?.canCreateEvent, isTrue);
  });

  testWidgets('背景點開：只重抓 /api/me，不再彈提示', (tester) async {
    final paths = <String>[];
    installMockClient({
      '/api/me': _me('user'),
    }, onRequest: (r) => paths.add(r.url.path));
    await tester.pumpWidget(_app());

    FcmService.handleOpenedMessage(_roleMessage());
    await tester.pumpAndSettle();

    expect(paths, ['/api/me']);
    expect(find.byType(SnackBar), findsNothing);
    expect(UserService.userNotifier.value?.role, 'user');
  });
}
