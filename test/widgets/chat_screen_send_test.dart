// 聊天室送出：送出請求還在路上時重連補抓先拿到同一則，回應回來後畫面上只有一則。

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/screens/chat/chat_screen.dart';
import 'package:flutter_application_1/services/chat_socket_service.dart';

import '../helpers/flow_test_helpers.dart';
import '../helpers/widget_test_helpers.dart';

const _path = '/api/friends/BBBB2345/messages';

Map<String, dynamic> _message(int id, String body, {bool mine = true}) => {
  'id': id,
  'body': body,
  'created_at': '2026-09-29T03:0${id % 10}:00Z',
  'read_at': null,
  'mine': mine,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 伺服器目前有的訊息（新到舊），GET 照它回。
  late List<Map<String, dynamic>> serverMessages;

  /// 不為 null 時 POST 等它完成才回應，用來卡住送出請求。
  Completer<void>? holdPost;

  setUp(() {
    stubCommonChannels();
    serverMessages = [_message(10, '舊訊息', mine: false)];
    holdPost = null;
    ApiClient.httpClient = MockClient((request) async {
      final path = request.url.path;
      if (path == '$_path/read') return jsonResponse({'ok': true, 'marked': 0});
      if (path == _path && request.method == 'GET') {
        return jsonResponse({
          'messages': serverMessages,
          'page_info': {'next_cursor': null, 'has_more': false},
        });
      }
      if (path == _path && request.method == 'POST') {
        final body = (jsonDecode(request.body) as Map)['body'] as String;
        final sent = _message(11, body);
        // 後端寫入後才回應：這段期間別的請求已經查得到這一則。
        serverMessages = [sent, ...serverMessages];
        await holdPost?.future;
        return jsonResponse({'message': sent}, status: 201);
      }
      return http.Response('{"error":{"code":"NOT_FOUND"}}', 404);
    });
  });
  tearDown(() {
    chatController.disconnect();
    restoreHttp();
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      wrapScreen(const ChatScreen(friendCode: 'BBBB2345')),
    );
    await pumpFrames(tester);
  }

  Future<void> send(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();
  }

  testWidgets('送出回應前補抓先拿到同一則：回應回來後只有一則，輸入框清空', (tester) async {
    await open(tester);
    holdPost = Completer<void>();

    await send(tester, '你好');
    // 送出途中重連，補抓拿到剛寫入的那一則。
    chatController.debugSimulateData(jsonEncode({'type': 'connected'}));
    await pumpFrames(tester);
    expect(find.text('你好'), findsNWidgets(2)); // 補抓的一則＋輸入框裡的字

    holdPost!.complete();
    await pumpFrames(tester);

    expect(find.text('你好'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
  });

  testWidgets('一般送出：插在最上方，輸入框清空', (tester) async {
    await open(tester);

    await send(tester, '晚安');
    await pumpFrames(tester);

    expect(find.text('晚安'), findsOneWidget);
    expect(find.text('舊訊息'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    // 新訊息插在清單最前面；列表反向顯示，所以畫在最下面貼著輸入列。
    expect(
      tester.getTopLeft(find.text('晚安')).dy,
      greaterThan(tester.getTopLeft(find.text('舊訊息')).dy),
    );
  });
}
