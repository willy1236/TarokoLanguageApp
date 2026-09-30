// 帳號唯讀（moderation 鎖帳號）共用機制的測試。
//
// 全 app 有二十幾處寫入動作靠 blockIfReadOnly() 把關（論壇發文/按讚、活動報名、
// 聊天送出、影音按讚…）。人工要驗證得先請後端把測試帳號鎖起來，再一頁一頁點過去。
// 這裡先把機制本身釘住；各畫面有沒有接上，由該畫面自己的測試負責
// （例如 test/widgets/event_action_bar_test.dart）。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/main.dart' show scaffoldMessengerKey;
import 'package:flutter_application_1/services/account_lock_controller.dart';

import '../helpers/widget_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => accountLockController.setLocked(false));

  group('AccountLockController', () {
    test('狀態改變時通知監聽者', () {
      var notified = 0;
      void listener() => notified++;
      accountLockController.addListener(listener);
      addTearDown(() => accountLockController.removeListener(listener));

      accountLockController.setLocked(true);
      expect(accountLockController.locked, isTrue);
      expect(notified, 1);

      // 設成同一個值不該再通知——否則每次 API 回應都會讓整頁重建。
      accountLockController.setLocked(true);
      expect(notified, 1);

      accountLockController.setLocked(false);
      expect(notified, 2);
    });
  });

  group('applyModerationPush', () {
    test('account_unlocked 解除唯讀', () {
      accountLockController.setLocked(true);

      final result = accountLockController.applyModerationPush({
        'type': 'moderation',
        'action': 'account_unlocked',
      });

      expect(result, isFalse);
      expect(accountLockController.locked, isFalse);
    });

    test('申訴成立且解除停權（appeal_accepted 帶 account_unlocked: "true"）解除唯讀', () {
      accountLockController.setLocked(true);

      final result = accountLockController.applyModerationPush({
        'type': 'moderation',
        'action': 'appeal_accepted',
        'case_id': '31',
        'account_unlocked': 'true',
      });

      expect(result, isFalse);
      expect(accountLockController.locked, isFalse);
    });

    test('申訴成立但沒有解除停權、申訴駁回：不動唯讀狀態', () {
      accountLockController.setLocked(true);

      expect(
        accountLockController.applyModerationPush({
          'type': 'moderation',
          'action': 'appeal_accepted',
          'case_id': '31',
        }),
        isNull,
      );
      expect(
        accountLockController.applyModerationPush({
          'type': 'moderation',
          'action': 'appeal_rejected',
          'case_id': '31',
        }),
        isNull,
      );
      expect(accountLockController.locked, isTrue);
    });

    test('locked: "true" 設為唯讀', () {
      final result = accountLockController.applyModerationPush({
        'type': 'moderation',
        'action': 'case_confirmed',
        'locked': 'true',
      });

      expect(result, isTrue);
      expect(accountLockController.locked, isTrue);
    });

    test('mute_lifted 等其他處置不動唯讀狀態', () {
      accountLockController.setLocked(true);

      final result = accountLockController.applyModerationPush({
        'type': 'moderation',
        'action': 'mute_lifted',
      });

      expect(result, isNull);
      expect(accountLockController.locked, isTrue);
    });
  });

  group('refreshIfLocked', () {
    late int requests;

    setUp(() {
      stubCommonChannels();
      requests = 0;
    });
    tearDown(restoreHttp);

    void respondWith(Object? route) => installMockClient({
      '/api/account/status': route,
    }, onRequest: (_) => requests++);

    test('非唯讀時不打請求', () async {
      respondWith({'status': 'active'});

      await accountLockController.refreshIfLocked();

      expect(requests, 0);
      expect(accountLockController.locked, isFalse);
    });

    test('唯讀中查到 active 就解除唯讀', () async {
      accountLockController.setLocked(true);
      respondWith({'status': 'active'});

      await accountLockController.refreshIfLocked();

      expect(requests, 1);
      expect(accountLockController.locked, isFalse);
    });

    test('仍是 locked 維持唯讀', () async {
      accountLockController.setLocked(true);
      respondWith({'status': 'locked'});

      await accountLockController.refreshIfLocked();

      expect(accountLockController.locked, isTrue);
    });

    test('查詢失敗維持唯讀、不丟例外', () async {
      accountLockController.setLocked(true);
      respondWith(errorResponse('INTERNAL_ERROR', status: 500));

      await accountLockController.refreshIfLocked();

      expect(accountLockController.locked, isTrue);
    });
  });

  group('blockIfReadOnly', () {
    testWidgets('非唯讀時放行，不顯示提示', (tester) async {
      accountLockController.setLocked(false);
      await tester.pumpWidget(
        MaterialApp(
          scaffoldMessengerKey: scaffoldMessengerKey,
          home: const Scaffold(body: SizedBox()),
        ),
      );

      expect(blockIfReadOnly(), isFalse);
      await tester.pump();
      expect(find.text(readOnlyMessage), findsNothing);
    });

    testWidgets('唯讀時攔下動作並顯示統一提示', (tester) async {
      accountLockController.setLocked(true);
      await tester.pumpWidget(
        MaterialApp(
          scaffoldMessengerKey: scaffoldMessengerKey,
          home: const Scaffold(body: SizedBox()),
        ),
      );

      expect(blockIfReadOnly(), isTrue);
      await tester.pump();
      expect(find.text(readOnlyMessage), findsOneWidget);
    });

    testWidgets('連續觸發只留一則提示，不會疊一整排', (tester) async {
      accountLockController.setLocked(true);
      await tester.pumpWidget(
        MaterialApp(
          scaffoldMessengerKey: scaffoldMessengerKey,
          home: const Scaffold(body: SizedBox()),
        ),
      );

      blockIfReadOnly();
      blockIfReadOnly();
      blockIfReadOnly();
      await tester.pump();

      expect(find.text(readOnlyMessage), findsOneWidget);
    });
  });
}
