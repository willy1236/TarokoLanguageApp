// ignore_for_file: avoid_print
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';

import 'package:flutter_application_1/core/constants/api.dart';
import 'package:flutter_application_1/firebase_options.dart';

// ============================================================
// API Inspector — 直接用裝置上的登入 token 打所有端點
//
// 使用方式：
//   1. 先在裝置上開 app 並完成 Google 登入
//   2. flutter test integration_test/api_inspector_test.dart -d <device_id>
//
// 新增端點測試時，在下方 group 裡加一行 test() 即可。
// ============================================================

String? _token;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    const storage = FlutterSecureStorage();
    _token = await storage.read(key: 'session_token');

    print('\n========================================');
    print('  API INSPECTOR');
    print('  Base URL: ${ApiConfig.baseUrl}');
    if (_token != null) {
      print('  Token: ${_token!.substring(0, 20)}... (${_token!.length} chars)');
    } else {
      print('  Token: ✗ 未登入 — 請先開 app 完成 Google 登入');
    }
    print('========================================\n');
  });

  group('API Inspector', () {
    test('GET /api/health', () => _inspect('GET', ApiConfig.health));
    test('GET /api/me', () => _inspect('GET', ApiConfig.me));
    test('GET /api/levels', () => _inspect('GET', ApiConfig.levels));
    test('POST /api/quiz/start', () => _inspect(
      'POST',
      ApiConfig.quizStart,
      body: {'level': 'beginner'},
    ));
    test('POST /api/quiz/submit (空資料測格式)', () => _inspect(
      'POST',
      ApiConfig.quizSubmit,
      body: {'session_id': '__test__', 'answers': []},
    ));
    test('POST /api/listening/start', () => _inspect(
      'POST',
      ApiConfig.listeningStart,
      body: {'level': 'beginner'},
    ));
    test('POST /api/listening/submit (空資料測格式)', () => _inspect(
      'POST',
      ApiConfig.listeningSubmit,
      body: {'session_id': '__test__', 'answers': []},
    ));
    test('GET /api/videos', () => _inspect('GET', ApiConfig.videos));
    test('GET /api/videos?sort=popular', () => _inspect(
      'GET',
      '${ApiConfig.videos}?sort=popular',
    ));
    test('GET /api/videos/1', () => _inspect('GET', ApiConfig.videoDetail(1)));
    test('GET /api/videos/999999 (測 404 格式)', () => _inspect(
      'GET',
      ApiConfig.videoDetail(999999),
    ));
  });
}

Future<void> _inspect(
  String method,
  String path, {
  Map<String, dynamic>? body,
}) async {
  if (_token == null) {
    markTestSkipped('未登入 — 請先開 app 完成 Google 登入');
    return;
  }

  final uri = Uri.parse('${ApiConfig.baseUrl}$path');
  final headers = {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $_token',
  };

  final http.Response response;
  if (method == 'GET') {
    response = await http.get(uri, headers: headers);
  } else {
    response = await http.post(
      uri,
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );
  }

  String prettyBody;
  try {
    final decoded = jsonDecode(response.body);
    prettyBody = const JsonEncoder.withIndent('  ').convert(decoded);
  } catch (_) {
    prettyBody = response.body;
  }

  print('--- $method $path ---');
  print('Status: ${response.statusCode}');
  print(prettyBody);
  print('');
}
