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
          request.url.path == '/api/friends/AMIA2345/messages/read') {
        readPosts++;
      }
      if (request.url.path == '/api/friends') {
        return http.Response(
          jsonEncode({
            'friends': [
              {'nickname': '阿美', 'friend_code': 'AMIA2345'},
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

  Future<void> open(WidgetTester tester, String type, String friendCode) async {
    await openFriendPush(routes, type, friendCode);
    await pumpFrames(tester);
  }

  testWidgets('好友邀請 → 好友邀請頁', (tester) async {
    await start(tester);
    await open(tester, 'friend_request', 'NEWB2345');
    expect(find.byType(FriendRequestsScreen), findsOneWidget);
  });

  testWidgets('私訊 → 與對方的聊天室；已開著就不重複疊頁', (tester) async {
    await start(tester);
    await open(tester, 'friend_message', 'AMIA2345');
    expect(find.byType(ChatScreen), findsOneWidget);

    final readsAfterOpen = readPosts;

    await open(tester, 'friend_message', 'AMIA2345');
    expect(find.byType(ChatScreen, skipOffstage: false), findsOneWidget);
    // 已開著時重抓訊息之外也要標已讀，否則紅點會殘留。
    expect(readPosts, readsAfterOpen + 1);
  });

  testWidgets('聊天室被其他頁（例如通話）蓋住時不拆掉上層，照常疊一頁', (tester) async {
    await start(tester);
    await open(tester, 'friend_message', 'AMIA2345');
    navKey.currentState!.push(
      MaterialPageRoute(builder: (_) => const Scaffold(body: Text('CALL'))),
    );
    await pumpFrames(tester);

    await open(tester, 'friend_message', 'AMIA2345');

    expect(find.text('CALL', skipOffstage: false), findsOneWidget);
    expect(find.byType(ChatScreen, skipOffstage: false), findsNWidgets(2));
  });

  testWidgets('聊天室上面只蓋著 dialog：視為已開著，不疊頁也不關 dialog', (tester) async {
    await start(tester);
    await open(tester, 'friend_message', 'AMIA2345');
    showDialog<void>(
      context: navKey.currentContext!,
      builder: (_) => const AlertDialog(content: Text('DIALOG')),
    );
    await pumpFrames(tester);
    final readsBefore = readPosts;

    await open(tester, 'friend_message', 'AMIA2345');

    expect(find.text('DIALOG'), findsOneWidget);
    expect(find.byType(ChatScreen, skipOffstage: false), findsOneWidget);
    expect(readPosts, readsBefore + 1);
  });

  testWidgets('同一人開了兩個聊天室，關掉上層後下層仍能被重載', (tester) async {
    await start(tester);
    await open(tester, 'friend_message', 'AMIA2345');
    navKey.currentState!.push(
      MaterialPageRoute(builder: (_) => const Scaffold(body: Text('CALL'))),
    );
    await pumpFrames(tester);
    await open(tester, 'friend_message', 'AMIA2345');
    expect(find.byType(ChatScreen, skipOffstage: false), findsNWidgets(2));

    navKey.currentState!
      ..pop()
      ..pop();
    await pumpFrames(tester);
    final readsBefore = readPosts;

    await open(tester, 'friend_message', 'AMIA2345');

    expect(find.byType(ChatScreen, skipOffstage: false), findsOneWidget);
    expect(readPosts, readsBefore + 1);
  });

  testWidgets('接受邀請與羈絆展示 → 對方公開頁', (tester) async {
    await start(tester);
    await open(tester, 'friend_accepted', 'AMIA2345');
    expect(find.byType(PublicProfileScreen), findsOneWidget);

    navKey.currentState!.pop();
    await pumpFrames(tester);
    await open(tester, 'friend_bond_showcase_confirmed', 'AMIA2345');
    expect(find.byType(PublicProfileScreen), findsOneWidget);
  });

  testWidgets('查詢好友失敗 → 不導頁，提示稍後再試', (tester) async {
    ApiClient.httpClient = MockClient(
      (_) async => http.Response('{"error":{"code":"INTERNAL"}}', 500),
    );
    await start(tester);
    await open(tester, 'friend_accepted', 'AMIA2345');

    expect(find.text('HOME'), findsOneWidget);
    expect(find.byType(FriendRequestsScreen), findsNothing);
    expect(find.text('無法開啟，請稍後再試'), findsOneWidget);
  });

  group('陌生人的私訊', () {
    /// 好友列表裡沒有 GONE2345；訊息 API 照常回對方資料與那則破冰訊息。
    void serveStranger({bool friendsFail = false}) {
      ApiClient.httpClient = MockClient((request) async {
        final path = request.url.path;
        if (path == '/api/friends') {
          if (friendsFail) {
            return http.Response('{"error":{"code":"INTERNAL"}}', 500);
          }
          return jsonResponse({'friends': <dynamic>[]});
        }
        if (path == '/api/friends/GONE2345/messages') {
          return jsonResponse({
            'partner': {'nickname': '路人甲', 'friend_code': 'GONE2345'},
            'messages': [
              {
                'id': 3,
                'body': '你好，想認識你',
                'created_at': '2026-10-05T01:00:00Z',
                'read_at': null,
                'mine': false,
              },
            ],
            'page_info': {'next_cursor': null, 'has_more': false},
          });
        }
        if (path == '/api/friends/GONE2345/messages/read') {
          return jsonResponse({'ok': true, 'marked': 1});
        }
        return http.Response('{"error":{"code":"NOT_FOUND"}}', 404);
      });
    }

    testWidgets('不是好友 → 開聊天室，看得到訊息，標題由訊息 API 補上暱稱', (tester) async {
      serveStranger();
      await start(tester);
      await open(tester, 'friend_message', 'GONE2345');

      expect(find.byType(ChatScreen), findsOneWidget);
      expect(find.byType(FriendRequestsScreen), findsNothing);
      expect(find.text('你好，想認識你'), findsOneWidget);
      expect(find.textContaining('路人甲'), findsOneWidget);
    });

    testWidgets('查詢好友失敗 → 仍開聊天室，不提示無法開啟', (tester) async {
      serveStranger(friendsFail: true);
      await start(tester);
      await open(tester, 'friend_message', 'GONE2345');

      expect(find.byType(ChatScreen), findsOneWidget);
      expect(find.text('你好，想認識你'), findsOneWidget);
      expect(find.text('無法開啟，請稍後再試'), findsNothing);
    });

    testWidgets('聊天室已在最上層 → 就地重載，不疊頁', (tester) async {
      serveStranger();
      await start(tester);
      await open(tester, 'friend_message', 'GONE2345');
      await open(tester, 'friend_message', 'GONE2345');

      expect(find.byType(ChatScreen, skipOffstage: false), findsOneWidget);
    });
  });

  testWidgets('好友碼已不是好友 → 好友邀請頁，不報錯', (tester) async {
    await start(tester);
    await open(tester, 'friend_accepted', 'GONE2345');
    expect(find.byType(FriendRequestsScreen), findsOneWidget);
  });
}
