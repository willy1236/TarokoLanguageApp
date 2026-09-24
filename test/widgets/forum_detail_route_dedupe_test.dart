// 通知導頁的冪等性：同一篇貼文詳情已經開著時，點通知只回到那一份並重載，
// 不能再疊一頁——疊了會讓使用者返回時看到留言前的舊狀態。
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/screens/forum/forum_detail_screen.dart';

Map<String, dynamic> postJson(int id, {int commentCount = 0}) => {
  'id': id,
  'board': {'id': 1, 'slug': 'life', 'name': '生活'},
  'title': '貼文 $id',
  'body': '內文',
  'like_count': 0,
  'comment_count': commentCount,
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

  // ApiClient 會經由 flutter_secure_storage 讀 token，測試環境沒有原生實作。
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async => null,
        );
  });

  tearDown(() => ApiClient.httpClient = http.Client());

  /// 回傳貼文與空留言列表，並記錄每支貼文被讀取幾次。
  (MockClient, Map<int, int>) mockApi() {
    final postHits = <int, int>{};
    final client = MockClient((request) async {
      final path = request.url.path;
      Map<String, dynamic> body;
      if (path.endsWith('/comments')) {
        body = {
          'comments': <dynamic>[],
          'replies': <dynamic>[],
          'next_cursor': null,
        };
      } else {
        final id =
            int.tryParse(path.split('/').where((s) => s.isNotEmpty).last) ?? 0;
        postHits[id] = (postHits[id] ?? 0) + 1;
        body = {'post': postJson(id)};
      }
      return http.Response(
        jsonEncode(body),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    return (client, postHits);
  }

  testWidgets('同一篇已開著時，通知導頁不疊第二頁而是重載既有那一份', (tester) async {
    final (client, postHits) = mockApi();
    ApiClient.httpClient = client;

    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navKey,
        home: const Scaffold(body: Text('列表')),
      ),
    );

    navKey.currentState!.push(ForumDetailScreen.route(postId: 7));
    await tester.pumpAndSettle();
    expect(ForumDetailScreen.isOpen(7), isTrue);
    expect(postHits[7], 1);

    // 模擬 main.dart 的通知導頁處理。
    expect(ForumDetailScreen.isOpen(7), isTrue);
    navKey.currentState!.popUntil(
      (r) => r.settings.name == ForumDetailScreen.routeNameFor(7),
    );
    ForumDetailScreen.refreshIfOpen(7);
    await tester.pumpAndSettle();

    // 既有那一份重新載入，堆疊沒有變多：返回一次就該回到列表。
    expect(postHits[7], 2);
    navKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('列表'), findsOneWidget);
    expect(ForumDetailScreen.isOpen(7), isFalse);
  });

  testWidgets('不同貼文仍會開新頁', (tester) async {
    final (client, postHits) = mockApi();
    ApiClient.httpClient = client;

    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navKey,
        home: const Scaffold(body: Text('列表')),
      ),
    );

    navKey.currentState!.push(ForumDetailScreen.route(postId: 7));
    await tester.pumpAndSettle();
    expect(ForumDetailScreen.isOpen(9), isFalse);

    navKey.currentState!.push(ForumDetailScreen.route(postId: 9));
    await tester.pumpAndSettle();

    expect(ForumDetailScreen.isOpen(7), isTrue);
    expect(ForumDetailScreen.isOpen(9), isTrue);
    expect(postHits[9], 1);

    navKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(ForumDetailScreen.isOpen(9), isFalse);
    navKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(ForumDetailScreen.isOpen(7), isFalse);
  });
}
