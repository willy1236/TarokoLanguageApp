// 文章與影音的列表、搜尋、收藏、按讚改用 limit＋cursor＋page_info，不再送 page／page_size。

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/models/page_info.dart';
import 'package:flutter_application_1/services/article_service.dart';
import 'package:flutter_application_1/services/video_service.dart';

import '../helpers/widget_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(stubCommonChannels);
  tearDown(restoreHttp);

  late List<http.BaseRequest> seen;

  void respondWith(Map<String, dynamic> body) {
    seen = [];
    ApiClient.httpClient = MockClient((r) async {
      seen.add(r);
      return jsonResponse(body);
    });
  }

  final pageInfo = {'next_cursor': '40', 'has_more': true};

  final endpoints = <String, Future<PageInfo> Function(String? cursor)>{
    '/api/articles': (c) async =>
        (await ArticleService.fetchArticles(cursor: c)).pageInfo,
    '/api/articles/search': (c) async =>
        (await ArticleService.searchArticles(q: '織布', cursor: c)).pageInfo,
    '/api/articles/bookmarks': (c) async =>
        (await ArticleService.fetchArticleBookmarks(cursor: c)).pageInfo,
    '/api/articles/likes': (c) async =>
        (await ArticleService.fetchLikedArticles(cursor: c)).pageInfo,
    '/api/videos': (c) async =>
        (await VideoService.fetchVideos(cursor: c)).pageInfo,
    '/api/videos/search': (c) async =>
        (await VideoService.searchVideos(q: '織布', cursor: c)).pageInfo,
    '/api/videos/bookmarks': (c) async =>
        (await VideoService.fetchVideoBookmarks(cursor: c)).pageInfo,
    '/api/videos/likes': (c) async =>
        (await VideoService.fetchLikedVideos(cursor: c)).pageInfo,
  };

  for (final MapEntry(key: path, value: fetch) in endpoints.entries) {
    test('$path 帶 cursor／limit 並讀 page_info', () async {
      respondWith({
        'total': 99,
        'page': 2,
        'articles': <dynamic>[],
        'videos': <dynamic>[],
        'page_info': pageInfo,
      });

      final info = await fetch('20');

      final query = seen.single.url.queryParameters;
      expect(seen.single.url.path, path);
      expect(query['cursor'], '20');
      expect(query['limit'], '20');
      expect(query.containsKey('page'), isFalse);
      expect(query.containsKey('page_size'), isFalse);
      expect(info.nextCursor, '40');
    });
  }

  test('本週精選用 limit 指定筆數，不帶 cursor', () async {
    respondWith({'videos': <dynamic>[], 'page_info': pageInfo});

    await VideoService.fetchVideos(sort: 'weekly_popular', limit: 5);

    expect(seen.single.url.queryParameters, {
      'sort': 'weekly_popular',
      'limit': '5',
    });
  });
}
