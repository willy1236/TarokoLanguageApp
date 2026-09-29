// 發送提醒表單的「發送時間不能晚於活動結束」。
// 選時間流程：點「指定時間」→ 日期選擇器（按確定）→ 時間選擇器（按確定）。
// 日期選擇器預設日與時間選擇器預設時間都由畫面決定，測試不需輸入。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/main.dart' show scaffoldMessengerKey;
import 'package:flutter_application_1/screens/events/reminder_compose_screen.dart';

import '../helpers/flow_test_helpers.dart';
import '../helpers/widget_test_helpers.dart';

Widget _app(DateTime? endsAt) => MaterialApp(
  scaffoldMessengerKey: scaffoldMessengerKey,
  home: ReminderComposeScreen(
    eventId: 1,
    eventTitle: '豐年祭',
    eventEndsAt: endsAt,
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(stubCommonChannels);
  tearDown(restoreHttp);

  group('sendTimeAfterEndError', () {
    final end = DateTime(2026, 12, 1, 18, 5);

    test('晚於結束時間：回傳含結束時間的說明', () {
      expect(
        ReminderComposeScreen.sendTimeAfterEndError(
          DateTime(2026, 12, 1, 18, 6),
          end,
        ),
        '發送時間不能晚於活動結束（2026/12/01  18:05）',
      );
    });

    test('等於或早於結束時間：通過', () {
      expect(ReminderComposeScreen.sendTimeAfterEndError(end, end), isNull);
      expect(
        ReminderComposeScreen.sendTimeAfterEndError(
          DateTime(2026, 11, 30),
          end,
        ),
        isNull,
      );
    });

    test('沒有結束時間（舊資料）：不限制', () {
      expect(
        ReminderComposeScreen.sendTimeAfterEndError(DateTime(2099), null),
        isNull,
      );
    });
  });

  group('選擇發送時間', () {
    Future<void> openPicker(WidgetTester tester) async {
      usePhoneSurface(tester);
      await tester.tap(find.text('指定時間'));
      await tester.pumpAndSettle();
    }

    Future<void> confirmDialog(WidgetTester tester) async {
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
    }

    testWidgets('日期選擇器最晚只到活動結束當天', (tester) async {
      final endsAt = DateTime.now().add(const Duration(days: 3));
      await tester.pumpWidget(_app(endsAt));
      await openPicker(tester);

      final picker = tester.widget<CalendarDatePicker>(
        find.byType(CalendarDatePicker),
      );
      expect(picker.lastDate, DateUtils.dateOnly(endsAt));
    });

    testWidgets('沒有結束時間：日期選擇器維持一年內', (tester) async {
      await tester.pumpWidget(_app(null));
      await openPicker(tester);

      final picker = tester.widget<CalendarDatePicker>(
        find.byType(CalendarDatePicker),
      );
      final expected = DateUtils.dateOnly(
        DateTime.now().add(const Duration(days: 365)),
      );
      expect(picker.lastDate, expected);
    });

    testWidgets('活動已結束：不開選擇器，提示無法排定', (tester) async {
      final endsAt = DateTime.now().subtract(const Duration(hours: 1));
      await tester.pumpWidget(_app(endsAt));
      await openPicker(tester);

      expect(find.byType(CalendarDatePicker), findsNothing);
      expect(find.text('活動已結束，無法排定發送時間'), findsOneWidget);
    });

    testWidgets('選到活動結束之後的時間：提示並不採用', (tester) async {
      // 時間選擇器預設 1 小時後，活動 30 分鐘後結束 → 一定晚於結束。
      final now = DateTime.now();
      if (now.hour >= 23) {
        markTestSkipped('接近午夜時預設時間會跨日，結果不固定');
        return;
      }
      final endsAt = now.add(const Duration(minutes: 30));
      await tester.pumpWidget(_app(endsAt));
      await openPicker(tester);
      await confirmDialog(tester); // 日期
      await confirmDialog(tester); // 時間

      expect(find.textContaining('發送時間不能晚於活動結束'), findsOneWidget);
      // 沒被採用：沒有出現已選時間那一列
      expect(find.byIcon(Icons.event), findsNothing);
    });

    testWidgets('選到活動結束之前的時間：採用', (tester) async {
      final now = DateTime.now();
      if (now.hour >= 23) {
        markTestSkipped('接近午夜時預設時間會跨日，結果不固定');
        return;
      }
      final endsAt = now.add(const Duration(days: 2));
      await tester.pumpWidget(_app(endsAt));
      await openPicker(tester);
      await confirmDialog(tester);
      await confirmDialog(tester);

      expect(find.textContaining('發送時間不能晚於'), findsNothing);
      expect(find.byIcon(Icons.event), findsOneWidget);
    });
  });
}
