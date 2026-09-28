// 點好友相關通知後的導頁（friend_push_navigation.dart）。
//
// 只驗「導到哪一頁」：好友列表之外的 API 一律回 404，目的頁自己的載入失敗不影響斷言。

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_application_1/core/navigation/route_stack.dart';
import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/main.dart' show scaffoldMessengerKey;
import 'package:flutter_application_1/screens/chat/chat_screen.dart';
import 'package:flutter_application_1/screens/friends/friend_push_navigation.dart';
import 'package:flutter_application_1/screens/friends/friend_requests_screen.dart';
import 'package:flutter_application_1/screens/friends/public_profile_screen.dart';

import '../helpers/flow_test_helpers.dart';
import '../helpers/widget_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final navKey = GlobalKey<NavigatorState>();
  late RouteStack routes;
  var readPosts = 0;

  setUp(() {
    stubCommonChannels();
    readPosts = 0;
    ApiClient.httpClient = MockClient((request) async {
      if (request.method == 'POST' &&
          request.url.path == '/api/friends/7/messages/read') {
        readPosts++;
      }
      if (request.url.path == '/api/friends') {
        return http.Response(
          jsonEncode({
            'friends': [
              {'uid': 7, 'nickname': '阿美', 'friend_code': 'AMI7'},
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response('{"error":{"code":"NOT_FOUND"}}', 404);
    });
  });
  tearDown(restoreHttp);

  Future<void> start(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navKey,
        scaffoldMessengerKey: scaffoldMessengerKey,
        navigatorObservers: [routes = RouteStack()],
        home: const Scaffold(body: Text('HOME')),
      ),
    );
  }

  Future<void> open(WidgetTester tester, String type, int uid) async {
    await openFriendPush(routes, type, uid);
    await pumpFrames(tester);
  }

  testWidgets('好友邀請 → 好友邀請頁', (tester) async {
    await start(tester);
    await open(tester, 'friend_request', 99);
    expect(find.byType(FriendRequestsScreen), findsOneWidget);
  });

  testWidgets('私訊 → 與對方的聊天室；已開著就不重複疊頁', (tester) async {
    await start(tester);
    await open(tester, 'friend_message', 7);
    expect(find.byType(ChatScreen), findsOneWidget);

    final readsAfterOpen = readPosts;

    await open(tester, 'friend_message', 7);
    expect(find.byType(ChatScreen, skipOffstage: false), findsOneWidget);
    // 已開著時重抓訊息之外也要標已讀，否則紅點會殘留。
    expect(readPosts, readsAfterOpen + 1);
  });

  testWidgets('聊天室被其他頁（例如通話）蓋住時不拆掉上層，照常疊一頁', (tester) async {
    await start(tester);
    await open(tester, 'friend_message', 7);
    navKey.currentState!.push(
      MaterialPageRoute(builder: (_) => const Scaffold(body: Text('CALL'))),
    );
    await pumpFrames(tester);

    await open(tester, 'friend_message', 7);

    expect(find.text('CALL', skipOffstage: false), findsOneWidget);
    expect(find.byType(ChatScreen, skipOffstage: false), findsNWidgets(2));
  });

  testWidgets('聊天室上面只蓋著 dialog：視為已開著，不疊頁也不關 dialog', (tester) async {
    await start(tester);
    await open(tester, 'friend_message', 7);
    showDialog<void>(
      context: navKey.currentContext!,
      builder: (_) => const AlertDialog(content: Text('DIALOG')),
    );
    await pumpFrames(tester);
    final readsBefore = readPosts;

    await open(tester, 'friend_message', 7);

    expect(find.text('DIALOG'), findsOneWidget);
    expect(find.byType(ChatScreen, skipOffstage: false), findsOneWidget);
    expect(readPosts, readsBefore + 1);
  });

  testWidgets('同一人開了兩個聊天室，關掉上層後下層仍能被重載', (tester) async {
    await start(tester);
    await open(tester, 'friend_message', 7);
    navKey.currentState!.push(
      MaterialPageRoute(builder: (_) => const Scaffold(body: Text('CALL'))),
    );
    await pumpFrames(tester);
    await open(tester, 'friend_message', 7);
    expect(find.byType(ChatScreen, skipOffstage: false), findsNWidgets(2));

    navKey.currentState!
      ..pop()
      ..pop();
    await pumpFrames(tester);
    final readsBefore = readPosts;

    await open(tester, 'friend_message', 7);

    expect(find.byType(ChatScreen, skipOffstage: false), findsOneWidget);
    expect(readPosts, readsBefore + 1);
  });

  testWidgets('接受邀請與羈絆展示 → 對方公開頁', (tester) async {
    await start(tester);
    await open(tester, 'friend_accepted', 7);
    expect(find.byType(PublicProfileScreen), findsOneWidget);

    navKey.currentState!.pop();
    await pumpFrames(tester);
    await open(tester, 'friend_bond_showcase_confirmed', 7);
    expect(find.byType(PublicProfileScreen), findsOneWidget);
  });

  testWidgets('查詢好友失敗 → 不導頁，提示稍後再試', (tester) async {
    ApiClient.httpClient = MockClient(
      (_) async => http.Response('{"error":{"code":"INTERNAL"}}', 500),
    );
    await start(tester);
    await open(tester, 'friend_message', 7);

    expect(find.text('HOME'), findsOneWidget);
    expect(find.byType(FriendRequestsScreen), findsNothing);
    expect(find.text('無法開啟，請稍後再試'), findsOneWidget);
  });

  testWidgets('uid 已不是好友 → 好友邀請頁，不報錯', (tester) async {
    await start(tester);
    await open(tester, 'friend_accepted', 404);
    expect(find.byType(FriendRequestsScreen), findsOneWidget);
  });
}
