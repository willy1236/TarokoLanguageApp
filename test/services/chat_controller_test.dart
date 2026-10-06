// ChatController 的連線狀態機：登出時的重設、重連間隔，以及 4003 導去條款頁。
//
// 不真的連 WebSocket：用 debugSimulateClosed 模擬斷線，只驗狀態。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/main.dart' show navigatorKey;
import 'package:flutter_application_1/services/chat_socket_service.dart';

import '../helpers/widget_test_helpers.dart';

void main() {
  group('4003 未同意條款', () {
    setUp(stubCommonChannels);
    tearDown(restoreHttp);

    testWidgets('即時連線 4003 與 REST CONSENT_REQUIRED 同時發生：只疊一層條款頁', (
      tester,
    ) async {
      final controller = ChatController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          routes: {
            '/': (_) => const Text('home'),
            '/terms-consent': (_) => const Text('consent'),
          },
        ),
      );
      ApiClient.httpClient = MockClient(
        (_) async => http.Response(
          '{"error":{"code":"CONSENT_REQUIRED","message":"x"}}',
          403,
        ),
      );

      controller.debugSimulateClosed(4003, 'consent required');
      await tester.runAsync(() async {
        await expectLater(
          ApiClient.get('/api/me'),
          throwsA(isA<ApiException>()),
        );
      });
      await tester.pumpAndSettle();

      expect(find.text('consent', skipOffstage: false), findsOneWidget);
      // 4003 不重連：同意後由首頁重新 connect。
      expect(controller.hasPendingReconnect, isFalse);

      // 關掉之後再收到 4003 仍會再開。
      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      controller.debugSimulateClosed(4003, 'consent required');
      await tester.pumpAndSettle();
      expect(find.text('consent'), findsOneWidget);
    });
  });

  group('ChatController.disconnect', () {
    test('重設重連次數、待重連計時器與 lastEvent', () {
      final controller = ChatController();
      addTearDown(controller.dispose);

      controller.debugSimulateClosed(1006, null);
      controller.debugSimulateClosed(1006, null);
      controller.lastEvent = ChatSocketEvent.connected();
      expect(controller.reconnectAttempts, 2);
      expect(controller.hasPendingReconnect, isTrue);

      controller.disconnect();

      expect(controller.reconnectAttempts, 0);
      expect(controller.hasPendingReconnect, isFalse);
      expect(controller.lastEvent, isNull);
      expect(controller.isConnected, isFalse);
    });
  });

  group('通話事件', () {
    test('從 callEvents 送出、不動 lastEvent；連續兩則都收得到', () async {
      final controller = ChatController();
      addTearDown(controller.dispose);
      final received = <Map<String, String>>[];
      final sub = controller.callEvents.listen(received.add);
      addTearDown(sub.cancel);
      var notified = 0;
      controller.addListener(() => notified++);

      controller.debugSimulateData(
        '{"type":"friend_call_accepted","call_id":"12","session_id":"34"}',
      );
      controller.debugSimulateData(
        '{"type":"video_session_ended","session_id":"34"}',
      );
      await Future<void>.delayed(Duration.zero);

      expect(received, [
        {'type': 'friend_call_accepted', 'call_id': '12', 'session_id': '34'},
        {'type': 'video_session_ended', 'session_id': '34'},
      ]);
      expect(controller.lastEvent, isNull);
      expect(notified, 0);
    });
  });

  group('ChatController.reconnectDelaySeconds', () {
    test('前幾次指數成長', () {
      expect(ChatController.reconnectDelaySeconds(1), 2);
      expect(ChatController.reconnectDelaySeconds(4), 16);
    });

    test('次數 5、63、100 時都是 30 秒，不會溢位成零間隔', () {
      for (final attempts in [5, 63, 100]) {
        expect(ChatController.reconnectDelaySeconds(attempts), 30);
      }
    });
  });
}
