// 聊天室開著時通話紀錄的即時更新：疊在上面的畫面關掉回來、或停在聊天室時收到
// 好友通話事件，都重抓第一頁；有疊畫面時收到事件不抓，回來再抓。
// 關掉通話畫面時送出的取消請求要先到後端，才抓得到那一通。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_application_1/core/navigation/route_stack.dart';
import 'package:flutter_application_1/screens/chat/chat_screen.dart';
import 'package:flutter_application_1/services/chat_socket_service.dart';
import 'package:flutter_application_1/services/directed_call_service.dart';
import 'package:flutter_application_1/services/fcm_service.dart';

import '../helpers/flow_test_helpers.dart';
import '../helpers/widget_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> seen;

  setUp(() {
    stubCommonChannels();
    FcmService.resetHandledCallEvents();
    seen = [];
    installMockClient(
      {
        '/api/friends/BBBB2345/messages': {
          'messages': [],
          'calls': [],
          'page_info': {'next_cursor': null, 'has_more': false},
        },
        '/api/friends/BBBB2345/messages/read': {
          'ok': true,
          'marked': 0,
          'calls_marked': 0,
        },
        '/api/notifications/summary': {'total': 0},
        '/api/friends/calls/5/cancel': {'ok': true},
      },
      onRequest: (http.Request r) => seen.add(r.url.path),
      delayFor: (r) => r.url.path.endsWith('/cancel')
          ? const Duration(milliseconds: 300)
          : Duration.zero,
    );
  });
  tearDown(() {
    chatController.disconnect();
    restoreHttp();
  });

  int historyRequests() =>
      seen.where((p) => p == '/api/friends/BBBB2345/messages').length;

  Future<NavigatorState> open(WidgetTester tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        navigatorObservers: [routeObserver],
        home: const ChatScreen(friendCode: 'BBBB2345'),
      ),
    );
    await pumpFrames(tester);
    return navigatorKey.currentState!;
  }

  Route<void> overlay() => MaterialPageRoute<void>(
    builder: (_) => const Scaffold(body: Text('通話畫面')),
  );

  testWidgets('停在聊天室收到通話結束事件就重抓第一頁，紅點也重抓', (tester) async {
    await open(tester);
    expect(historyRequests(), 1);

    const event = {'type': 'friend_call_ended', 'call_id': '5'};
    FcmService.handleSocketCallEvent(event);
    await pumpFrames(tester);
    expect(historyRequests(), 2);
    expect(seen, contains('/api/notifications/summary'));
  });

  testWidgets('有疊畫面時收到事件不抓，關掉回到聊天室時抓', (tester) async {
    final navigator = await open(tester);
    navigator.push(overlay());
    await pumpFrames(tester);

    FcmService.handleSocketCallEvent({
      'type': 'friend_call_cancelled',
      'call_id': '6',
    });
    await pumpFrames(tester);
    expect(historyRequests(), 1);

    navigator.pop();
    await pumpFrames(tester);
    expect(historyRequests(), 2);
  });

  testWidgets('關掉撥號畫面時的取消請求到後端後才重抓', (tester) async {
    final navigator = await open(tester);
    navigator.push(overlay());
    await pumpFrames(tester);

    // 撥號畫面 dispose 時送出取消、不等回應。
    unawaited(DirectedCallService.cancelCall(5));
    navigator.pop();
    await tester.pump(const Duration(milliseconds: 100));
    expect(historyRequests(), 1);

    await pumpFrames(tester);
    final cancelAt = seen.indexOf('/api/friends/calls/5/cancel');
    expect(cancelAt, isNonNegative);
    expect(
      seen.lastIndexOf('/api/friends/BBBB2345/messages'),
      greaterThan(cancelAt),
    );
    expect(historyRequests(), 2);
  });
}
