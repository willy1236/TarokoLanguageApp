// 點活動提醒、論壇回覆通知後的導頁，以及論壇前景推播的頁內提示判斷
// （content_push_navigation.dart）。
//
// 目標頁是最上層的整頁才就地重載；被通話、響鈴或其他頁蓋住時疊一份新的，
// 不能 pop 掉蓋在上面的頁。以「詳情 API 被打了幾次」判斷重載，以返回後看到的頁
// 判斷堆疊。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

import 'package:flutter_application_1/core/navigation/route_stack.dart';
import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/screens/content_push_navigation.dart';
import 'package:flutter_application_1/screens/events/event_detail_screen.dart';
import 'package:flutter_application_1/screens/forum/forum_detail_screen.dart';

import '../helpers/flow_test_helpers.dart';
import '../helpers/widget_test_helpers.dart';

final _postPath = RegExp(r'^/api/forum/posts/(\d+)$');
final _eventPath = RegExp(r'^/api/events/\d+$');

Map<String, dynamic> _postJson(int id) => {
  'id': id,
  'board': {'id': 1, 'slug': 'life', 'name': '生活'},
  'title': '貼文 $id',
  'body': '內文',
  'like_count': 0,
  'comment_count': 0,
  'is_pinned': false,
  'is_liked': false,
  'is_bookmarked': false,
  'images': <String>[],
  'tags': <Map<String, dynamic>>[],
  'created_at': '2026-08-01T11:00:00.000Z',
  'updated_at': '2026-08-01T11:00:00.000Z',
  'author': {'uid': 8, 'display_name': 'Pisaw', 'avatar_url': null},
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final navKey = GlobalKey<NavigatorState>();
  late RouteStack routes;

  /// 各詳情 API 被讀取的次數，key 是 path。
  final hits = <String, int>{};

  setUp(() {
    stubCommonChannels();
    hits.clear();
    ApiClient.httpClient = MockClient((request) async {
      final path = request.url.path;
      final post = _postPath.firstMatch(path);
      if (post != null) {
        hits[path] = (hits[path] ?? 0) + 1;
        return jsonResponse({'post': _postJson(int.parse(post.group(1)!))});
      }
      if (path.endsWith('/comments')) {
        return jsonResponse({
          'comments': <dynamic>[],
          'replies': <dynamic>[],
          'next_cursor': null,
        });
      }
      // 活動詳情只數次數，載入失敗顯示錯誤頁不影響導頁斷言。
      if (_eventPath.hasMatch(path)) {
        hits[path] = (hits[path] ?? 0) + 1;
      }
      return errorResponse('NOT_FOUND', status: 404);
    });
  });
  tearDown(restoreHttp);

  Future<void> start(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navKey,
        navigatorObservers: [routes = RouteStack()],
        home: const Scaffold(body: Text('HOME')),
      ),
    );
  }

  Future<void> push(WidgetTester tester, Route<void> route) async {
    navKey.currentState!.push(route);
    await pumpFrames(tester);
  }

  Future<void> pop(WidgetTester tester) async {
    navKey.currentState!.pop();
    await pumpFrames(tester);
  }

  /// 模擬通話或響鈴畫面這類蓋在詳情頁上的整頁。
  Route<void> callScreen() =>
      MaterialPageRoute(builder: (_) => fakeRoute('CALL'));

  group('論壇回覆通知', () {
    const path = '/api/forum/posts/7';

    testWidgets('詳情頁在最上層：就地重載，不疊頁', (tester) async {
      await start(tester);
      await push(tester, ForumDetailScreen.route(postId: 7));
      expect(hits[path], 1);

      openForumReplyPush(routes, 7);
      await pumpFrames(tester);

      expect(hits[path], 2);
      await pop(tester);
      expect(find.text('HOME'), findsOneWidget);
    });

    testWidgets('上面只蓋著 dialog：仍算在最上層，就地重載', (tester) async {
      await start(tester);
      await push(tester, ForumDetailScreen.route(postId: 7));
      showDialog<void>(
        context: navKey.currentContext!,
        builder: (_) => const AlertDialog(content: Text('DIALOG')),
      );
      await pumpFrames(tester);

      openForumReplyPush(routes, 7);
      await pumpFrames(tester);

      expect(hits[path], 2);
      expect(find.text('DIALOG'), findsOneWidget);
    });

    testWidgets('詳情頁被通話畫面蓋住：疊一份新的，通話不被拆掉，返回回到通話', (tester) async {
      await start(tester);
      await push(tester, ForumDetailScreen.route(postId: 7));
      await push(tester, callScreen());

      openForumReplyPush(routes, 7);
      await pumpFrames(tester);

      expect(hits[path], 2);
      expect(find.byType(ForumDetailScreen), findsOneWidget);
      await pop(tester);
      expect(find.text('CALL'), findsOneWidget);
    });

    testWidgets('同一篇開了兩份，關掉上層後通知仍能重載下層那份', (tester) async {
      await start(tester);
      await push(tester, ForumDetailScreen.route(postId: 7));
      await push(tester, callScreen());
      openForumReplyPush(routes, 7);
      await pumpFrames(tester);
      await pop(tester);
      await pop(tester);
      expect(hits[path], 2);

      openForumReplyPush(routes, 7);
      await pumpFrames(tester);

      expect(hits[path], 3);
      await pop(tester);
      expect(find.text('HOME'), findsOneWidget);
    });

    testWidgets('沒開著：開啟詳情頁', (tester) async {
      await start(tester);
      openForumReplyPush(routes, 7);
      await pumpFrames(tester);
      expect(find.byType(ForumDetailScreen), findsOneWidget);
    });

    testWidgets('沒開著且推播帶了留言：開啟詳情頁並指定要捲去的留言', (tester) async {
      await start(tester);
      openForumReplyPush(routes, 7, commentId: 8);
      await pumpFrames(tester);
      final screen = tester.widget<ForumDetailScreen>(
        find.byType(ForumDetailScreen),
      );
      expect(screen.focusCommentId, 8);
    });

    testWidgets('詳情頁在最上層且推播帶了留言：就地重載，不疊頁', (tester) async {
      await start(tester);
      await push(tester, ForumDetailScreen.route(postId: 7));

      openForumReplyPush(routes, 7, commentId: 8);
      await pumpFrames(tester);

      expect(hits[path], 2);
      expect(find.byType(ForumDetailScreen), findsOneWidget);
    });
  });

  group('論壇前景回覆推播', () {
    final chip = find.textContaining('則新回覆');

    testWidgets('正看著該貼文：改在頁內提示', (tester) async {
      await start(tester);
      await push(tester, ForumDetailScreen.route(postId: 7));

      expect(showForumReplyInPage(routes, 7, 'reply_post'), isTrue);
      await pumpFrames(tester);
      expect(chip, findsOneWidget);
    });

    testWidgets('貼文被別的頁蓋住：交回呼叫端照常彈通知', (tester) async {
      await start(tester);
      await push(tester, ForumDetailScreen.route(postId: 7));
      await push(tester, callScreen());

      expect(showForumReplyInPage(routes, 7, 'reply_post'), isFalse);
      await pop(tester);
      expect(chip, findsNothing);
    });

    testWidgets('別篇貼文的回覆：交回呼叫端照常彈通知', (tester) async {
      await start(tester);
      await push(tester, ForumDetailScreen.route(postId: 7));

      expect(showForumReplyInPage(routes, 99, 'reply_post'), isFalse);
      await pumpFrames(tester);
      expect(chip, findsNothing);
    });
  });

  group('活動提醒通知', () {
    const path = '/api/events/41';

    testWidgets('詳情頁在最上層：就地重載，不疊頁', (tester) async {
      await start(tester);
      await push(tester, EventDetailScreen.route(41));
      expect(hits[path], 1);

      openEventPush(routes, 41);
      await pumpFrames(tester);

      expect(hits[path], 2);
      await pop(tester);
      expect(find.text('HOME'), findsOneWidget);
    });

    testWidgets('詳情頁被響鈴畫面蓋住：疊一份新的，返回回到響鈴畫面', (tester) async {
      await start(tester);
      await push(tester, EventDetailScreen.route(41));
      await push(tester, callScreen());

      openEventPush(routes, 41);
      await pumpFrames(tester);

      expect(hits[path], 2);
      expect(find.byType(EventDetailScreen), findsOneWidget);
      await pop(tester);
      expect(find.text('CALL'), findsOneWidget);
    });

    testWidgets('同一場開了兩份，關掉上層後通知仍能重載下層那份', (tester) async {
      await start(tester);
      await push(tester, EventDetailScreen.route(41));
      await push(tester, callScreen());
      openEventPush(routes, 41);
      await pumpFrames(tester);
      await pop(tester);
      await pop(tester);

      openEventPush(routes, 41);
      await pumpFrames(tester);

      expect(hits[path], 3);
      await pop(tester);
      expect(find.text('HOME'), findsOneWidget);
    });
  });
}
