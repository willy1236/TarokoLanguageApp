import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/screens/forum/forum_notifications_screen.dart';

Map<String, dynamic> notification({required int id, required bool isRead}) => {
  'id': id,
  'type': 'reply_post',
  'post_id': 1024,
  'comment_id': 5,
  'post_title': '關於 mhuway',
  'is_read': isRead,
  'created_at': '2026-08-01T11:00:00.000Z',
  'actor': {'uid': 8, 'display_name': 'Pisaw', 'avatar_url': null},
};

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

  testWidgets('顯示通知，內容包含回覆者與貼文標題', (tester) async {
    ApiClient.httpClient = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'notifications': [notification(id: 3, isRead: false)],
          'unread_count': 1,
          'next_cursor': null,
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(home: ForumNotificationsScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Pisaw'), findsOneWidget);
    expect(find.textContaining('關於 mhuway'), findsOneWidget);
  });

  testWidgets('沒有通知時顯示空狀態', (tester) async {
    ApiClient.httpClient = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'notifications': [],
          'unread_count': 0,
          'next_cursor': null,
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(home: ForumNotificationsScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('還沒有新的回覆'), findsOneWidget);
  });

  testWidgets('點「全部已讀」送出不帶 ids 的請求', (tester) async {
    String? sentPath;
    Map<String, dynamic>? sentBody;
    ApiClient.httpClient = MockClient((req) async {
      if (req.method == 'POST') {
        sentPath = req.url.path;
        sentBody = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response(jsonEncode({'ok': true}), 200);
      }
      return http.Response(
        jsonEncode({
          'notifications': [notification(id: 3, isRead: false)],
          'unread_count': 1,
          'next_cursor': null,
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    await tester.pumpWidget(
      const MaterialApp(home: ForumNotificationsScreen()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('全部已讀'));
    await tester.pumpAndSettle();

    expect(sentPath, '/api/forum/notifications/read');
    expect(sentBody, <String, dynamic>{});
  });
}
