// 聊天室的通話紀錄：與訊息混排、只有通話也不顯示空狀態，點泡泡走視訊鈕的回撥流程，
// 長按不檢舉。

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/screens/chat/chat_screen.dart';
import 'package:flutter_application_1/services/chat_socket_service.dart';

import '../helpers/flow_test_helpers.dart';
import '../helpers/widget_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(stubCommonChannels);
  tearDown(() {
    chatController.disconnect();
    restoreHttp();
  });

  Future<void> open(
    WidgetTester tester, {
    List<Map<String, dynamic>> messages = const [],
    bool unavailable = false,
  }) async {
    installMockClient({
      '/api/friends/BBBB2345/messages': {
        'partner': {
          'nickname': '阿華',
          'friend_code': 'BBBB2345',
          'unavailable': unavailable,
        },
        'messages': messages,
        'calls': [
          {
            'id': 123,
            'kind': 'completed',
            'mine': true,
            'created_at': '2026-10-12T06:00:00Z',
            'duration_sec': 332,
            'is_unread': false,
          },
          {
            'id': 120,
            'kind': 'missed',
            'mine': false,
            'created_at': '2026-10-12T05:00:00Z',
            'duration_sec': null,
            'is_unread': true,
          },
        ],
        'page_info': {'next_cursor': null, 'has_more': false},
      },
      '/api/friends/BBBB2345/messages/read': {
        'ok': true,
        'marked': 0,
        'calls_marked': 0,
      },
    });
    await tester.pumpWidget(
      wrapScreen(const ChatScreen(friendCode: 'BBBB2345')),
    );
    await pumpFrames(tester);
  }

  testWidgets('只有通話沒有訊息：顯示通話泡泡與時間，不顯示空狀態', (tester) async {
    await open(tester);

    expect(find.text('還沒有訊息'), findsNothing);
    expect(find.text('視訊通話 05:32'), findsOneWidget);
    expect(find.text('未接視訊通話'), findsOneWidget);
    // 06:00Z、05:00Z 是台灣 14:00、13:00。
    expect(find.text('14:00'), findsOneWidget);
    expect(find.text('13:00'), findsOneWidget);
  });

  testWidgets('通話與訊息依時間混排', (tester) async {
    await open(
      tester,
      messages: [
        {
          'id': 7,
          'body': '剛剛沒接到',
          'created_at': '2026-10-12T05:30:00Z',
          'read_at': null,
          'mine': false,
        },
      ],
    );

    final missed = tester.getCenter(find.text('未接視訊通話')).dy;
    final message = tester.getCenter(find.text('剛剛沒接到')).dy;
    final completed = tester.getCenter(find.text('視訊通話 05:32')).dy;
    expect(missed, lessThan(message));
    expect(message, lessThan(completed));
  });

  testWidgets('點通話泡泡走視訊鈕同一個流程：對方無法使用時一樣擋下提示', (tester) async {
    await open(tester, unavailable: true);

    await tester.tap(find.text('未接視訊通話'));
    await tester.pump();
    expect(find.text('對方暫時無法使用，無法通話'), findsOneWidget);
  });

  testWidgets('長按通話泡泡不跳檢舉', (tester) async {
    await open(tester);

    await tester.longPress(find.text('未接視訊通話'));
    await pumpFrames(tester);
    expect(find.text('檢舉此訊息'), findsNothing);
  });
}
