// ChatController 的連線狀態機：登出時的重設，以及重連間隔。
//
// 不真的連 WebSocket：用 debugSimulateClosed 模擬斷線，只驗狀態。

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/services/chat_socket_service.dart';

void main() {
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
