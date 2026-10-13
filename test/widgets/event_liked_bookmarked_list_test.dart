// 活動收藏／按讚清單：往下捲帶游標翻頁，到底判斷看 has_more，不再用這頁筆數猜。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/screens/events/event_liked_bookmarked_list.dart';

import '../helpers/flow_test_helpers.dart';
import '../helpers/widget_test_helpers.dart';

Map<String, dynamic> _event(int id) => {
  'id': id,
  'title': '活動 $id',
  'starts_at': '2026-12-01T10:00:00Z',
  'status': 'active',
  'effective_status': 'active',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(stubCommonChannels);
  tearDown(restoreHttp);

  Future<void> scrollToBottom(WidgetTester tester) async {
    await tester.fling(find.byType(ListView), const Offset(0, -5000), 3000);
    await pumpFrames(tester, times: 10);
  }

  for (final (mode, path) in [
    (EventListMode.liked, '/api/events/likes'),
    (EventListMode.bookmarked, '/api/events/bookmarks'),
  ]) {
    testWidgets('$path：翻頁帶上一頁的游標，重複的只出現一次', (tester) async {
      final cursors = <String?>[];
      ApiClient.httpClient = MockClient((r) async {
        expect(r.url.path, path);
        final cursor = r.url.queryParameters['cursor'];
        cursors.add(cursor);
        return jsonResponse(
          cursor == null
              ? {
                  'events': [for (var i = 1; i <= 20; i++) _event(i)],
                  'page_info': {'next_cursor': '20', 'has_more': true},
                }
              : {
                  // 不滿 20 筆但還有下一頁：以前用筆數判斷會在這裡停下。
                  'events': [for (var i = 20; i <= 25; i++) _event(i)],
                  'page_info': {'next_cursor': '26', 'has_more': true},
                },
        );
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: EventLikedBookmarkedList(mode: mode)),
        ),
      );
      await pumpFrames(tester);
      await scrollToBottom(tester);
      await scrollToBottom(tester);

      expect(cursors.take(3), [null, '20', '26']);
      expect(find.text('活動 20', skipOffstage: false), findsOneWidget);
    });
  }

  testWidgets('has_more 為 false：捲到底不再請求', (tester) async {
    var calls = 0;
    ApiClient.httpClient = MockClient((r) async {
      calls++;
      return jsonResponse({
        'events': [for (var i = 1; i <= 20; i++) _event(i)],
        'page_info': {'next_cursor': null, 'has_more': false},
      });
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EventLikedBookmarkedList(mode: EventListMode.liked),
        ),
      ),
    );
    await pumpFrames(tester);
    await scrollToBottom(tester);

    expect(calls, 1);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  group('從詳情返回', () {
    /// 我按讚的活動清單後端：[liked] 決定清單裡有沒有活動 1。
    ({int listCalls}) Function() install({required bool Function() liked}) {
      var listCalls = 0;
      ApiClient.httpClient = MockClient((r) async {
        final Object body = switch (r.url.path) {
          '/api/events/likes' => () {
            listCalls++;
            return {
              'events': [if (liked()) _event(1), _event(2)],
              'page_info': {'next_cursor': null, 'has_more': false},
            };
          }(),
          '/api/events/1' => {
            ..._event(1),
            'description': '說明',
            'registration_open': true,
            'like_count': 1,
            'is_liked': true,
          },
          '/api/events/1/reminders' => {'reminders': <dynamic>[]},
          '/api/events/1/like' => {'liked': false, 'like_count': 0},
          '/api/me' => {'uid': 1, 'created_at': '2026-01-01T00:00:00Z'},
          '/api/shop/items' => {'items': <dynamic>[]},
          _ => fail('沒準備 ${r.url.path}'),
        };
        return jsonResponse(body);
      });
      return () => (listCalls: listCalls);
    }

    Future<void> openFirst(WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EventLikedBookmarkedList(mode: EventListMode.liked),
          ),
        ),
      );
      await pumpFrames(tester);
      await tester.tap(find.text('活動 1'));
      await pumpFrames(tester, times: 10);
    }

    testWidgets('只看不改就返回：不重抓', (tester) async {
      final stats = install(liked: () => true);
      await openFirst(tester);

      await tester.binding.handlePopRoute();
      await pumpFrames(tester, times: 10);

      expect(stats().listCalls, 1);
      expect(find.text('活動 1'), findsOneWidget);
    });

    testWidgets('在詳情取消按讚後返回：重抓，那則活動從列表移除', (tester) async {
      var liked = true;
      final stats = install(liked: () => liked);
      await openFirst(tester);

      await tester.tap(find.byIcon(Icons.favorite));
      await pumpFrames(tester);
      liked = false;
      await tester.binding.handlePopRoute();
      await pumpFrames(tester, times: 10);

      expect(stats().listCalls, 2);
      expect(find.text('活動 1'), findsNothing);
      expect(find.text('活動 2'), findsOneWidget);
    });
  });
}
