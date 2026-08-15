import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/screens/forum/forum_bookmarks_screen.dart';

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

  tearDown(() => ApiClient.httpClient = http.Client());

  testWidgets('顯示收藏的貼文', (tester) async {
    ApiClient.httpClient = MockClient((req) async {
      expect(req.url.path, '/api/forum/bookmarks');
      return http.Response(
        jsonEncode({
          'posts': [
            {
              'id': 1,
              'board': {'id': 2, 'slug': 'culture', 'name': '文化傳承'},
              'title': '收藏的貼文',
              'body': '內文',
              'like_count': 0,
              'comment_count': 0,
              'is_pinned': false,
              'is_liked': false,
              'is_bookmarked': true,
              'created_at': '2026-08-01T10:00:00.000Z',
              'updated_at': '2026-08-01T10:00:00.000Z',
              'author': {'uid': 1, 'display_name': 'A', 'avatar_url': null},
            },
          ],
          'next_cursor': null,
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    await tester.pumpWidget(const MaterialApp(home: ForumBookmarksScreen()));
    await tester.pumpAndSettle();

    expect(find.text('收藏的貼文'), findsOneWidget);
  });

  testWidgets('端點未上線（404）時顯示錯誤與重試', (tester) async {
    ApiClient.httpClient = MockClient((_) async => http.Response(
          jsonEncode({
            'error': {'code': 'NOT_FOUND', 'message': '找不到資源'},
          }),
          404,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ));

    await tester.pumpWidget(const MaterialApp(home: ForumBookmarksScreen()));
    await tester.pumpAndSettle();

    expect(find.text('重試'), findsOneWidget);
  });
}
