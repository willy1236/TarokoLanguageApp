// 隨機配對視訊檢舉：打的路徑、body 與錯誤往上拋（呼叫端的檢舉面板靠例外顯示失敗）。

import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/services/video_call_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ApiClient 經 AuthService.currentToken() 讀 flutter_secure_storage，測試環境
  // 沒有原生實作，mock 成回 null（視為未登入）。
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async => null,
        );
  });
  tearDown(() => ApiClient.httpClient = http.Client());

  late List<http.Request> seen;

  void respondWith(Map<String, dynamic> body, {required int status}) {
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

  group('VideoCallService.reportSession', () {
    test('POST /api/video/session/:id/report，body 帶 reason', () async {
      respondWith({'ok': true}, status: 201);

      await VideoCallService.reportSession(42, '騷擾');

      expect(seen, hasLength(1));
      expect(seen.single.method, 'POST');
      expect(seen.single.url.path, '/api/video/session/42/report');
      expect(jsonDecode(seen.single.body), {'reason': '騷擾'});
    });

    test('後端回錯誤時丟 ApiException，帶 code 與 message', () async {
      respondWith({
        'error': {'code': 'NOT_FOUND', 'message': 'session 不存在'},
      }, status: 404);

      await expectLater(
        VideoCallService.reportSession(42, '騷擾'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 404)
              .having((e) => e.code, 'code', 'NOT_FOUND')
              .having((e) => e.message, 'message', 'session 不存在'),
        ),
      );
    });
  });
}
