// AccountPendingScreen（帳號刪除緩衝期畫面）的畫面層測試。
//
// 這支取代的人工測試：登入到刪除中的帳號、看倒數天數對不對、
// 按「重新啟用」會不會正確導向、在別台裝置已重新啟用時會不會自己跳回主畫面。
// 這些原本都要真的去申請刪除一個帳號才測得到。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/screens/account/account_pending_screen.dart';
import 'package:flutter_application_1/services/account_lock_controller.dart';
import 'package:flutter_application_1/services/user_service.dart';

import '../helpers/widget_test_helpers.dart';

/// /api/me 的最小合法回應：UserModel.fromJson 只硬性要求 uid 與 created_at。
Map<String, dynamic> _me({bool profileCompleted = true}) => {
  'uid': 1,
  'created_at': '2026-01-01T00:00:00Z',
  'profile_completed': profileCompleted,
};

/// 把畫面放進帶命名路由的 App，才能驗證 pushNamedAndRemoveUntil 導去哪裡。
Widget _app(Widget screen) => MaterialApp(
  home: screen,
  routes: {
    '/home': (_) => const Scaffold(body: Text('HOME')),
    '/login': (_) => const Scaffold(body: Text('LOGIN')),
    '/complete-profile': (_) => const Scaffold(body: Text('COMPLETE')),
  },
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    stubCommonChannels();
    // 全域單例會跨測試殘留，每支測試都從乾淨狀態開始。
    accountLockController.setLocked(false);
    UserService.clearCache();
  });

  tearDown(() {
    restoreHttp();
    accountLockController.setLocked(false);
    UserService.clearCache();
  });

  testWidgets('顯示剩餘天數與預定刪除日期', (tester) async {
    final purgeAt = DateTime.now().add(const Duration(days: 30));
    installMockClient({
      '/api/account/status': {
        'status': 'pending_deletion',
        'purge_at': purgeAt.toIso8601String(),
      },
    });

    await tester.pumpWidget(_app(AccountPendingScreen(purgeAt: purgeAt)));
    await tester.pumpAndSettle();

    expect(find.textContaining('天永久刪除'), findsOneWidget);
    expect(find.textContaining('預定刪除日期'), findsOneWidget);
    expect(find.text('重新啟用帳號'), findsOneWidget);
    expect(find.text('維持刪除並登出'), findsOneWidget);
  });

  testWidgets('沒有 purge_at 時不顯示日期，改顯示通用標題', (tester) async {
    installMockClient({
      '/api/account/status': {'status': 'pending_deletion'},
    });

    await tester.pumpWidget(_app(const AccountPendingScreen()));
    await tester.pumpAndSettle();

    expect(find.text('你的帳號已排定永久刪除'), findsOneWidget);
    expect(find.textContaining('預定刪除日期'), findsNothing);
  });

  testWidgets('後端回報已不在刪除中（別台裝置已復原）時自動導回主畫面', (tester) async {
    installMockClient({
      '/api/account/status': {'status': 'active'},
    });

    await tester.pumpWidget(_app(const AccountPendingScreen()));
    await tester.pumpAndSettle();

    expect(find.text('HOME'), findsOneWidget);
    expect(accountLockController.locked, isFalse);
  });

  testWidgets('別台裝置復原且帳號仍被鎖定時，導回主畫面並進入唯讀模式', (tester) async {
    installMockClient({
      '/api/account/status': {'status': 'locked'},
    });

    await tester.pumpWidget(_app(const AccountPendingScreen()));
    await tester.pumpAndSettle();

    expect(find.text('HOME'), findsOneWidget);
    expect(accountLockController.locked, isTrue);
  });

  testWidgets('重新啟用成功且資料已完善 → 導向主畫面', (tester) async {
    installMockClient({
      '/api/account/status': {'status': 'pending_deletion'},
      '/api/account/reactivate': {'status': 'active'},
      '/api/me': _me(),
    });

    await tester.pumpWidget(_app(const AccountPendingScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('重新啟用帳號'));
    await tester.pumpAndSettle();

    expect(find.text('HOME'), findsOneWidget);
    expect(accountLockController.locked, isFalse);
    expect(find.text('帳號已重新啟用，歡迎回來'), findsOneWidget);
  });

  testWidgets('重新啟用後資料尚未完善 → 導向完善資料', (tester) async {
    installMockClient({
      '/api/account/status': {'status': 'pending_deletion'},
      '/api/account/reactivate': {'status': 'active'},
      '/api/me': _me(profileCompleted: false),
    });

    await tester.pumpWidget(_app(const AccountPendingScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('重新啟用帳號'));
    await tester.pumpAndSettle();

    expect(find.text('COMPLETE'), findsOneWidget);
  });

  testWidgets('刪除前就被鎖定的帳號復原後維持唯讀，提示文案不同', (tester) async {
    installMockClient({
      '/api/account/status': {'status': 'pending_deletion'},
      '/api/account/reactivate': {'status': 'locked'},
      '/api/me': _me(),
    });

    await tester.pumpWidget(_app(const AccountPendingScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('重新啟用帳號'));
    await tester.pumpAndSettle();

    expect(accountLockController.locked, isTrue);
    expect(find.text('帳號已重新啟用，目前為唯讀狀態'), findsOneWidget);
  });

  testWidgets('重新啟用失敗時留在原畫面並顯示後端錯誤訊息', (tester) async {
    installMockClient({
      '/api/account/status': jsonResponse({'status': 'pending_deletion'}),
      '/api/account/reactivate': errorResponse(
        'REACTIVATE_FAILED',
        status: 400,
        message: '無法重新啟用',
      ),
    });

    await tester.pumpWidget(_app(const AccountPendingScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('重新啟用帳號'));
    await tester.pumpAndSettle();

    expect(find.text('HOME'), findsNothing);
    expect(find.text('無法重新啟用'), findsOneWidget);
    // 失敗後按鈕要恢復可按，否則使用者卡死在轉圈圈。
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('查詢狀態失敗時沿用登入帶來的天數，不把使用者丟出畫面', (tester) async {
    final purgeAt = DateTime.now().add(const Duration(days: 10));
    installMockClient({
      '/api/account/status': errorResponse('SERVER_ERROR', status: 500),
    });

    await tester.pumpWidget(_app(AccountPendingScreen(purgeAt: purgeAt)));
    await tester.pumpAndSettle();

    expect(find.textContaining('天永久刪除'), findsOneWidget);
    expect(find.text('HOME'), findsNothing);
  });
}
