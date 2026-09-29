// event_deleted 推播（報名的活動被發起人刪除）的解析、監聽與點擊處理。
// payload 依 前端待辦 §A1 手寫：後端一次送 data { type, event_id }，
// 說明文字在 notification 的 title／body。

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/main.dart' show scaffoldMessengerKey;
import 'package:flutter_application_1/services/fcm_service.dart';

import '../helpers/widget_test_helpers.dart';

RemoteMessage _deletedMessage({
  Object? eventId = 7,
  String? body = '您參加的豐年祭已被發起人刪除',
}) => RemoteMessage(
  data: {'type': 'event_deleted', 'event_id': ?eventId?.toString()},
  notification: RemoteNotification(title: '活動已刪除', body: body),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('parseEventDeleted', () {
    test('取 event_id 與通知 title／body', () {
      final notice = FcmService.parseEventDeleted(
        {'type': 'event_deleted', 'event_id': '7'},
        title: '活動已刪除',
        body: '您參加的豐年祭已被發起人刪除',
      );
      expect(notice, isNotNull);
      expect(notice!.eventId, 7);
      expect(notice.title, '活動已刪除');
      expect(notice.body, '您參加的豐年祭已被發起人刪除');
    });

    test('沒有 notification 文字時給預設值，event_id 壞掉時為 null', () {
      final notice = FcmService.parseEventDeleted({
        'type': 'event_deleted',
        'event_id': 'abc',
      });
      expect(notice!.eventId, isNull);
      expect(notice.title, '活動已刪除');
      expect(notice.body, isEmpty);
    });

    test('event_reminder／event_cancelled 不算', () {
      for (final type in ['event_reminder', 'event_cancelled']) {
        expect(
          FcmService.parseEventDeleted({'type': type, 'event_id': '7'}),
          isNull,
        );
      }
    });
  });

  group('監聽', () {
    test('多個畫面同時登記都收得到，移除後不再收到', () {
      final a = <int?>[];
      final b = <int?>[];
      FcmService.addEventDeletedListener(a.add);
      FcmService.addEventDeletedListener(b.add);

      FcmService.dispatchEventDeleted(7);
      FcmService.removeEventDeletedListener(a.add);
      FcmService.dispatchEventDeleted(8);
      FcmService.removeEventDeletedListener(b.add);

      expect(a, [7]);
      expect(b, [7, 8]);
    });

    test('通知途中有人移除自己不會出錯', () {
      late void Function(int?) self;
      var calls = 0;
      self = (_) {
        calls++;
        FcmService.removeEventDeletedListener(self);
      };
      FcmService.addEventDeletedListener(self);

      FcmService.dispatchEventDeleted(1);
      FcmService.dispatchEventDeleted(1);

      expect(calls, 1);
    });
  });

  group('點擊通知（背景／冷啟動）', () {
    tearDown(() => FcmService.onEventDeletedTapped = null);

    test('回呼收到推播內文，且不導到活動詳情', () {
      final messages = <String>[];
      final openedEvents = <int?>[];
      FcmService.onEventDeletedTapped = messages.add;
      FcmService.onReminderTapped = openedEvents.add;
      addTearDown(() => FcmService.onReminderTapped = null);

      FcmService.handleOpenedMessage(_deletedMessage());

      expect(messages, ['您參加的豐年祭已被發起人刪除']);
      expect(openedEvents, isEmpty);
    });

    test('推播沒帶內文時用預設說明', () {
      final messages = <String>[];
      FcmService.onEventDeletedTapped = messages.add;

      FcmService.handleOpenedMessage(_deletedMessage(body: null));

      expect(messages, ['您參加的活動已被發起人刪除']);
    });
  });

  group('前景收到', () {
    setUp(() {
      // 本機通知外掛在測試環境沒有原生端：註冊 Android 實作，channel 由 stub 吞掉。
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      stubChannel('dexterous.com/flutter/local_notifications');
    });

    testWidgets('SnackBar 顯示內文、沒有「查看」，並通知登記的畫面', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          scaffoldMessengerKey: scaffoldMessengerKey,
          home: const Scaffold(body: SizedBox()),
        ),
      );
      final received = <int?>[];
      FcmService.addEventDeletedListener(received.add);
      addTearDown(() => FcmService.removeEventDeletedListener(received.add));

      FcmService.handleForegroundMessage(_deletedMessage());
      await tester.pump();

      expect(find.text('您參加的豐年祭已被發起人刪除'), findsOneWidget);
      expect(find.text('查看'), findsNothing);
      expect(received, [7]);
    });
  });
}
