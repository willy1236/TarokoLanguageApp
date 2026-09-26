// NotificationEmailScreen（通知信箱 + 6 碼驗證）的畫面層測試。
//
// 這支取代的人工測試：改信箱、等驗證信、輸入驗證碼、試各種錯誤碼的文案。
// 人工跑一輪要真的收信，而且寄送有 60 秒冷卻與每分鐘 5 次限流，重測很痛。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/models/user_model.dart';
import 'package:flutter_application_1/screens/profile/notification_email_screen.dart';
import 'package:flutter_application_1/services/user_service.dart';

import '../helpers/widget_test_helpers.dart';

UserModel _user({String email = 'me@example.com', bool verified = false}) =>
    UserModel(
      uid: 1,
      email: email,
      emailVerified: verified,
      createdAt: DateTime(2026, 1, 1),
    );

/// /api/me 的最小合法回應，驗證成功後 verifyEmail 會 forceRefresh 打這支。
Map<String, dynamic> _meJson() => {
  'uid': 1,
  'created_at': '2026-01-01T00:00:00Z',
  'email': 'me@example.com',
  'email_verified': true,
};

Widget _app(Widget screen) => MaterialApp(home: screen);

/// 寄送成功後畫面會起 60 秒的重寄冷卻 Timer。
/// 測試結束時還有 pending timer 會讓 flutter_test 報錯，所以要把它跑完。
Future<void> _drainCooldown(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 61));
}

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

  testWidgets('已驗證的信箱顯示信箱與已驗證標記', (tester) async {
    await tester.pumpWidget(
      _app(NotificationEmailScreen(user: _user(verified: true))),
    );

    // 信箱會同時出現在上方狀態列與下方可編輯欄位，兩處都該帶入目前的值。
    expect(find.text('me@example.com'), findsNWidgets(2));
    expect(find.byType(EmailVerifiedBadge), findsOneWidget);
    expect(
      tester
          .widget<EmailVerifiedBadge>(find.byType(EmailVerifiedBadge))
          .verified,
      isTrue,
    );
  });

  testWidgets('尚未設定信箱時顯示提示且不顯示驗證標記', (tester) async {
    await tester.pumpWidget(
      _app(NotificationEmailScreen(user: _user(email: ''))),
    );

    expect(find.text('尚未設定'), findsOneWidget);
    expect(find.byType(EmailVerifiedBadge), findsNothing);
  });

  testWidgets('信箱格式無效時顯示錯誤且不打 API', (tester) async {
    var called = false;
    installMockClient({
      '/api/me/email': <String, dynamic>{},
    }, onRequest: (_) => called = true);

    await tester.pumpWidget(_app(NotificationEmailScreen(user: _user())));
    await tester.enterText(find.byType(TextField), 'not-an-email');
    await tester.tap(find.text('寄送驗證碼'));
    await tester.pump();

    expect(find.text('請輸入有效的電子信箱'), findsOneWidget);
    expect(called, isFalse);
  });

  testWidgets('寄送成功後進入輸入驗證碼步驟，並顯示重寄冷卻', (tester) async {
    installMockClient({'/api/me/email': <String, dynamic>{}});

    await tester.pumpWidget(_app(NotificationEmailScreen(user: _user())));
    await tester.enterText(find.byType(TextField), 'new@example.com');
    await tester.tap(find.text('寄送驗證碼'));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('驗證碼已寄到 new@example.com'), findsOneWidget);
    expect(find.text('驗證'), findsOneWidget);
    expect(find.textContaining('秒後可重寄'), findsOneWidget);

    await _drainCooldown(tester);
    expect(find.text('重新寄送'), findsOneWidget);
  });

  testWidgets('驗證碼不足 6 碼時顯示錯誤且不打 API', (tester) async {
    var verifyCalls = 0;
    installMockClient(
      {
        '/api/me/email': <String, dynamic>{},
        '/api/me/email/verify': <String, dynamic>{},
      },
      onRequest: (req) {
        if (req.url.path == '/api/me/email/verify') verifyCalls++;
      },
    );

    await tester.pumpWidget(_app(NotificationEmailScreen(user: _user())));
    await tester.tap(find.text('寄送驗證碼'));
    await tester.pump();
    await tester.pump();

    await tester.enterText(find.byType(TextField), '123');
    await tester.tap(find.text('驗證'));
    await tester.pump();

    expect(find.text('請輸入 6 位數驗證碼'), findsOneWidget);
    expect(verifyCalls, 0);

    await _drainCooldown(tester);
  });

  testWidgets('驗證成功後帶著更新後的 user 關閉畫面', (tester) async {
    installMockClient({
      '/api/me/email': <String, dynamic>{},
      '/api/me/email/verify': <String, dynamic>{},
      '/api/me': _meJson(),
    });

    UserModel? popped;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              popped = await Navigator.of(context).push<UserModel>(
                MaterialPageRoute(
                  builder: (_) => NotificationEmailScreen(user: _user()),
                ),
              );
            },
            child: const Text('OPEN'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('寄送驗證碼'));
    await tester.pump();
    await tester.pump();

    await tester.enterText(find.byType(TextField), '123456');
    await tester.tap(find.text('驗證'));
    await tester.pumpAndSettle();

    expect(popped, isNotNull);
    expect(popped!.emailVerified, isTrue);
  });

  testWidgets('驗證碼過期時顯示可行動的文案（而不是後端原始訊息）', (tester) async {
    installMockClient({
      '/api/me/email': <String, dynamic>{},
      '/api/me/email/verify': errorResponse(
        'CODE_EXPIRED',
        status: 400,
        message: 'code expired',
      ),
    });

    await tester.pumpWidget(_app(NotificationEmailScreen(user: _user())));
    await tester.tap(find.text('寄送驗證碼'));
    await tester.pump();
    await tester.pump();

    await tester.enterText(find.byType(TextField), '123456');
    await tester.tap(find.text('驗證'));
    await tester.pump();
    await tester.pump();

    expect(find.text('驗證碼已過期，請重新寄送'), findsOneWidget);

    await _drainCooldown(tester);
  });

  testWidgets('錯誤次數過多時顯示專屬文案', (tester) async {
    installMockClient({
      '/api/me/email': <String, dynamic>{},
      '/api/me/email/verify': errorResponse(
        'CODE_ATTEMPTS_EXCEEDED',
        status: 400,
        message: 'too many attempts',
      ),
    });

    await tester.pumpWidget(_app(NotificationEmailScreen(user: _user())));
    await tester.tap(find.text('寄送驗證碼'));
    await tester.pump();
    await tester.pump();

    await tester.enterText(find.byType(TextField), '123456');
    await tester.tap(find.text('驗證'));
    await tester.pump();
    await tester.pump();

    expect(find.text('錯誤次數過多，請重新寄送驗證碼'), findsOneWidget);

    await _drainCooldown(tester);
  });

  testWidgets('「修改信箱」可退回第一段重填', (tester) async {
    installMockClient({'/api/me/email': <String, dynamic>{}});

    await tester.pumpWidget(_app(NotificationEmailScreen(user: _user())));
    await tester.tap(find.text('寄送驗證碼'));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('修改信箱'));
    await tester.pump();

    expect(find.textContaining('驗證碼已寄到'), findsNothing);
    expect(find.textContaining('秒後可再寄送'), findsOneWidget);

    await _drainCooldown(tester);
  });
}
