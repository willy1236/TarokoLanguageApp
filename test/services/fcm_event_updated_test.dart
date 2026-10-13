// event_updated 推播（發起人改了地點、地址或提醒事項）的解析與點擊、前景處理。
// payload 依 前端待辦 2026-10-11 手寫：後端送 data { type, event_id }，
// 標題與內文在 notification。

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/main.dart' show scaffoldMessengerKey;
import 'package:flutter_application_1/services/fcm_service.dart';

import '../helpers/widget_test_helpers.dart';

RemoteMessage _updatedMessage({Object? eventId = 7}) => RemoteMessage(
  data: {'type': 'event_updated', 'event_id': ?eventId?.toString()},
  notification: const RemoteNotification(
    title: '活動有更新',
    body: '豐年祭的集合地點改了',
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('parseReminderPayload', () {
    test('event_updated 取出 event_id', () {
      expect(
        FcmService.parseReminderPayload({
          'type': 'event_updated',
          'event_id': '7',
        }),
        ('event_updated', 7),
      );
    });

    test('event_id 壞掉時 eventId 為 null，不丟例外', () {
      expect(
        FcmService.parseReminderPayload({'type': 'event_updated'}),
        ('event_updated', null),
      );
    });

    test('既有的 event_reminder／event_cancelled 照舊，其他類型不算', () {
      for (final type in ['event_reminder', 'event_cancelled']) {
        expect(
          FcmService.parseReminderPayload({'type': type, 'event_id': '3'}),
          (type, 3),
        );
      }
      expect(
        FcmService.parseReminderPayload({
          'type': 'event_deleted',
          'event_id': '3',
        }),
        isNull,
      );
    });
  });

  group('點擊通知（背景／冷啟動）', () {
    tearDown(() => FcmService.onReminderTapped = null);

    test('開該活動詳情', () {
      final opened = <int?>[];
      FcmService.onReminderTapped = opened.add;

      FcmService.handleOpenedMessage(_updatedMessage());

      expect(opened, [7]);
    });
  });

  group('前景收到', () {
    setUp(() {
      // 本機通知外掛在測試環境沒有原生端：註冊 Android 實作，channel 由 stub 吞掉。
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      stubChannel('dexterous.com/flutter/local_notifications');
    });

    testWidgets('SnackBar 顯示推播內文，按「查看」開該活動詳情', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          scaffoldMessengerKey: scaffoldMessengerKey,
          home: const Scaffold(body: SizedBox()),
        ),
      );
      final opened = <int?>[];
      FcmService.onReminderTapped = opened.add;
      addTearDown(() => FcmService.onReminderTapped = null);

      FcmService.handleForegroundMessage(_updatedMessage());
      await tester.pumpAndSettle(); // 等 SnackBar 滑入完，「查看」才點得到

      expect(find.text('豐年祭的集合地點改了'), findsOneWidget);
      await tester.tap(find.text('查看'));
      expect(opened, [7]);
    });

    testWidgets('event_id 缺失時照樣提示、不閃退，也沒有「查看」', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          scaffoldMessengerKey: scaffoldMessengerKey,
          home: const Scaffold(body: SizedBox()),
        ),
      );

      FcmService.handleForegroundMessage(_updatedMessage(eventId: null));
      await tester.pump();

      expect(find.text('豐年祭的集合地點改了'), findsOneWidget);
      expect(find.text('查看'), findsNothing);
    });
  });
}
