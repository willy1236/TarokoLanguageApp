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
        (_) async =>
            http.Response('Too Many', 429, headers: {'retry-after': '7'}),
      );

      expect(
        () => ApiClient.get('/api/ping'),
        throwsA(
          isA<ApiException>().having((e) => e.retryAfter, 'retryAfter', 7),
        ),
      );
    });

    test('業務邏輯的 429（無 retry_after）保留後端 code 與訊息', () async {
      ApiClient.httpClient = MockClient(
        (_) async => http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'error': {
                'code': 'FRIEND_REQUEST_LIMIT',
                'message': '24 小時內最多送出 30 個好友邀請，請明天再試',
              },
            }),
          ),
          429,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      );

      expect(
        () => ApiClient.post('/api/friends/requests', {'uid': 1}),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', 'FRIEND_REQUEST_LIMIT')
              .having((e) => e.message, 'message', contains('30 個好友邀請')),
        ),
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
    final e = ApiException(
      statusCode: 410,
      code: 'ACCOUNT_PURGED',
      message: '',
    );
    expect(e.isAccountPurged, isTrue);
    expect(e.isUnauthorized, isFalse);
  });

  testWidgets('403 ACCOUNT_PENDING_DELETION 導去 /account-pending', (
    tester,
  ) async {
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
        throwsA(
          isA<ApiException>().having(
            (e) => e.isAccountPendingDeletion,
            'isAccountPendingDeletion',
            isTrue,
          ),
        ),
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
          throwsA(
            isA<ApiException>().having(
              (e) => e.isAccountLocked,
              'isAccountLocked',
              isTrue,
            ),
          ),
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

      await expectLater(
        ApiClient.get('/api/ping'),
        throwsA(isA<ApiException>()),
      );
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

  test('PROFANITY 未禁言時原樣用後端訊息，muted=true 才接到期時間', () async {
    Future<ApiException> errorFor(Map<String, dynamic> error) async {
      ApiClient.httpClient = MockClient(
        (_) async => http.Response(
          jsonEncode({'error': error}),
          400,
          headers: _utf8Json,
        ),
      );
      try {
        await ApiClient.post('/api/forum/posts');
      } on ApiException catch (e) {
        return e;
      }
      fail('應丟出 ApiException');
    }

    final warned = await errorFor({
      'code': 'PROFANITY',
      'muted': false,
      'message': '內容含不當用語，未送出',
    });
    expect(warned.isProfanity, isTrue);
    expect(warned.muteUntil, isNull);
    expect(warned.message, '內容含不當用語，未送出');

    final muted = await errorFor({
      'code': 'PROFANITY',
      'muted': true,
      'mute_until': '2026-09-26T10:00:00.000Z',
      'message': '暫停發言 24 小時',
    });
    final until = DateTime.utc(2026, 9, 26, 10).toLocal();
    expect(muted.muteUntil, until);
    expect(muted.message, '暫停發言 24 小時（至 ${formatMuteUntil(until)}）');
  });

  test('410 下架內容不當成帳號已刪除', () {
    for (final code in [
      'ARTICLE_ARCHIVED',
      'VIDEO_ARCHIVED',
      'SESSION_ENDED',
    ]) {
      final e = ApiException(statusCode: 410, code: code, message: '');
      expect(e.isAccountPurged, isFalse, reason: code);
    }
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

  _serviceBusyTests();
}

// 503 SERVICE_BUSY：GET 依 retry_after 自動重送一次，寫入類不重送。
void _serviceBusyTests() {
  http.Response busy() => http.Response(
    jsonEncode({
      'error': {'code': 'SERVICE_BUSY', 'message': '伺服器忙碌中，請稍後再試'},
      'retry_after': 5,
    }),
    503,
    headers: _utf8Json,
  );

  // 重送前等待 = retry_after 秒數 + 0–1 秒隨機值，避免大量裝置同時重送。
  Matcher waits(int seconds) => allOf(
    greaterThanOrEqualTo(Duration(seconds: seconds)),
    lessThan(Duration(seconds: seconds + 1)),
  );

  group('503 SERVICE_BUSY', () {
    final delays = <Duration>[];
    setUp(() {
      delays.clear();
      ApiClient.busyRetryDelay = (d) async => delays.add(d);
    });
    tearDown(() => ApiClient.busyRetryDelay = Future.delayed);

    test('GET 等 retry_after 秒後重送一次，成功就正常回傳', () async {
      var calls = 0;
      ApiClient.httpClient = MockClient((_) async {
        calls++;
        return calls == 1 ? busy() : http.Response(jsonEncode({'ok': 1}), 200);
      });

      expect(await ApiClient.get('/api/levels'), {'ok': 1});
      expect(calls, 2);
      expect(delays, [waits(5)]);
    });

    test('GET 重送仍 503：顯示忙碌訊息，不再重試', () async {
      var calls = 0;
      ApiClient.httpClient = MockClient((_) async {
        calls++;
        return busy();
      });

      await expectLater(
        ApiClient.get('/api/levels'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.isServiceBusy, 'isServiceBusy', isTrue)
              .having((e) => e.message, 'message', '伺服器忙碌，請稍後再試')
              .having((e) => e.retryAfter, 'retryAfter', 5),
        ),
      );
      expect(calls, 2);
    });

    test('依 retry_after 秒數等待（body 或 Retry-After header）', () async {
      for (final resp in [
        http.Response(
          jsonEncode({
            'error': {'code': 'SERVICE_BUSY', 'message': 'busy'},
            'retry_after': 3,
          }),
          503,
        ),
        http.Response(
          jsonEncode({
            'error': {'code': 'SERVICE_BUSY', 'message': 'busy'},
          }),
          503,
          headers: {'retry-after': '17'},
        ),
      ]) {
        var calls = 0;
        ApiClient.httpClient = MockClient((_) async {
          calls++;
          return calls == 1 ? resp : http.Response('{}', 200);
        });
        await ApiClient.get('/api/levels');
      }
      expect(delays, [waits(3), waits(17)]);
    });

    test('等待秒數加上隨機值，不會每次都剛好整數秒', () async {
      for (var i = 0; i < 5; i++) {
        var calls = 0;
        ApiClient.httpClient = MockClient((_) async {
          calls++;
          return calls == 1 ? busy() : http.Response('{}', 200);
        });
        await ApiClient.get('/api/levels');
      }
      expect(delays, everyElement(waits(5)));
      expect(delays.any((d) => d > const Duration(seconds: 5)), isTrue);
    });

    test('retry_after 缺少時等 5 秒', () async {
      var calls = 0;
      ApiClient.httpClient = MockClient((_) async {
        calls++;
        return calls == 1
            ? http.Response(
                jsonEncode({
                  'error': {'code': 'SERVICE_BUSY', 'message': 'busy'},
                }),
                503,
              )
            : http.Response('{}', 200);
      });

      await ApiClient.get('/api/levels');
      expect(delays, [waits(5)]);
    });

    for (final method in ['POST', 'PATCH', 'DELETE']) {
      test('$method 不重送，直接顯示忙碌訊息', () async {
        var calls = 0;
        ApiClient.httpClient = MockClient((_) async {
          calls++;
          return busy();
        });

        final future = switch (method) {
          'POST' => ApiClient.post('/api/thing'),
          'PATCH' => ApiClient.patch('/api/thing'),
          _ => ApiClient.delete('/api/thing'),
        };
        await expectLater(
          future,
          throwsA(
            isA<ApiException>().having(
              (e) => e.message,
              'message',
              '伺服器忙碌，請稍後再試',
            ),
          ),
        );
        expect(calls, 1);
        expect(delays, isEmpty);
      });
    }

    test('503 VIDEO_UNAVAILABLE 不重送，行為不變', () async {
      var calls = 0;
      ApiClient.httpClient = MockClient((_) async {
        calls++;
        return http.Response(
          jsonEncode({
            'error': {'code': 'VIDEO_UNAVAILABLE', 'message': '視訊暫停'},
          }),
          503,
          headers: _utf8Json,
        );
      });

      await expectLater(
        ApiClient.get('/api/video/session/current'),
        throwsA(
          isA<ApiException>().having((e) => e.isVideoUnavailable, 'v', isTrue),
        ),
      );
      expect(calls, 1);
    });

    for (final (status, code) in [
      (413, 'PAYLOAD_TOO_LARGE'),
      (400, 'INVALID_REQUEST'),
    ]) {
      test('$status $code 照一般錯誤顯示 error.message', () async {
        ApiClient.httpClient = MockClient(
          (_) async => http.Response(
            jsonEncode({
              'error': {'code': code, 'message': '後端訊息'},
            }),
            status,
            headers: _utf8Json,
          ),
        );

        await expectLater(
          ApiClient.post('/api/thing'),
          throwsA(
            isA<ApiException>().having((e) => e.message, 'message', '後端訊息'),
          ),
        );
      });
    }
  });
}
