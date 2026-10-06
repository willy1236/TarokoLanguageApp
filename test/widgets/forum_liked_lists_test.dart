// 論壇按讚的貼文／留言清單：帶游標翻頁、兩頁重複的只留一份、翻頁失敗等使用者點重試。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/screens/forum/forum_liked_comments_list.dart';
import 'package:flutter_application_1/screens/forum/forum_liked_posts_list.dart';

import '../helpers/flow_test_helpers.dart';
import '../helpers/widget_test_helpers.dart';

Map<String, dynamic> _post(int id) => {'id': id, 'title': '項目 $id'};

Map<String, dynamic> _comment(int id) => {
  'id': id,
  'post_id': 1,
  'post_title': '貼文',
  'body': '項目 $id',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(stubCommonChannels);
  tearDown(restoreHttp);

  Future<void> scrollToBottom(WidgetTester tester) async {
    await tester.fling(find.byType(ListView), const Offset(0, -5000), 3000);
    await pumpFrames(tester, times: 10);
  }

  final cases = <(String, String, Map<String, dynamic> Function(int), Widget)>[
    ('/api/forum/posts/likes', 'posts', _post, const ForumLikedPostsList()),
    (
      '/api/forum/comments/likes',
      'comments',
      _comment,
      const ForumLikedCommentsList(),
    ),
  ];

  for (final (path, key, item, list) in cases) {
    testWidgets('$path：翻頁失敗顯示重試，點了才重打；重複的只出現一次', (tester) async {
      final cursors = <String?>[];
      var failNext = true;
      ApiClient.httpClient = MockClient((r) async {
        expect(r.url.path, path);
        final cursor = r.url.queryParameters['cursor'];
        cursors.add(cursor);
        if (cursor == null) {
          return jsonResponse({
            key: [for (var i = 1; i <= 20; i++) item(i)],
            'page_info': {'next_cursor': 't20', 'has_more': true},
          });
        }
        if (failNext) return errorResponse('SERVER_ERROR', status: 500);
        return jsonResponse({
          key: [for (var i = 20; i <= 23; i++) item(i)],
          'page_info': {'next_cursor': null, 'has_more': false},
        });
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: list)));
      await pumpFrames(tester);
      await scrollToBottom(tester);
      await scrollToBottom(tester);

      expect(cursors, [null, 't20']);
      expect(find.text('載入失敗，點此重試'), findsOneWidget);

      failNext = false;
      await tester.tap(find.text('載入失敗，點此重試'));
      await pumpFrames(tester, times: 10);
      await scrollToBottom(tester);

      expect(cursors, [null, 't20', 't20']);
      expect(find.text('項目 23'), findsOneWidget);
      expect(find.text('項目 20', skipOffstage: false), findsOneWidget);
    });
  }

  testWidgets('第一頁填不滿畫面：不用捲動就接著抓下一頁', (tester) async {
    final cursors = <String?>[];
    ApiClient.httpClient = MockClient((r) async {
      final cursor = r.url.queryParameters['cursor'];
      cursors.add(cursor);
      return jsonResponse(
        cursor == null
            ? {
                'posts': [_post(1), _post(2)],
                'page_info': {'next_cursor': 't2', 'has_more': true},
              }
            : {
                'posts': [_post(3)],
                'page_info': {'next_cursor': null, 'has_more': false},
              },
      );
    });

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ForumLikedPostsList())),
    );
    await pumpFrames(tester, times: 10);

    expect(cursors, [null, 't2']);
    expect(find.text('項目 3'), findsOneWidget);
  });
}
