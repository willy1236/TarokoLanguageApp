// ignore_for_file: avoid_print
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';

import 'package:flutter_application_1/core/constants/api.dart';
import 'package:flutter_application_1/firebase_options.dart';

import 'helpers/contract.dart';
import 'helpers/test_auth.dart';

// ============================================================
// API Inspector — 用裝置上的 Google 帳號自動登入後打所有端點
//
// 使用方式：
//   1. 首次在該裝置上開 app 用 Google 登入一次（完成授權）即可
//   2. flutter test integration_test/api_inspector_test.dart -d <device_id>
//      測試會自動靜默登入取得 token；靜默失敗時會叫出帳號選擇，手動點一次。
//
// 新增端點測試時，在下方 group 裡加一行 test() 即可；
// 帶 shape: 參數就會斷言回應格式（見 helpers/contract.dart）。
//
// 錄製 fixture（供 test/contract/ 離線回放，後端格式漂移時不必等實機）：
//   flutter test integration_test/api_inspector_test.dart -d <device> \
//       --dart-define=RECORD_FIXTURES=true > fixtures.log
//   dart run tool/extract_fixtures.dart fixtures.log
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
    test('GET /api/me', () => _inspect(
      'GET',
      ApiConfig.me,
      shape: _meShape,
      optional: _meOptional,
    ));
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
    // levels 的每一筆只要有 code/label/level 其一即可（LevelInfo.fromJson 三擇一），
    // 不是單一必要欄位，因此這裡只驗外層是清單。
    test('GET /api/levels', () => _inspect(
      'GET',
      ApiConfig.levels,
      shape: {'levels': F.list},
    ));
    // level 必須是 /api/levels 實際回傳的值（目前是「初級/中級/中高級/高級」），
    // 寫死英文代號會被後端擋成 400 INVALID_REQUEST。
    test('POST /api/quiz/start', () async {
      final level = await _firstLevel();
      if (level == null) {
        markTestSkipped('拿不到 /api/levels，無法決定合法的 level');
        return;
      }
      await _inspect(
        'POST',
        ApiConfig.quizStart,
        body: {'level': level},
        shape: _quizSessionShape,
        unwrap: true,
      );
    });
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
    test('POST /api/listening/start', () async {
      final level = await _firstLevel();
      if (level == null) {
        markTestSkipped('拿不到 /api/levels，無法決定合法的 level');
        return;
      }
      await _inspect(
        'POST',
        ApiConfig.listeningStart,
        body: {'mode': 'word_to_zh', 'level': level},
        shape: _listeningSessionShape,
        unwrap: true,
      );
    });
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
    test('GET /api/shop/items', () => _inspect(
      'GET',
      ApiConfig.shopItems,
      shape: {'items': F.list},
      listKey: 'items',
      itemShape: _shopItemShape,
      itemOptional: _shopItemOptional,
    ));
    test('GET /api/videos', () => _inspect(
      'GET',
      ApiConfig.videos,
      shape: {'videos': F.list},
      optional: {'total': F.number, 'page': F.number, 'page_size': F.number,
        'sort': F.string},
      listKey: 'videos',
      itemShape: _videoSummaryShape,
      itemOptional: _videoSummaryOptional,
    ));
    test('GET /api/videos?sort=popular', () => _inspect(
      'GET',
      '${ApiConfig.videos}?sort=popular',
      shape: {'videos': F.list},
      listKey: 'videos',
      itemShape: _videoSummaryShape,
      itemOptional: _videoSummaryOptional,
    ));
    test('GET /api/videos/1', () => _inspect(
      'GET',
      ApiConfig.videoDetail(1),
      fixtureAs: 'get_api_video_detail.json',
      shape: _videoDetailShape,
      optional: _videoSummaryOptional,
    ));
    test('GET /api/videos/999999 (測 404 格式)', () => _inspect(
      'GET',
      ApiConfig.videoDetail(999999),
      expectStatus: 404,
      expectError: true,
    ));

    test('GET /api/events?scope=all (找已結束的活動)', () => _inspect(
      'GET',
      '${ApiConfig.events}?scope=all',
      shape: {'events': F.list},
      listKey: 'events',
      itemShape: _eventSummaryShape,
      itemOptional: _eventSummaryOptional,
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
      await _inspect(
        'GET',
        ApiConfig.eventDetail(endedId),
        fixtureAs: 'get_api_event_detail.json',
        shape: _eventDetailShape,
        optional: _eventDetailOptional,
      );
    });

    // 影音/文章/活動/論壇搜尋（q/range/tribe_id 皆選填，見 backend/searchQuery.ts）
    test('GET /api/videos/search', () => _inspect(
      'GET',
      '${ApiConfig.videoSearch}?q=a&range=1m',
      shape: {'videos': F.list},
      listKey: 'videos',
      itemShape: _videoSummaryShape,
      itemOptional: _videoSummaryOptional,
    ));
    test('GET /api/articles/search', () => _inspect(
      'GET',
      '${ApiConfig.articleSearch}?q=a&range=1m',
      shape: {'articles': F.list},
      listKey: 'articles',
      itemShape: _articleSummaryShape,
      itemOptional: _articleSummaryOptional,
    ));
    test('GET /api/events/search', () => _inspect(
      'GET',
      '${ApiConfig.eventSearch}?q=a&range=1m',
      shape: {'events': F.list},
      listKey: 'events',
      itemShape: _eventSummaryShape,
      itemOptional: _eventSummaryOptional,
    ));
    test('GET /api/forum/search (range/tribe_id)', () => _inspect(
      'GET',
      '${ApiConfig.forumSearch}?q=a&range=1m',
      shape: {'posts': F.list},
    ));

    // 2026-09 後端更新（見 Truku_backend 說明文件/前端交接/2026-09_更新與待接清單.md）。
    // 刪除帳號、匯出資料、寄驗證信屬於有副作用或受每分鐘 5 次限流的端點，不在此自動打。
    test('GET /api/terms (確認 tos v5 / privacy v10 已發布)', () => _inspect(
      'GET',
      ApiConfig.terms,
      shape: {'documents': F.list},
      optional: {'all_consented': F.boolean},
      listKey: 'documents',
      itemShape: _termsDocShape,
      itemNullable: {'consented_version'},
      itemOptional: {'consented_version': F.number},
    ));
    test('GET /api/account/status', () => _inspect(
      'GET',
      ApiConfig.accountStatus,
      shape: {'status': F.string},
      optional: {'purge_at': F.string},
    ));
    // NotificationSummary 每個欄位都有 ?? 0，缺欄位不會壞，但全缺代表端點掛了，
    // 所以這裡把五個計數都列必要、允許為 null。
    test('GET /api/notifications/summary', () => _inspect(
      'GET',
      ApiConfig.notificationsSummary,
      shape: {
        'forum': F.number,
        'events': F.number,
        'messages': F.number,
        'friend_requests': F.number,
        'total': F.number,
      },
      nullable: {'forum', 'events', 'messages', 'friend_requests', 'total'},
    ));
    test('GET /api/search/history?module=forum', () => _inspect(
      'GET',
      '${ApiConfig.searchHistory}?module=forum',
      shape: {'history': F.list},
      listKey: 'history',
      itemShape: {'q': F.string},
    ));
    // popular 的每一筆可能是 {q: ...} 也可能是純字串（SearchAssistService 兩者都收），
    // 因此只驗外層是清單。
    test('GET /api/search/popular?module=forum', () => _inspect(
      'GET',
      '${ApiConfig.searchPopular}?module=forum',
      shape: {'popular': F.list},
    ));
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

/// 取 /api/levels 的第一個等級代號，給 quiz／listening 的 start 當合法 level 用。
/// 等級是中文（初級／中級／中高級／高級），寫死英文代號會被擋成 400。
Future<String?> _firstLevel() async {
  if (_token == null) return null;
  final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.levels}');
  final response = await http.get(uri, headers: {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $_token',
  });
  if (response.statusCode != 200) return null;
  final decoded = jsonDecode(response.body) as Map<String, dynamic>;
  final levels = decoded['levels'] as List<dynamic>? ?? const [];
  if (levels.isEmpty) return null;
  final first = levels.first as Map<String, dynamic>;
  return (first['code'] ?? first['label'] ?? first['level']) as String?;
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

/// 打一支端點：印出回應、（若有給 [shape]）斷言格式、（錄製模式下）輸出 fixture。
///
/// [shape] 描述最外層 object 的必要欄位；要逐筆檢查清單時給 [listKey] + [itemShape]。
/// 測錯誤格式時給 [errorCode] 與對應的 [expectStatus]。
/// 都不給就維持原本「只印不驗」的偵察行為。
Future<void> _inspect(
  String method,
  String path, {
  Map<String, dynamic>? body,
  Map<String, F>? shape,
  Set<String> nullable = const {},
  Map<String, F> optional = const {},
  String? listKey,
  Map<String, F>? itemShape,
  Set<String> itemNullable = const {},
  Map<String, F> itemOptional = const {},
  int expectStatus = 200,
  /// 指定 fixture 檔名。路徑含動態 id（例如 /api/events/123）時必須給，
  /// 否則每次錄製都會產生不同檔名，離線測試對不上。
  String? fixtureAs,
  bool unwrap = false,
  bool expectError = false,
  String? errorCode,
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

  recordFixture(method, path, response, as: fixtureAs);

  // 沒給契約就只當偵察用，維持原行為。
  if (shape == null && !expectError) return;

  expect(response.statusCode, expectStatus,
      reason: '$method $path 狀態碼不符\n${response.body}');

  if (expectError) {
    expectErrorShape(response, code: errorCode);
    return;
  }

  var decoded = jsonDecode(response.body);
  // 部分端點包了 {data: {...}} 信封（service 端用 ApiClient.unwrapData 拆）。
  if (unwrap && decoded is Map<String, dynamic> && decoded['data'] != null) {
    decoded = decoded['data'];
  }
  expectShape(decoded, shape!,
      nullable: nullable, optional: optional, label: '$method $path');

  if (listKey != null && itemShape != null) {
    expectEachShape((decoded as Map<String, dynamic>)[listKey], itemShape,
        nullable: itemNullable,
        optional: itemOptional,
        label: '$method $path.$listKey');
  }
}

// ============================================================
// 契約定義
//
// 判準：只有「fromJson 少了它就會丟例外」的欄位才列為必要（spec），
// 其餘一律列 optional。這樣測試紅的時候就等於 app 真的會壞，
// 而後端新增欄位或補 nullable 不會誤報。
// 每個 shape 旁註明對應的 lib/models/*.dart。
// ============================================================

/// GET /api/me → lib/models/user_model.dart UserModel.fromJson
/// 只有 uid / created_at 是硬性（`as int` / `DateTime.parse`），其餘皆有預設值。
const Map<String, F> _meShape = {
  'uid': F.number,
  'created_at': F.string,
};
const Map<String, F> _meOptional = {
  'display_name': F.string,
  'avatar_url': F.string,
  'avatar_id': F.string,
  'frame_id': F.string,
  'owned_avatar_ids': F.list,
  'owned_frame_ids': F.list,
  'millet': F.number,
  'email': F.string,
  'email_verified': F.boolean,
  'email_is_custom': F.boolean,
  'checked_in_today': F.boolean,
  'checkin_streak': F.number,
  'ethnic_group': F.string,
  'tribe_id': F.number,
  'tribe_name': F.string,
  'video_nickname': F.string,
  'is_indigenous': F.boolean,
  'tribal_name': F.string,
  'profile_completed': F.boolean,
  'self_intro': F.string,
  'friend_code': F.string,
  'quiz_suggested_level': F.string,
  'listening_suggested_level': F.string,
  'study_streak': F.number,
  'video_call_count': F.number,
  'forum_post_count': F.number,
  'role': F.string,
  'provider': F.string,
  'updated_at': F.string,
  'last_login_at': F.string,
};

/// GET /api/shop/items → lib/models/shop_item.dart ShopItem.fromJson
const Map<String, F> _shopItemShape = {
  'id': F.string,
  'type': F.string,
  'name': F.string,
  'price': F.number,
};
const Map<String, F> _shopItemOptional = {
  'rarity': F.string,
  'unlock_condition': F.string,
  'image_url': F.string,
  'is_owned': F.boolean,
};

/// GET /api/videos → lib/models/video_models.dart VideoSummary.fromJson
const Map<String, F> _videoSummaryShape = {
  'id': F.number,
  'title': F.string,
  'category': F.string,
};
const Map<String, F> _videoSummaryOptional = {
  'description': F.string,
  'duration_sec': F.number,
  'thumbnail_url': F.string,
  'view_count': F.number,
  'weekly_view_count': F.number,
  'like_count': F.number,
  'is_liked': F.boolean,
  'is_bookmarked': F.boolean,
  'published_at': F.string,
};

/// GET /api/videos/:id → VideoDetail.fromJson（比 summary 多 hls_url）
const Map<String, F> _videoDetailShape = {
  'id': F.number,
  'title': F.string,
  'category': F.string,
  'hls_url': F.string,
};

/// GET /api/articles/search → lib/models/article_models.dart ArticleSummary
const Map<String, F> _articleSummaryShape = {
  'id': F.number,
  'title': F.string,
  'category': F.string,
};
const Map<String, F> _articleSummaryOptional = {
  'summary': F.string,
  'cover_image_url': F.string,
  'view_count': F.number,
  'weekly_view_count': F.number,
  'like_count': F.number,
  'is_liked': F.boolean,
  'is_bookmarked': F.boolean,
  'published_at': F.string,
};

/// GET /api/events → lib/models/event_model.dart EventSummary.fromJson
/// id 用 F.any：後端曾回字串型 id，前端以 asEventInt() 寬鬆解析，不該因此變紅。
const Map<String, F> _eventSummaryShape = {
  'id': F.any,
  'title': F.string,
  'starts_at': F.string,
};
const Map<String, F> _eventSummaryOptional = {
  'host_uid': F.any,
  'location': F.string,
  'max_participants': F.any,
  'category': F.string,
  'status': F.string,
  'participant_count': F.any,
  'is_joined': F.boolean,
  'registration_deadline': F.string,
  'effective_status': F.string,
  'registration_open': F.boolean,
  'like_count': F.any,
  'is_liked': F.boolean,
  'is_bookmarked': F.boolean,
};

/// GET /api/terms → lib/models/terms_models.dart TermsDocument.fromJson
const Map<String, F> _termsDocShape = {
  'doc_type': F.string,
  'version': F.number,
  'title': F.string,
  'content_md': F.string,
  'published_at': F.string,
  'consented': F.boolean,
};

/// POST /api/quiz/start → lib/models/quiz_models.dart QuizSession.fromJson
const Map<String, F> _quizSessionShape = {
  'session_id': F.string,
  'questions': F.list,
};

/// POST /api/listening/start → lib/models/listening_models.dart ListeningSession
const Map<String, F> _listeningSessionShape = {
  'session_id': F.string,
  'mode': F.string,
  'level': F.string,
  'questions': F.list,
};

/// GET /api/events/:id → lib/models/event_model.dart EventDetail.fromJson
/// 比 summary 多一個硬性 host_uid（`asEventInt(...)!`）。
const Map<String, F> _eventDetailShape = {
  'id': F.any,
  'host_uid': F.any,
  'title': F.string,
  'starts_at': F.string,
};
const Map<String, F> _eventDetailOptional = {
  ..._eventSummaryOptional,
  'description': F.string,
  'address': F.string,
  'contact_email': F.string,
  'contact_phone': F.string,
  'reminder_note': F.string,
  'created_at': F.string,
  'participants': F.list,
};
