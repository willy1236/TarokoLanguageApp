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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => accountLockController.setLocked(false));

  group('AccountLockController', () {
    test('預設非唯讀', () {
      expect(accountLockController.locked, isFalse);
    });

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

  group('blockIfReadOnly', () {
    testWidgets('非唯讀時放行，不顯示提示', (tester) async {
      accountLockController.setLocked(false);
      await tester.pumpWidget(MaterialApp(
        scaffoldMessengerKey: scaffoldMessengerKey,
        home: const Scaffold(body: SizedBox()),
      ));

      expect(blockIfReadOnly(), isFalse);
      await tester.pump();
      expect(find.text(readOnlyMessage), findsNothing);
    });

    testWidgets('唯讀時攔下動作並顯示統一提示', (tester) async {
      accountLockController.setLocked(true);
      await tester.pumpWidget(MaterialApp(
        scaffoldMessengerKey: scaffoldMessengerKey,
        home: const Scaffold(body: SizedBox()),
      ));

      expect(blockIfReadOnly(), isTrue);
      await tester.pump();
      expect(find.text(readOnlyMessage), findsOneWidget);
    });

    testWidgets('連續觸發只留一則提示，不會疊一整排', (tester) async {
      accountLockController.setLocked(true);
      await tester.pumpWidget(MaterialApp(
        scaffoldMessengerKey: scaffoldMessengerKey,
        home: const Scaffold(body: SizedBox()),
      ));

      blockIfReadOnly();
      blockIfReadOnly();
      blockIfReadOnly();
      await tester.pump();

      expect(find.text(readOnlyMessage), findsOneWidget);
    });

    testWidgets('提示文案不透露封鎖原因（後端刻意不揭露）', (tester) async {
      expect(readOnlyMessage, isNot(contains('原因')));
      expect(readOnlyMessage, isNot(contains('違規')));
      expect(readOnlyMessage, contains('唯讀'));
    });
  });
}
