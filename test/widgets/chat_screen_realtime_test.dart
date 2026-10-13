// 聊天室的即時事件：只處理這個聊天室對象的事件（以好友碼辨識），已讀只標我傳的訊息。

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/utils/date_format.dart';
import 'package:flutter_application_1/screens/chat/chat_screen.dart';
import 'package:flutter_application_1/services/chat_socket_service.dart';

import '../helpers/flow_test_helpers.dart';
import '../helpers/widget_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    stubCommonChannels();
    installMockClient({
      '/api/friends/BBBB2345/messages': {
        'messages': [
          {
            'id': 16,
            'body': '我傳的',
            'created_at': '2026-09-29T03:01:00Z',
            'read_at': null,
            'mine': true,
          },
          {
            'id': 15,
            'body': '對方傳的',
            'created_at': '2026-09-29T03:00:00Z',
            'read_at': '2026-09-29T03:00:30Z',
            'mine': false,
          },
          {
            'id': 14,
            'body': '我先前傳的',
            'created_at': '2026-09-28T15:59:00Z',
            'read_at': '2026-09-29T02:00:00Z',
            'mine': true,
          },
        ],
        'page_info': {'next_cursor': null, 'has_more': false},
      },
      '/api/friends/BBBB2345/messages/read': {'ok': true, 'marked': 0},
    });
  });
  tearDown(() {
    chatController.disconnect();
    restoreHttp();
  });

  void emit(Map<String, dynamic> event) =>
      chatController.debugSimulateData(jsonEncode(event));

  Map<String, dynamic> message(int id, String body, String from) => {
    'type': 'message',
    'message': {
      'id': id,
      'body': body,
      'created_at': '2026-09-29T03:05:00Z',
      'read_at': null,
      'mine': false,
    },
    'from_friend_code': from,
  };

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      wrapScreen(const ChatScreen(friendCode: 'BBBB2345')),
    );
    await pumpFrames(tester);
  }

  testWidgets('每則訊息旁有本地時間；跨日插日期分隔，已到最早時最舊一則上方也有', (tester) async {
    await open(tester);

    // 03:01Z、03:00Z 是台灣 11:01、11:00；15:59Z 是 9/28 的 23:59。
    expect(find.text('11:01'), findsOneWidget);
    expect(find.text('11:00'), findsOneWidget);
    expect(find.text('23:59'), findsOneWidget);
    expect(
      find.text(chatDayLabel(DateTime.utc(2026, 9, 29, 3))),
      findsOneWidget,
    );
    expect(
      find.text(chatDayLabel(DateTime.utc(2026, 9, 28, 15, 59))),
      findsOneWidget,
    );
  });

  testWidgets('別人的已讀與訊息不影響這個聊天室；未讀的不顯示「已送出」', (tester) async {
    await open(tester);
    expect(find.text('已讀'), findsOneWidget);
    expect(find.text('已送出'), findsNothing);

    emit({'type': 'read', 'by_friend_code': 'CCCC2345', 'count': 1});
    emit(message(20, '別人的訊息', 'CCCC2345'));
    await pumpFrames(tester);

    expect(find.text('已讀'), findsOneWidget);
    expect(find.text('別人的訊息'), findsNothing);
  });

  testWidgets('這位對象的已讀讓我每一則都顯示已讀，對方的不標；訊息接到最下面', (tester) async {
    await open(tester);

    emit({'type': 'read', 'by_friend_code': 'bbbb2345', 'count': 1});
    await pumpFrames(tester);
    expect(find.text('已讀'), findsNWidgets(2));

    emit(message(21, '晚安', 'BBBB2345'));
    await pumpFrames(tester);
    expect(find.text('晚安'), findsOneWidget);
  });
}
