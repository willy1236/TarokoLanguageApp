import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/services/forum_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ApiClient 內部經由 AuthService.currentToken() 讀取 flutter_secure_storage，
  // 該套件在測試環境沒有原生實作，需 mock method channel 讓它回傳 null（視為未登入）。
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async => null,
        );
  });

  late List<http.BaseRequest> seen;

  /// 以固定 JSON 回應所有請求，並記錄收到的 request 供斷言。
  void respondWith(Map<String, dynamic> body, {int status = 200}) {
    seen = [];
    ApiClient.httpClient = MockClient((req) async {
      seen.add(req);
      return http.Response(
        jsonEncode(body),
        status,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
  }

  Map<String, dynamic> postJson() => {
    'id': 1,
    'board': {'id': 2, 'slug': 'culture', 'name': '文化傳承'},
    'title': 't',
    'body': 'b',
    'like_count': 0,
    'comment_count': 0,
    'is_pinned': false,
    'is_liked': false,
    'created_at': '2026-08-01T10:00:00.000Z',
    'updated_at': '2026-08-01T10:00:00.000Z',
    'author': {'uid': 1, 'display_name': 'A', 'avatar_url': null},
  };

  tearDown(() => ApiClient.httpClient = http.Client());

  test('boards 打對端點並解析看板', () async {
    respondWith({
      'boards': [
        {'id': 1, 'slug': 'general', 'name': '綜合討論', 'description': null},
      ],
    });

    final boards = await ForumService.boards();

    expect(seen.single.url.path, '/api/forum/boards');
    expect(boards.single.slug, 'general');
  });

  test('posts 帶 cursor 與 limit', () async {
    respondWith({'pinned': [], 'posts': [], 'next_cursor': null});

    await ForumService.posts('culture', cursor: 500);

    expect(seen.single.url.path, '/api/forum/boards/culture/posts');
    expect(seen.single.url.queryParameters['cursor'], '500');
    expect(seen.single.url.queryParameters['limit'], '20');
    expect(seen.single.url.queryParameters.containsKey('after'), isFalse);
  });

  test('posts 帶 after 供下拉刷新，不同時帶 cursor', () async {
    respondWith({'pinned': [], 'posts': [], 'next_cursor': null});

    await ForumService.posts('culture', after: 900);

    expect(seen.single.url.queryParameters['after'], '900');
    expect(seen.single.url.queryParameters.containsKey('cursor'), isFalse);
  });

  test('allPosts 打跨看板端點，不帶 board 參數', () async {
    respondWith({'pinned': [], 'posts': [], 'next_cursor': null});

    await ForumService.allPosts(cursor: 300);

    expect(seen.single.method, 'GET');
    expect(seen.single.url.path, '/api/forum/posts');
    expect(seen.single.url.queryParameters['cursor'], '300');
    expect(seen.single.url.queryParameters['limit'], '20');
    expect(seen.single.url.queryParameters.containsKey('board'), isFalse);
  });

  test('likePost like=true 走 POST、like=false 走 DELETE', () async {
    respondWith({'liked': true, 'like_count': 4});
    final liked = await ForumService.likePost(7, like: true);
    expect(seen.single.method, 'POST');
    expect(seen.single.url.path, '/api/forum/posts/7/like');
    expect(liked.liked, isTrue);
    expect(liked.likeCount, 4);

    respondWith({'liked': false, 'like_count': 3});
    await ForumService.likePost(7, like: false);
    expect(seen.single.method, 'DELETE');
  });

  test('createComment 帶 parentCommentId 時送出第二層回覆', () async {
    respondWith({
      'comment': {
        'id': 11,
        'post_id': 7,
        'parent_comment_id': 5,
        'body': '回覆',
        'like_count': 0,
        'is_liked': false,
        'created_at': '2026-08-01T11:00:00.000Z',
        'author': {'uid': 1, 'display_name': 'A', 'avatar_url': null},
      },
    }, status: 201);

    final comment = await ForumService.createComment(
      7,
      '回覆',
      parentCommentId: 5,
    );

    final body = jsonDecode((seen.single as http.Request).body);
    expect(body['body'], '回覆');
    expect(body['parent_comment_id'], 5);
    expect(comment.parentCommentId, 5);
  });

  test('createPost 沒有附圖時走 JSON', () async {
    respondWith({'post': postJson()}, status: 201);

    await ForumService.createPost(boardId: 2, title: 't', body: 'b');

    expect(seen.single, isA<http.Request>());
    final body = jsonDecode((seen.single as http.Request).body);
    expect(body['board_id'], 2);
  });

  test('createPost 有附圖時走 multipart，標籤以逗號分隔傳遞', () async {
    respondWith({'post': postJson()}, status: 201);

    await ForumService.createPost(
      boardId: 2,
      title: 't',
      body: 'b',
      tags: ['族語', '走讀'],
      images: [
        const MultipartFileData(
          field: 'images',
          bytes: [1, 2],
          filename: 'a.jpg',
          mimeType: 'image/jpeg',
        ),
      ],
    );

    final request = seen.single;
    expect(request.method, 'POST');
    expect(request.headers['content-type'], contains('multipart/form-data'));
    // 注意：http 套件的 MockClient 一律把送出的請求（含 MultipartRequest）
    // 轉成一份新的 http.Request 再交給 handler（見 package:http/src/mock_client.dart），
    // 因此這裡拿不回原本的 MultipartRequest，只能改由原始 body bytes 解析欄位。
    final bodyText = utf8.decode((request as http.Request).bodyBytes);
    final boardIdMatch = RegExp(
      'name="board_id"\r\n\r\n([^\r]*)',
    ).firstMatch(bodyText);
    expect(boardIdMatch?.group(1), '2');
    // tags 欄位在 name 與值之間多帶了 content-type / content-transfer-encoding
    // 標頭列，因此用非貪婪比對跳過剩餘標頭列，直到分隔用的空白行為止。
    final tagsMatch = RegExp(
      'name="tags"[\\s\\S]*?\r\n\r\n([^\r]*)',
    ).firstMatch(bodyText);
    // multipart 下後端以逗號分隔解析（後端 API 文件 §3.1），不是 JSON。
    expect(tagsMatch!.group(1), '族語,走讀');
  });

  test('updatePost 只送 title 與 body，不送 tags', () async {
    respondWith({'post': postJson()});

    await ForumService.updatePost(1, title: 't2', body: 'b2');

    final body = jsonDecode((seen.single as http.Request).body);
    expect(body, {'title': 't2', 'body': 'b2'});
    expect(body.containsKey('tags'), isFalse);
    expect(seen.single.method, 'PATCH');
  });

  test('search 少於 2 字直接丟錯，不發請求', () async {
    respondWith({'posts': [], 'next_cursor': null});

    expect(() => ForumService.search('族'), throwsA(isA<ArgumentError>()));
    expect(seen, isEmpty);
  });

  test('markRead 不帶 ids 時送出空 body 代表全部已讀', () async {
    respondWith({'ok': true});

    await ForumService.markRead();

    expect(seen.single.url.path, '/api/forum/notifications/read');
    expect(jsonDecode((seen.single as http.Request).body), <String, dynamic>{});
  });

  test('report 送出 target_type 與 target_id', () async {
    respondWith({'ok': true}, status: 201);

    await ForumService.report(
      targetType: 'comment',
      targetId: 11,
      reason: '廣告',
    );

    final body = jsonDecode((seen.single as http.Request).body);
    expect(body, {'target_type': 'comment', 'target_id': 11, 'reason': '廣告'});
  });

  test('bookmarkPost add=false 走 DELETE', () async {
    respondWith({'bookmarked': false});

    final result = await ForumService.bookmarkPost(7, add: false);

    expect(seen.single.method, 'DELETE');
    expect(seen.single.url.path, '/api/forum/posts/7/bookmark');
    expect(result, isFalse);
  });
}
