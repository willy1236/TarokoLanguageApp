import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/main.dart'
    show navigatorKey, scaffoldMessengerKey;
import 'package:flutter_application_1/services/account_lock_controller.dart';

const _utf8Json = {'content-type': 'application/json; charset=utf-8'};

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

  test('get 走可注入的 httpClient', () async {
    late Uri seen;
    ApiClient.httpClient = MockClient((req) async {
      seen = req.url;
      return http.Response(jsonEncode({'ok': true}), 200);
    });

    final result = await ApiClient.get('/api/ping', query: {'a': '1'});

    expect(seen.path, '/api/ping');
    expect(seen.queryParameters, {'a': '1'});
    expect(result, {'ok': true});
  });

  test('delete 離線時轉成 NETWORK_ERROR', () async {
    ApiClient.httpClient = MockClient(
      (_) async => throw const SocketException('offline'),
    );

    expect(
      () => ApiClient.delete('/api/thing'),
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', 'NETWORK_ERROR'),
      ),
    );
  });

  // Web 上 ClientException 會轉成 NETWORK_ERROR，需 `--platform chrome` 才測得到。
  test('手機上 ClientException 維持原樣往外丟', () async {
    ApiClient.httpClient = MockClient(
      (_) async => throw http.ClientException('Connection closed'),
    );

    expect(
      () => ApiClient.delete('/api/thing'),
      throwsA(isA<http.ClientException>()),
    );
  });

  test('postMultipart 帶上文字欄位與檔案的 MIME', () async {
    late http.BaseRequest seen;
    late String bodyText;
    ApiClient.httpClient = MockClient((req) async {
      seen = req;
      bodyText = req.body;
      return http.Response(jsonEncode({'ok': true}), 201);
    });

    await ApiClient.postMultipart(
      '/api/forum/posts',
      fields: {'board_id': '1', 'title': '標題'},
      files: [
        MultipartFileData(
          field: 'images',
          bytes: [1, 2, 3],
          filename: 'a.jpg',
          mimeType: 'image/jpeg',
        ),
      ],
    );

    expect(seen.method, 'POST');
    expect(seen.headers['content-type'], contains('multipart/form-data'));
    expect(bodyText, contains('name="board_id"'));
    expect(bodyText, contains('name="title"'));
    expect(bodyText, contains('filename="a.jpg"'));
    expect(bodyText, contains('image/jpeg'));
  });

  test('postMultipartBytes 帶上欄位名、檔名與 MIME', () async {
    late http.BaseRequest seen;
    late String bodyText;
    ApiClient.httpClient = MockClient((req) async {
      seen = req;
      bodyText = req.body;
      return http.Response(jsonEncode({'ok': true}), 200);
    });

    await ApiClient.postMultipartBytes(
      '/api/me/avatar',
      fieldName: 'avatar',
      bytes: [1, 2, 3],
      filename: 'a.png',
      contentType: 'image/png',
    );

    expect(seen.method, 'POST');
    expect(seen.headers['content-type'], contains('multipart/form-data'));
    expect(bodyText, contains('name="avatar"'));
    expect(bodyText, contains('filename="a.png"'));
    expect(bodyText, contains('image/png'));
  });

  group('429 retry_after', () {
    test('優先讀 body 的 retry_after', () async {
      ApiClient.httpClient = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'error': {'code': 'RATE_LIMITED', 'message': 'x'},
            'retry_after': 42,
          }),
          429,
          headers: {'retry-after': '7'},
        ),
      );

      expect(
        () => ApiClient.post('/api/me/email', {'email': 'a@b.c'}),
        throwsA(
          isA<ApiException>()
              .having((e) => e.retryAfter, 'retryAfter', 42)
              .having((e) => e.message, 'message', contains('42 秒')),
        ),
      );
    });

    test('body 沒有時改讀 Retry-After header', () async {
      ApiClient.httpClient = MockClient(
        (_) async => http.Response('Too Many', 429, headers: {'retry-after': '7'}),
      );

      expect(
        () => ApiClient.get('/api/ping'),
        throwsA(isA<ApiException>().having((e) => e.retryAfter, 'retryAfter', 7)),
      );
    });

    test('都沒有時 retryAfter 為 null、沿用固定文案', () async {
      ApiClient.httpClient = MockClient((_) async => http.Response('', 429));

      expect(
        () => ApiClient.get('/api/ping'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.retryAfter, 'retryAfter', isNull)
              .having((e) => e.message, 'message', '操作太頻繁，請稍後再試'),
        ),
      );
    });
  });

  test('410 ACCOUNT_PURGED 解析為 isAccountPurged', () {
    final e = ApiException(statusCode: 410, code: 'ACCOUNT_PURGED', message: '');
    expect(e.isAccountPurged, isTrue);
    expect(e.isUnauthorized, isFalse);
  });

  testWidgets('403 ACCOUNT_PENDING_DELETION 導去 /account-pending', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        routes: {
          '/': (_) => const Text('home'),
          '/account-pending': (_) => const Text('pending'),
          '/terms-consent': (_) => const Text('consent'),
        },
      ),
    );
    ApiClient.httpClient = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'error': {'code': 'ACCOUNT_PENDING_DELETION', 'message': 'x'},
        }),
        403,
      ),
    );

    await tester.runAsync(() async {
      await expectLater(
        ApiClient.get('/api/me'),
        throwsA(isA<ApiException>().having(
          (e) => e.isAccountPendingDeletion,
          'isAccountPendingDeletion',
          isTrue,
        )),
      );
    });
    await tester.pumpAndSettle();

    expect(find.text('pending'), findsOneWidget);
    expect(find.text('home'), findsNothing);
  });

  group('403 ACCOUNT_LOCKED', () {
    tearDown(() => accountLockController.setLocked(false));

    testWidgets('切到唯讀模式並顯示統一提示', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          scaffoldMessengerKey: scaffoldMessengerKey,
          home: const Scaffold(body: Text('home')),
        ),
      );
      ApiClient.httpClient = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'error': {'code': 'ACCOUNT_LOCKED', 'message': '後端訊息'},
          }),
          403,
          headers: _utf8Json,
        ),
      );

      await tester.runAsync(() async {
        await expectLater(
          ApiClient.post('/api/forum/posts/1/like'),
          throwsA(isA<ApiException>().having(
            (e) => e.isAccountLocked,
            'isAccountLocked',
            isTrue,
          )),
        );
      });
      await tester.pump();
      await tester.pump();

      expect(accountLockController.locked, isTrue);
      expect(find.text(readOnlyMessage), findsOneWidget);
      expect(find.text('home'), findsOneWidget);
    });

    test('其他 403 不影響唯讀狀態', () async {
      ApiClient.httpClient = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'error': {'code': 'FORBIDDEN', 'message': 'x'},
          }),
          403,
        ),
      );

      await expectLater(ApiClient.get('/api/ping'), throwsA(isA<ApiException>()));
      expect(accountLockController.locked, isFalse);
    });
  });

  test('MUTED 帶 mute_until 時解析到期時間並接在訊息後', () async {
    ApiClient.httpClient = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'error': {
            'code': 'MUTED',
            'message': '你目前被禁言，暫時無法發表內容',
            'mute_until': '2026-10-01T04:30:00.000Z',
          },
        }),
        403,
        headers: _utf8Json,
      ),
    );
    final until = DateTime.utc(2026, 10, 1, 4, 30).toLocal();

    await expectLater(
      ApiClient.post('/api/forum/posts'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.muteUntil, 'muteUntil', until)
            .having(
              (e) => e.message,
              'message',
              '你目前被禁言，暫時無法發表內容（至 ${formatMuteUntil(until)}）',
            ),
      ),
    );
  });

  testWidgets('/api/account/* 的 403 PENDING 不重複導頁', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        routes: {
          '/': (_) => const Text('home'),
          '/account-pending': (_) => const Text('pending'),
        },
      ),
    );
    ApiClient.httpClient = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'error': {'code': 'ACCOUNT_PENDING_DELETION', 'message': 'x'},
        }),
        403,
      ),
    );

    await tester.runAsync(() async {
      await expectLater(
        ApiClient.get('/api/account/export'),
        throwsA(isA<ApiException>()),
      );
    });
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
  });
}
