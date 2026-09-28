// 文章／影音的收藏與按讚清單：往下捲帶游標翻頁，到底看 has_more，重複的只留一份。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/screens/culture/article_liked_bookmarked_list.dart';
import 'package:flutter_application_1/screens/culture/video_liked_bookmarked_list.dart';

import '../helpers/flow_test_helpers.dart';
import '../helpers/widget_test_helpers.dart';

Map<String, dynamic> _item(int id) => {
  'id': id,
  'title': '項目 $id',
  'category': 'cultural',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(stubCommonChannels);
  tearDown(restoreHttp);

  final cases = <(String, String, Widget)>[
    (
      '/api/articles/likes',
      'articles',
      const ArticleLikedBookmarkedList(mode: ArticleListMode.liked),
    ),
    (
      '/api/articles/bookmarks',
      'articles',
      const ArticleLikedBookmarkedList(mode: ArticleListMode.bookmarked),
    ),
    (
      '/api/videos/likes',
      'videos',
      const VideoLikedBookmarkedList(mode: VideoListMode.liked),
    ),
    (
      '/api/videos/bookmarks',
      'videos',
      const VideoLikedBookmarkedList(mode: VideoListMode.bookmarked),
    ),
  ];

  for (final (path, key, list) in cases) {
    testWidgets('$path：帶游標翻到底，重複的只留一份，到底後不再請求', (tester) async {
      final cursors = <String?>[];
      ApiClient.httpClient = MockClient((r) async {
        expect(r.url.path, path);
        final cursor = r.url.queryParameters['cursor'];
        cursors.add(cursor);
        return jsonResponse(
          cursor == null
              ? {
                  key: [for (var i = 1; i <= 20; i++) _item(i)],
                  'page_info': {'next_cursor': '20', 'has_more': true},
                }
              : {
                  key: [for (var i = 20; i <= 23; i++) _item(i)],
                  'page_info': {'next_cursor': null, 'has_more': false},
                },
        );
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: list)));
      await pumpFrames(tester);
      for (var i = 0; i < 3; i++) {
        await tester.fling(find.byType(ListView), const Offset(0, -5000), 3000);
        await pumpFrames(tester, times: 10);
      }

      expect(cursors, [null, '20']);
      expect(find.text('項目 23'), findsOneWidget);
      expect(find.text('項目 20', skipOffstage: false), findsOneWidget);
    });
  }
}
