import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_1/core/network/api_client.dart';

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
}
