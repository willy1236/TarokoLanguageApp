// ignore_for_file: avoid_print
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';

import 'package:flutter_application_1/core/constants/api.dart';
import 'package:flutter_application_1/firebase_options.dart';

import 'helpers/test_auth.dart';

// ============================================================
// API Inspector — 用裝置上的 Google 帳號自動登入後打所有端點
//
// 使用方式：
//   1. 首次在該裝置上開 app 用 Google 登入一次（完成授權）即可
//   2. flutter test integration_test/api_inspector_test.dart -d <device_id>
//      測試會自動靜默登入取得 token；靜默失敗時會叫出帳號選擇，手動點一次。
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
    // 自動用裝置上的 Google 帳號登入（靜默優先＋互動備援）
    await ensureLoggedIn();
    const storage = FlutterSecureStorage();
    _token = await storage.read(key: 'session_token');

    print('\n========================================');
    print('  API INSPECTOR');
    print('  Base URL: ${ApiConfig.baseUrl}');
    if (_token != null) {
      print('  Token: ${_token!.substring(0, 20)}... (${_token!.length} chars)');
    } else {
      print('  Token: ✗ 自動登入失敗 — 請先在此裝置開 app 用 Google 登入一次');
    }
    print('========================================\n');
  });

  group('API Inspector', () {
    test('GET /api/health', () => _inspect('GET', ApiConfig.health));
    test('GET /api/me', () => _inspect('GET', ApiConfig.me));
    test('PATCH /api/me (display_name 回傳格式測試，測完自動還原)', () async {
      if (_token == null) {
        markTestSkipped('未登入 — 請先開 app 完成 Google 登入');
        return;
      }
      final original = await _fetchDisplayName();
      await _inspect(
        'PATCH',
        ApiConfig.me,
        body: {'display_name': 'API Inspector Test'},
      );
      if (original != null) {
        await _inspect('PATCH', ApiConfig.me, body: {'display_name': original});
      }
    });
    test('PATCH /api/me (is_indigenous/tribal_name 回傳格式測試，測完自動還原)',
        () async {
      if (_token == null) {
        markTestSkipped('未登入 — 請先開 app 完成 Google 登入');
        return;
      }
      final original = await _fetchIdentityFields();
      await _inspect(
        'PATCH',
        ApiConfig.me,
        body: {'is_indigenous': true, 'tribal_name': 'API Inspector Test'},
      );
      // 再打一次確認是否遭 IDENTITY_LOCKED（族群/部落尚未設定應該不會鎖）
      await _inspect(
        'PATCH',
        ApiConfig.me,
        body: {'tribal_name': 'API Inspector Test 2'},
      );
      if (original != null) {
        await _inspect(
          'PATCH',
          ApiConfig.me,
          body: {
            'is_indigenous': original['is_indigenous'],
            'tribal_name': original['tribal_name'],
          },
        );
      }
    });
    test('POST /api/me/avatar (multipart 上傳格式測試)', () => _inspectAvatarUpload());
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
    test('POST /api/quiz/placement/start', () => _inspect(
      'POST',
      ApiConfig.quizPlacementStart,
    ));
    test('PATCH /api/quiz/placement/answer (空資料測格式)', () => _inspect(
      'PATCH',
      ApiConfig.quizPlacementAnswer,
      body: {
        'session_id': '__test__',
        'question_id': '__test__',
        'selected_option_id': 0,
      },
    ));
    test('POST /api/quiz/placement/submit (空資料測格式)', () => _inspect(
      'POST',
      ApiConfig.quizPlacementSubmit,
      body: {'session_id': '__test__', 'answers': []},
    ));
    test('POST /api/listening/start', () => _inspect(
      'POST',
      ApiConfig.listeningStart,
      body: {'mode': 'word_to_zh', 'level': 'beginner'},
    ));
    test('PATCH /api/listening/answer (空資料測格式)', () => _inspect(
      'PATCH',
      ApiConfig.listeningAnswer,
      body: {
        'session_id': '__test__',
        'question_id': '__test__',
        'selected_option_id': 0,
      },
    ));
    test('POST /api/listening/submit (空資料測格式)', () => _inspect(
      'POST',
      ApiConfig.listeningSubmit,
      body: {'session_id': '__test__', 'answers': []},
    ));
    test('POST /api/listening/placement/start', () => _inspect(
      'POST',
      ApiConfig.listeningPlacementStart,
    ));
    test('PATCH /api/listening/placement/answer (空資料測格式)', () => _inspect(
      'PATCH',
      ApiConfig.listeningPlacementAnswer,
      body: {
        'session_id': '__test__',
        'question_id': '__test__',
        'selected_option_id': 0,
      },
    ));
    test('POST /api/listening/placement/submit (空資料測格式)', () => _inspect(
      'POST',
      ApiConfig.listeningPlacementSubmit,
      body: {'session_id': '__test__', 'answers': []},
    ));
    test('GET /api/shop/items', () => _inspect('GET', ApiConfig.shopItems));
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

    test('GET /api/events?scope=all (找已結束的活動)', () => _inspect(
      'GET',
      '${ApiConfig.events}?scope=all',
    ));
    test('GET /api/events/:id (自動挑第一個 effective_status=ended 的活動測詳情)',
        () async {
      if (_token == null) {
        markTestSkipped('未登入 — 請先開 app 完成 Google 登入');
        return;
      }
      final endedId = await _findEndedEventId();
      if (endedId == null) {
        markTestSkipped('目前沒有任何 effective_status=ended 的活動可測');
        return;
      }
      print('（挑到已結束活動 id=$endedId）');
      await _inspect('GET', ApiConfig.eventDetail(endedId));
    });
  });
}

/// 打 /api/events?scope=all 找第一筆 effective_status == 'ended' 的活動 id。
Future<int?> _findEndedEventId() async {
  final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.events}?scope=all');
  final response = await http.get(uri, headers: {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $_token',
  });
  if (response.statusCode != 200) return null;
  final decoded = jsonDecode(response.body) as Map<String, dynamic>;
  final events = decoded['events'] as List<dynamic>? ?? [];
  for (final e in events) {
    final m = e as Map<String, dynamic>;
    if (m['effective_status'] == 'ended') {
      final id = m['id'];
      return id is int ? id : int.tryParse(id.toString());
    }
  }
  return null;
}

Future<String?> _fetchDisplayName() async {
  final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.me}');
  final response = await http.get(uri, headers: {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $_token',
  });
  if (response.statusCode != 200) return null;
  final decoded = jsonDecode(response.body) as Map<String, dynamic>;
  return decoded['display_name'] as String?;
}

Future<Map<String, dynamic>?> _fetchIdentityFields() async {
  final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.me}');
  final response = await http.get(uri, headers: {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $_token',
  });
  if (response.statusCode != 200) return null;
  final decoded = jsonDecode(response.body) as Map<String, dynamic>;
  return {
    'is_indigenous': decoded['is_indigenous'],
    'tribal_name': decoded['tribal_name'],
  };
}

/// 用一張 1x1 PNG（記憶體產生，不需額外檔案）測 POST /api/me/avatar 的
/// multipart 上傳回應格式（成功與否都印出來看）。
Future<void> _inspectAvatarUpload() async {
  if (_token == null) {
    markTestSkipped('未登入 — 請先開 app 完成 Google 登入');
    return;
  }

  // 1x1 透明 PNG bytes
  final pngBytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  );

  final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.meAvatar}');
  final request = http.MultipartRequest('POST', uri)
    ..headers['Authorization'] = 'Bearer $_token'
    ..files.add(http.MultipartFile.fromBytes(
      'avatar',
      pngBytes,
      filename: 'inspector_test.png',
    ));

  final streamed = await request.send();
  final response = await http.Response.fromStream(streamed);

  String prettyBody;
  try {
    final decoded = jsonDecode(response.body);
    prettyBody = const JsonEncoder.withIndent('  ').convert(decoded);
  } catch (_) {
    prettyBody = response.body;
  }

  print('--- POST ${ApiConfig.meAvatar} (multipart, 1x1 png) ---');
  print('Status: ${response.statusCode}');
  print(prettyBody);
  print('');
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
  switch (method) {
    case 'GET':
      response = await http.get(uri, headers: headers);
    case 'PATCH':
      response = await http.patch(
        uri,
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      );
    default:
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
