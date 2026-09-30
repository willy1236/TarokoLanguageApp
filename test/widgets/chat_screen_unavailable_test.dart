// 聊天室對象暫時無法使用（刪除中或被鎖）：歷史照常顯示，輸入列停用。
// 不論從哪個入口進來，都以歷史訊息回應的 partner.unavailable 為準。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/screens/chat/chat_screen.dart';
import 'package:flutter_application_1/services/chat_socket_service.dart';

import '../helpers/fixtures.dart';
import '../helpers/flow_test_helpers.dart';
import '../helpers/widget_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(stubCommonChannels);
  tearDown(() {
    chatController.disconnect();
    restoreHttp();
  });

  Future<void> open(WidgetTester tester, Map<String, dynamic> history) async {
    installMockClient({
      '/api/friends/CCCC2345/messages': history,
      '/api/friends/CCCC2345/messages/read': {'ok': true, 'marked': 0},
    });
    await tester.pumpWidget(
      wrapScreen(
        // 從好友列表、公開個人頁進來時帶的是舊的暱稱。
        const ChatScreen(friendCode: 'CCCC2345', partnerNickname: '阿華'),
      ),
    );
    await pumpFrames(tester);
  }

  IconButton sendButton(WidgetTester tester) =>
      tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.send));

  testWidgets('對象暫時無法使用：歷史照常顯示，輸入框與送出鈕停用並提示', (tester) async {
    await open(
      tester,
      loadSpecFixtureMap('get_api_friend_messages_unavailable.json'),
    );

    expect(find.text('在嗎'), findsOneWidget);
    expect(find.text('暫時無法使用'), findsOneWidget);
    expect(find.textContaining('阿華', findRichText: true), findsNothing);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    expect(find.text('對方暫時無法使用，無法傳送訊息'), findsOneWidget);
    expect(sendButton(tester).onPressed, isNull);
  });

  testWidgets('對象正常：輸入框可用', (tester) async {
    final history = loadSpecFixtureMap(
      'get_api_friend_messages_unavailable.json',
    );
    (history['partner'] as Map<String, dynamic>)
      ..['unavailable'] = false
      ..['nickname'] = '阿華';
    await open(tester, history);

    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
    expect(find.text('傳送訊息…'), findsOneWidget);
    expect(sendButton(tester).onPressed, isNotNull);
  });
}
