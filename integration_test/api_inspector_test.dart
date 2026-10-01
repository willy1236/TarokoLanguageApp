// ignore_for_file: avoid_print
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
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
      print(
        '  Token: ${_token!.substring(0, 20)}... (${_token!.length} chars)',
      );
    } else {
      print('  Token: ✗ 自動登入失敗 — 請先在此裝置開 app 用 Google 登入一次');
    }
    print('========================================\n');
  });

  group('API Inspector', () {
    test('GET /api/health', () => _inspect('GET', ApiConfig.health));
    test(
      'GET /api/me',
      () =>
          _inspect('GET', ApiConfig.me, shape: _meShape, optional: _meOptional),
    );
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
    test('PATCH /api/me (is_indigenous/tribal_name 回傳格式測試，測完自動還原)', () async {
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
    test(
      'POST /api/me/avatar (multipart 上傳格式測試)',
      () => _inspectAvatarUpload(),
    );
    // levels 的每一筆只要有 code/label/level 其一即可（LevelInfo.fromJson 三擇一），
    // 不是單一必要欄位，因此這裡只驗外層是清單。
    test(
      'GET /api/levels',
      () => _inspect('GET', ApiConfig.levels, shape: {'levels': F.list}),
    );
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
    // 放棄舊測驗：先製造等級衝突取得舊 session_id → abandon → 重複 abandon 應 404
    // → 再 start 想要的等級要拿到新測驗。會刪掉測試帳號原本進行中的單字測驗。
    test('POST /api/quiz/abandon (製造衝突後放棄，再重新 start)', () async {
      await _inspectAbandonFlow(
        startPath: ApiConfig.quizStart,
        abandonPath: ApiConfig.quizAbandon,
        startBody: (level) => {'level': level},
      );
    });
    test(
      'POST /api/quiz/submit (空資料測格式)',
      () => _inspect(
        'POST',
        ApiConfig.quizSubmit,
        body: {'session_id': '__test__', 'answers': []},
      ),
    );
    test(
      'POST /api/quiz/placement/start',
      () => _inspect('POST', ApiConfig.quizPlacementStart),
    );
    test(
      'PATCH /api/quiz/placement/answer (空資料測格式)',
      () => _inspect(
        'PATCH',
        ApiConfig.quizPlacementAnswer,
        body: {
          'session_id': '__test__',
          'question_id': '__test__',
          'selected_option_id': 0,
        },
      ),
    );
    test(
      'POST /api/quiz/placement/submit (空資料測格式)',
      () => _inspect(
        'POST',
        ApiConfig.quizPlacementSubmit,
        body: {'session_id': '__test__', 'answers': []},
      ),
    );
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
    // 流程同 /api/quiz/abandon；另一個 mode 先開一份，放棄後確認它仍能續接。
    test('POST /api/listening/abandon (製造衝突後放棄，再重新 start)', () async {
      Map<String, dynamic> body(String mode, String level) => {
        'mode': mode,
        'level': level,
      };
      final levels = await _levelCodes();
      if (levels.isEmpty) {
        markTestSkipped('拿不到 /api/levels，無法決定合法的 level');
        return;
      }
      final other = await _postData(
        ApiConfig.listeningStart,
        body('sentence_to_zh', levels.first),
      );
      await _inspectAbandonFlow(
        startPath: ApiConfig.listeningStart,
        abandonPath: ApiConfig.listeningAbandon,
        startBody: (level) => body('word_to_zh', level),
      );
      if (other == null) return;
      final again = await _postData(
        ApiConfig.listeningStart,
        body('sentence_to_zh', levels.first),
      );
      expect(
        again?['session_id'],
        other['session_id'],
        reason: '放棄 word_to_zh 不應影響 sentence_to_zh 的進行中測驗',
      );
    });
    test(
      'PATCH /api/listening/answer (空資料測格式)',
      () => _inspect(
        'PATCH',
        ApiConfig.listeningAnswer,
        body: {
          'session_id': '__test__',
          'question_id': '__test__',
          'selected_option_id': 0,
        },
      ),
    );
    test(
      'POST /api/listening/submit (空資料測格式)',
      () => _inspect(
        'POST',
        ApiConfig.listeningSubmit,
        body: {'session_id': '__test__', 'answers': []},
      ),
    );
    test(
      'POST /api/listening/placement/start',
      () => _inspect('POST', ApiConfig.listeningPlacementStart),
    );
    test(
      'PATCH /api/listening/placement/answer (空資料測格式)',
      () => _inspect(
        'PATCH',
        ApiConfig.listeningPlacementAnswer,
        body: {
          'session_id': '__test__',
          'question_id': '__test__',
          'selected_option_id': 0,
        },
      ),
    );
    test(
      'POST /api/listening/placement/submit (空資料測格式)',
      () => _inspect(
        'POST',
        ApiConfig.listeningPlacementSubmit,
        body: {'session_id': '__test__', 'answers': []},
      ),
    );
    test(
      'GET /api/shop/items',
      () => _inspect(
        'GET',
        ApiConfig.shopItems,
        shape: {'items': F.list},
        listKey: 'items',
        itemShape: _shopItemShape,
        itemOptional: _shopItemOptional,
      ),
    );
    // 列表分頁統一成 limit＋cursor＋page_info（後端 2026-09-28 加急 API 格式統一 §1）。
    test(
      'GET /api/millet/transactions',
      () => _inspect(
        'GET',
        ApiConfig.milletTransactions,
        shape: {'transactions': F.list, 'page_info': F.object},
      ),
    );
    test(
      'GET /api/forum/posts',
      () => _inspect(
        'GET',
        ApiConfig.forumPosts,
        shape: {'pinned': F.list, 'posts': F.list, 'page_info': F.object},
      ),
    );
    test(
      'GET /api/forum/boards/general/posts',
      () => _inspect(
        'GET',
        ApiConfig.forumBoardPosts('general'),
        shape: {'pinned': F.list, 'posts': F.list, 'page_info': F.object},
      ),
    );
    test('GET /api/forum/posts/:id/comments (自動挑留言最多的貼文)', () async {
      if (_token == null) {
        markTestSkipped('未登入 — 請先開 app 完成 Google 登入');
        return;
      }
      final postId = await _findMostCommentedPostId();
      if (postId == null) {
        markTestSkipped('目前沒有任何有留言的貼文可測');
        return;
      }
      await _inspect(
        'GET',
        ApiConfig.forumPostComments(postId),
        fixtureAs: 'get_api_forum_post_comments.json',
        shape: {'comments': F.list, 'replies': F.list, 'page_info': F.object},
      );
    });
    test(
      'GET /api/forum/bookmarks',
      () => _inspect(
        'GET',
        ApiConfig.forumBookmarks,
        shape: {'posts': F.list, 'page_info': F.object},
      ),
    );
    test(
      'GET /api/forum/posts/likes',
      () => _inspect(
        'GET',
        ApiConfig.forumPostLikes,
        shape: {'posts': F.list, 'page_info': F.object},
      ),
    );
    test(
      'GET /api/forum/comments/likes',
      () => _inspect(
        'GET',
        ApiConfig.forumCommentLikes,
        shape: {'comments': F.list, 'page_info': F.object},
      ),
    );
    test('GET /api/friends/:friend_code/messages (自動挑第一位好友)', () async {
      if (_token == null) {
        markTestSkipped('未登入 — 請先開 app 完成 Google 登入');
        return;
      }
      final friendCode = await _firstFriendCode();
      if (friendCode == null) {
        markTestSkipped('目前沒有好友可測私訊歷史');
        return;
      }
      await _inspect(
        'GET',
        '${ApiConfig.friendMessages(friendCode)}?limit=30',
        fixtureAs: 'get_api_friend_messages.json',
        shape: {'messages': F.list, 'page_info': F.object},
      );
    });
    test(
      'GET /api/videos',
      () => _inspect(
        'GET',
        ApiConfig.videos,
        shape: {'videos': F.list, 'page_info': F.object},
        optional: {'sort': F.string},
        listKey: 'videos',
        itemShape: _videoSummaryShape,
        itemOptional: _videoSummaryOptional,
      ),
    );
    test(
      'GET /api/videos?sort=popular',
      () => _inspect(
        'GET',
        '${ApiConfig.videos}?sort=popular',
        shape: {'videos': F.list, 'page_info': F.object},
        listKey: 'videos',
        itemShape: _videoSummaryShape,
        itemOptional: _videoSummaryOptional,
      ),
    );
    test(
      'GET /api/videos/bookmarks',
      () => _inspect(
        'GET',
        ApiConfig.videoBookmarks,
        shape: {'videos': F.list, 'page_info': F.object},
      ),
    );
    test(
      'GET /api/videos/likes',
      () => _inspect(
        'GET',
        ApiConfig.videoLikes,
        shape: {'videos': F.list, 'page_info': F.object},
      ),
    );
    test(
      'GET /api/articles',
      () => _inspect(
        'GET',
        ApiConfig.articles,
        shape: {'articles': F.list, 'page_info': F.object},
        listKey: 'articles',
        itemShape: _articleSummaryShape,
        itemOptional: _articleSummaryOptional,
      ),
    );
    test(
      'GET /api/articles/bookmarks',
      () => _inspect(
        'GET',
        ApiConfig.articleBookmarks,
        shape: {'articles': F.list, 'page_info': F.object},
      ),
    );
    test(
      'GET /api/articles/likes',
      () => _inspect(
        'GET',
        ApiConfig.articleLikes,
        shape: {'articles': F.list, 'page_info': F.object},
      ),
    );
    test(
      'GET /api/history',
      () => _inspect(
        'GET',
        ApiConfig.historyList,
        shape: {'records': F.list, 'page_info': F.object},
      ),
    );
    test(
      'GET /api/videos/1',
      () => _inspect(
        'GET',
        ApiConfig.videoDetail(1),
        fixtureAs: 'get_api_video_detail.json',
        shape: _videoDetailShape,
        optional: _videoSummaryOptional,
      ),
    );
    // video 5 是第一支上架的 YouTube 影片（後端 2026-09-25 前端待辦 A1）。
    test(
      'GET /api/videos/5 (YouTube 影片)',
      () => _inspect(
        'GET',
        ApiConfig.videoDetail(5),
        fixtureAs: 'get_api_video_detail_youtube.json',
        shape: _youtubeVideoDetailShape,
        nullable: const {'hls_url', 'duration_sec'},
        optional: _videoSummaryOptional,
      ),
    );
    test(
      'GET /api/videos/999999 (測 404 格式)',
      () => _inspect(
        'GET',
        ApiConfig.videoDetail(999999),
        expectStatus: 404,
        expectError: true,
      ),
    );

    test(
      'GET /api/events',
      () => _inspect(
        'GET',
        ApiConfig.events,
        shape: {'events': F.list, 'page_info': F.object},
        listKey: 'events',
        itemShape: _eventSummaryShape,
        itemOptional: _eventSummaryOptional,
      ),
    );
    test(
      'GET /api/events/mine',
      () => _inspect(
        'GET',
        ApiConfig.eventsMine,
        shape: {'events': F.list, 'page_info': F.object},
        listKey: 'events',
        itemShape: _eventSummaryShape,
        itemOptional: _eventSummaryOptional,
      ),
    );
    test(
      'GET /api/events/likes',
      () => _inspect(
        'GET',
        ApiConfig.eventLikes,
        shape: {'events': F.list, 'page_info': F.object},
        listKey: 'events',
        itemShape: _eventSummaryShape,
        itemOptional: _eventSummaryOptional,
      ),
    );
    test(
      'GET /api/events/bookmarks',
      () => _inspect(
        'GET',
        ApiConfig.eventBookmarks,
        shape: {'events': F.list, 'page_info': F.object},
        listKey: 'events',
        itemShape: _eventSummaryShape,
        itemOptional: _eventSummaryOptional,
      ),
    );
    test(
      'GET /api/events?scope=all (找已結束的活動)',
      () => _inspect(
        'GET',
        '${ApiConfig.events}?scope=all',
        shape: {'events': F.list},
        listKey: 'events',
        itemShape: _eventSummaryShape,
        itemOptional: _eventSummaryOptional,
      ),
    );
    test(
      'GET /api/events/:id (自動挑第一個 effective_status=ended 的活動測詳情)',
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
      },
    );

    // 我參加的活動（T-16）：確認 total、is_host、joined_at 的實際格式。
    for (final tab in ['active', 'ended']) {
      test(
        'GET /api/events/joined?tab=$tab',
        () => _inspect(
          'GET',
          '${ApiConfig.eventsJoined}?tab=$tab',
          shape: {'events': F.list, 'page_info': F.object},
          listKey: 'events',
          itemShape: _joinedEventShape,
          itemOptional: _eventSummaryOptional,
        ),
      );
    }

    // 影音/文章/活動/論壇搜尋（q/range/tribe_id 皆選填，見 backend/searchQuery.ts）
    test(
      'GET /api/videos/search',
      () => _inspect(
        'GET',
        '${ApiConfig.videoSearch}?q=a&range=1m',
        shape: {'videos': F.list, 'page_info': F.object},
        listKey: 'videos',
        itemShape: _videoSummaryShape,
        itemOptional: _videoSummaryOptional,
      ),
    );
    test(
      'GET /api/articles/search',
      () => _inspect(
        'GET',
        '${ApiConfig.articleSearch}?q=a&range=1m',
        shape: {'articles': F.list, 'page_info': F.object},
        listKey: 'articles',
        itemShape: _articleSummaryShape,
        itemOptional: _articleSummaryOptional,
      ),
    );
    // 活動圖片：在錄製帳號自己發起的活動上傳一張、看詳情與列表、再刪掉。
    test(
      'POST/DELETE /api/events/:id/images (上傳一張再刪掉)',
      () => _inspectEventImages(),
    );
    test(
      'GET /api/events/search',
      () => _inspect(
        'GET',
        '${ApiConfig.eventSearch}?q=a&range=1m',
        shape: {'events': F.list, 'page_info': F.object},
        listKey: 'events',
        itemShape: _eventSummaryShape,
        itemOptional: _eventSummaryOptional,
      ),
    );
    test(
      'GET /api/forum/search (range/tribe_id)',
      () => _inspect(
        'GET',
        '${ApiConfig.forumSearch}?q=a&range=1m',
        shape: {'posts': F.list, 'page_info': F.object},
      ),
    );

    // 2026-09 後端更新（見 Truku_backend 說明文件/前端交接/2026-09_更新與待接清單.md）。
    // 刪除帳號、匯出資料、寄驗證信屬於有副作用或受每分鐘 5 次限流的端點，不在此自動打。
    test(
      'GET /api/terms (確認 tos v5 / privacy v10 已發布)',
      () => _inspect(
        'GET',
        ApiConfig.terms,
        shape: {'documents': F.list},
        optional: {'all_consented': F.boolean},
        listKey: 'documents',
        itemShape: _termsDocShape,
        itemNullable: {'consented_version'},
        itemOptional: {'consented_version': F.number},
      ),
    );
    // 2026-10-01 前端待辦 A3（見 Truku_backend 說明文件/API/資料來源與授權.md）。
    // 不需登入、沒有個資，不用遮罩。
    test(
      'GET /api/data-sources',
      () => _inspect(
        'GET',
        ApiConfig.dataSources,
        shape: {'title': F.string, 'sources': F.list},
        listKey: 'sources',
        itemShape: _dataSourceShape,
        itemNullable: {'license'},
        itemOptional: {'license': F.string},
      ),
    );
    test(
      'GET /api/account/status',
      () => _inspect(
        'GET',
        ApiConfig.accountStatus,
        shape: {'status': F.string},
        optional: {'purge_at': F.string},
      ),
    );
    test(
      'GET /api/me/notification-settings',
      () => _inspect(
        'GET',
        ApiConfig.meNotificationSettings,
        shape: {'tribe_events': F.boolean},
      ),
    );
    // NotificationSummary 每個欄位都有 ?? 0，缺欄位不會壞，但全缺代表端點掛了，
    // 所以這裡把五個計數都列必要、允許為 null。
    test(
      'GET /api/notifications/summary',
      () => _inspect(
        'GET',
        ApiConfig.notificationsSummary,
        shape: {
          'forum': F.number,
          'events': F.number,
          'messages': F.number,
          'friend_requests': F.number,
          'total': F.number,
          'inbox': F.object,
        },
        nullable: {'forum', 'events', 'messages', 'friend_requests', 'total'},
      ),
    );
    // 收件匣（收件匣與申訴.md §1）。POST /api/inbox/read 會真的改已讀狀態，不錄。
    test(
      'GET /api/inbox',
      () => _inspect(
        'GET',
        ApiConfig.inbox,
        shape: {'items': F.list, 'unread': F.object, 'page_info': F.object},
        listKey: 'items',
        itemShape: {
          'id': F.number,
          'category': F.string,
          'kind': F.string,
          'is_read': F.boolean,
          'created_at': F.string,
        },
      ),
    );
    test(
      'GET /api/search/history?module=forum',
      () => _inspect(
        'GET',
        '${ApiConfig.searchHistory}?module=forum',
        shape: {'history': F.list},
        listKey: 'history',
        itemShape: {'q': F.string},
      ),
    );
    // popular 的每一筆可能是 {q: ...} 也可能是純字串（SearchAssistService 兩者都收），
    // 因此只驗外層是清單。
    test(
      'GET /api/search/popular?module=forum',
      () => _inspect(
        'GET',
        '${ApiConfig.searchPopular}?module=forum',
        shape: {'popular': F.list},
      ),
    );
  });

  // 管理員後台（唯讀 GET）。要用 role == 'admin' 的帳號錄，否則整組略過。
  // 只錄讀取：PATCH／POST 會真的改角色、發文章、發條款，回應依規格手寫。
  group('API Inspector — 管理員後台（需 admin 帳號）', () {
    void adminTest(
      String name,
      Future<void> Function(Map<String, dynamic> me) body,
    ) {
      test(name, () async {
        if (_token == null) {
          markTestSkipped('未登入 — 請先開 app 完成 Google 登入');
          return;
        }
        final me = await _fetchMe();
        if (me?['role'] != 'admin') {
          markTestSkipped('這個帳號不是 admin，略過後台端點');
          return;
        }
        await body(me!);
      });
    }

    adminTest(
      'GET /api/admin/forum/reports',
      (_) => _inspect(
        'GET',
        ApiConfig.adminForumReports,
        shape: {'reports': F.list},
      ),
    );
    adminTest(
      'GET /api/admin/moderation/cases',
      (_) => _inspect(
        'GET',
        ApiConfig.adminModerationCases,
        shape: {'cases': F.list},
      ),
    );
    adminTest(
      'GET /api/admin/users/roles',
      (_) =>
          _inspect('GET', ApiConfig.adminUsersRoles, shape: {'users': F.list}),
    );
    adminTest(
      'GET /api/admin/mutes',
      (_) => _inspect('GET', ApiConfig.adminMutes, shape: {'mutes': F.list}),
    );
    adminTest(
      'GET /api/admin/banned-words',
      (_) =>
          _inspect('GET', ApiConfig.adminBannedWords, shape: {'words': F.list}),
    );
    adminTest(
      'GET /api/admin/question-reports',
      (_) => _inspect(
        'GET',
        ApiConfig.adminQuestionReports,
        shape: {'reports': F.list},
      ),
    );
    adminTest(
      'GET /api/admin/millet/transactions (查自己)',
      (me) => _inspect(
        'GET',
        '${ApiConfig.adminMilletTransactions}?uid=${me['uid']}',
        shape: {'transactions': F.list, 'page_info': F.object},
        fixtureAs: 'get_api_admin_millet_transactions.json',
      ),
    );
    adminTest(
      'GET /api/admin/millet/reconcile (查自己)',
      (me) => _inspect(
        'GET',
        '${ApiConfig.adminMilletReconcile}?uid=${me['uid']}',
        shape: {
          'ledger_sum': F.number,
          'user_millet': F.number,
          'ok': F.boolean,
        },
        fixtureAs: 'get_api_admin_millet_reconcile.json',
      ),
    );
    // 每次查詢後端都會記一筆操作紀錄，只查錄製帳號自己一次。
    adminTest(
      'GET /api/admin/users/lookup (查自己)',
      (me) => _inspect(
        'GET',
        '${ApiConfig.adminUsersLookup}?friend_code=${me['friend_code']}',
        shape: {'user': F.object},
        fixtureAs: 'get_api_admin_users_lookup.json',
      ),
    );
    adminTest(
      'GET /api/admin/appeals',
      (_) =>
          _inspect('GET', ApiConfig.adminAppeals, shape: {'appeals': F.list}),
    );
    // 只錄列表；POST 會真的發給所有使用者。
    adminTest(
      'GET /api/admin/announcements',
      (_) => _inspect(
        'GET',
        ApiConfig.adminAnnouncements,
        shape: {'announcements': F.list},
      ),
    );
  });
}

Future<Map<String, dynamic>?> _fetchMe() async {
  final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.me}');
  final response = await http.get(
    uri,
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_token',
    },
  );
  if (response.statusCode != 200) return null;
  return jsonDecode(response.body) as Map<String, dynamic>;
}

/// 打 /api/events?scope=all 找第一筆 effective_status == 'ended' 的活動 id。
Future<int?> _findEndedEventId() async {
  final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.events}?scope=all');
  final response = await http.get(
    uri,
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_token',
    },
  );
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

/// 打 /api/forum/posts 找留言數最多的貼文 id，讓留言 fixture 盡量有內容。
Future<int?> _findMostCommentedPostId() async {
  final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.forumPosts}?limit=50');
  final response = await http.get(
    uri,
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_token',
    },
  );
  if (response.statusCode != 200) return null;
  final decoded = jsonDecode(response.body) as Map<String, dynamic>;
  final posts =
      (decoded['posts'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .where((p) => ((p['comment_count'] ?? 0) as num) > 0)
          .toList()
        ..sort(
          (a, b) => ((b['comment_count'] as num)).compareTo(
            a['comment_count'] as num,
          ),
        );
  if (posts.isEmpty) return null;
  final id = posts.first['id'];
  return id is int ? id : int.tryParse('$id');
}

/// 打 /api/friends 取第一位好友的好友碼，給私訊歷史用。
Future<String?> _firstFriendCode() async {
  final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.friends}');
  final response = await http.get(
    uri,
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_token',
    },
  );
  if (response.statusCode != 200) return null;
  final decoded = jsonDecode(response.body) as Map<String, dynamic>;
  final friends = decoded['friends'] as List<dynamic>? ?? const [];
  if (friends.isEmpty) return null;
  return (friends.first as Map<String, dynamic>)['friend_code'] as String?;
}

/// 取 /api/levels 的第一個等級代號，給 quiz／listening 的 start 當合法 level 用。
/// 等級是中文（初級／中級／中高級／高級），寫死英文代號會被擋成 400。
Future<String?> _firstLevel() async {
  final levels = await _levelCodes();
  return levels.isEmpty ? null : levels.first;
}

/// /api/levels 回傳的所有等級代號，依後端順序。
Future<List<String>> _levelCodes() async {
  if (_token == null) return const [];
  final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.levels}');
  final response = await http.get(
    uri,
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_token',
    },
  );
  if (response.statusCode != 200) return const [];
  final decoded = jsonDecode(response.body) as Map<String, dynamic>;
  final levels = decoded['levels'] as List<dynamic>? ?? const [];
  return [
    for (final l in levels.whereType<Map<String, dynamic>>())
      if ((l['code'] ?? l['label'] ?? l['level']) case final String code) code,
  ];
}

/// POST 並回傳 data（有 {data: ...} 信封就拆掉）；非 200 回 null。
Future<Map<String, dynamic>?> _postData(
  String path,
  Map<String, dynamic> body,
) async {
  final response = await http.post(
    Uri.parse('${ApiConfig.baseUrl}$path'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_token',
    },
    body: jsonEncode(body),
  );
  print('--- POST $path ${jsonEncode(body)} → ${response.statusCode}');
  if (response.statusCode != 200) return null;
  final decoded = jsonDecode(response.body) as Map<String, dynamic>;
  return (decoded['data'] as Map<String, dynamic>?) ?? decoded;
}

/// 單字／聽力共用的放棄流程：取得衝突時的舊 session_id → abandon（200）
/// → 重複 abandon（404 SESSION_NOT_FOUND）→ 再 start 想要的等級拿到新測驗。
Future<void> _inspectAbandonFlow({
  required String startPath,
  required String abandonPath,
  required Map<String, dynamic> Function(String level) startBody,
}) async {
  final levels = await _levelCodes();
  if (levels.length < 2) {
    markTestSkipped('/api/levels 少於兩個等級，無法製造衝突');
    return;
  }
  // 帳號原本就有進行中的測驗時，第一次 start 就會衝突；沒有的話換等級再 start 一次。
  var wanted = levels[0];
  var conflict = await _postData(startPath, startBody(wanted));
  if (conflict?['conflicting_level'] == null) {
    wanted = levels[1];
    conflict = await _postData(startPath, startBody(wanted));
  }
  expect(
    conflict?['conflicting_level'],
    wanted,
    reason: '換等級 start 應回 conflicting_level',
  );
  final oldSessionId = conflict!['session_id'] as String;
  print('舊測驗 ${conflict['level']}（$oldSessionId），想開 $wanted');

  await _inspect(
    'POST',
    abandonPath,
    body: {'session_id': oldSessionId},
    shape: const {'ok': F.boolean, 'abandoned_level': F.string},
  );
  await _inspect(
    'POST',
    abandonPath,
    body: {'session_id': oldSessionId},
    expectStatus: 404,
    expectError: true,
    errorCode: 'SESSION_NOT_FOUND',
  );

  final fresh = await _postData(startPath, startBody(wanted));
  expect(fresh?['level'], wanted, reason: '放棄後重新 start 應開出想要的等級');
  expect(fresh?['conflicting_level'], isNull);
  expect(fresh?['session_id'], isNot(oldSessionId));
}

Future<String?> _fetchDisplayName() async {
  final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.me}');
  final response = await http.get(
    uri,
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_token',
    },
  );
  if (response.statusCode != 200) return null;
  final decoded = jsonDecode(response.body) as Map<String, dynamic>;
  return decoded['display_name'] as String?;
}

Future<Map<String, dynamic>?> _fetchIdentityFields() async {
  final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.me}');
  final response = await http.get(
    uri,
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_token',
    },
  );
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
    ..files.add(
      http.MultipartFile.fromBytes(
        'avatar',
        pngBytes,
        filename: 'inspector_test.png',
      ),
    );

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

/// 活動圖片上傳／刪除：挑錄製帳號自己發起的第一場活動，上傳一張 1x1 PNG，
/// 看詳情的 images／cover_image_url 與「我發起的」列表的 cover_image_url，
/// 再把剛上傳的那張刪掉，最後重刪一次確認 404 IMAGE_NOT_FOUND 的格式。
/// 不動活動原有的圖片。
Future<void> _inspectEventImages() async {
  if (_token == null) {
    markTestSkipped('未登入 — 請先開 app 完成 Google 登入');
    return;
  }
  final mine = await http.get(
    Uri.parse('${ApiConfig.baseUrl}${ApiConfig.eventsMine}'),
    headers: {'Authorization': 'Bearer $_token'},
  );
  final events =
      (jsonDecode(mine.body) as Map<String, dynamic>)['events']
          as List<dynamic>? ??
      const [];
  if (events.isEmpty) {
    markTestSkipped('錄製帳號沒有自己發起的活動可測');
    return;
  }
  // 列表的 id 實際是字串（例如 "44"）。
  final eventId = int.parse('${(events.first as Map<String, dynamic>)['id']}');
  print('（挑到自己發起的活動 id=$eventId）');
  final before = await http.get(
    Uri.parse('${ApiConfig.baseUrl}${ApiConfig.eventDetail(eventId)}'),
    headers: {'Authorization': 'Bearer $_token'},
  );
  final beforeIds = {
    for (final image
        in (jsonDecode(before.body) as Map<String, dynamic>)['images']
                as List<dynamic>? ??
            const [])
      '${(image as Map<String, dynamic>)['id']}',
  };
  if (beforeIds.length >= 6) {
    markTestSkipped('活動 $eventId 已有 6 張圖片，無法再上傳測試圖');
    return;
  }

  // 1x1 透明 PNG bytes（伺服器會重新輸出成 JPEG）
  final pngBytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  );
  // 中途任何斷言失敗都要把這次上傳的測試圖刪掉，不在正式後端留下：
  // 重取詳情，刪掉上傳前沒有的圖片。
  addTearDown(() async {
    final after = await http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.eventDetail(eventId)}'),
      headers: {'Authorization': 'Bearer $_token'},
    );
    final images =
        (jsonDecode(after.body) as Map<String, dynamic>)['images']
            as List<dynamic>? ??
        const [];
    for (final image in images) {
      final id = '${(image as Map<String, dynamic>)['id']}';
      if (beforeIds.contains(id)) continue;
      await http.delete(
        Uri.parse(
          '${ApiConfig.baseUrl}${ApiConfig.eventImage(eventId, int.parse(id))}',
        ),
        headers: {'Authorization': 'Bearer $_token'},
      );
    }
  });
  final uploadPath = ApiConfig.eventImages(eventId);
  final request =
      http.MultipartRequest(
          'POST',
          Uri.parse('${ApiConfig.baseUrl}$uploadPath'),
        )
        ..headers['Authorization'] = 'Bearer $_token'
        ..files.add(
          http.MultipartFile.fromBytes(
            'images',
            pngBytes,
            filename: 'inspector_test.png',
            contentType: MediaType('image', 'png'),
          ),
        );
  final uploaded = await http.Response.fromStream(await request.send());
  _printResponse('POST', uploadPath, uploaded);
  recordFixture('POST', uploadPath, uploaded, as: 'post_api_event_images.json');
  expect(uploaded.statusCode, 201, reason: uploaded.body);
  final uploadedJson = jsonDecode(uploaded.body);
  expectShape(uploadedJson, {'images': F.list}, label: 'POST images');
  final images = (uploadedJson as Map<String, dynamic>)['images'] as List;
  final newImageId = int.parse(
    '${images.map((i) => (i as Map<String, dynamic>)['id']).firstWhere((id) => !beforeIds.contains('$id'))}',
  );
  final deletePath = ApiConfig.eventImage(eventId, newImageId);
  expectEachShape(images, _eventImageShape, label: 'POST images.images');

  await _inspect(
    'GET',
    ApiConfig.eventDetail(eventId),
    fixtureAs: 'get_api_event_detail_with_images.json',
    shape: {
      ..._eventDetailShape,
      'images': F.list,
      'cover_image_url': F.string,
    },
    optional: _eventDetailOptional,
  );
  await _inspect(
    'GET',
    ApiConfig.eventsMine,
    fixtureAs: 'get_api_events_mine_with_cover.json',
    shape: {'events': F.list, 'page_info': F.object},
    listKey: 'events',
    itemShape: _eventSummaryShape,
    itemOptional: _eventSummaryOptional,
  );

  final deleted = await http.delete(
    Uri.parse('${ApiConfig.baseUrl}$deletePath'),
    headers: {'Authorization': 'Bearer $_token'},
  );
  _printResponse('DELETE', deletePath, deleted);
  recordFixture(
    'DELETE',
    deletePath,
    deleted,
    as: 'delete_api_event_image.json',
  );
  expect(deleted.statusCode, 200, reason: deleted.body);
  final deletedJson = jsonDecode(deleted.body);
  expectShape(deletedJson, {
    'ok': F.boolean,
    'images': F.list,
  }, label: 'DELETE image');
  expectEachShape(
    (deletedJson as Map<String, dynamic>)['images'],
    _eventImageShape,
    label: 'DELETE image.images',
  );

  final again = await http.delete(
    Uri.parse('${ApiConfig.baseUrl}$deletePath'),
    headers: {'Authorization': 'Bearer $_token'},
  );
  _printResponse('DELETE', '$deletePath (再刪一次)', again);
  expect(again.statusCode, 404, reason: again.body);
  expectErrorShape(again, code: 'IMAGE_NOT_FOUND');
}

void _printResponse(String method, String path, http.Response response) {
  String prettyBody;
  try {
    prettyBody = const JsonEncoder.withIndent(
      '  ',
    ).convert(jsonDecode(response.body));
  } catch (_) {
    prettyBody = response.body;
  }
  print('--- $method $path ---');
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

  expect(
    response.statusCode,
    expectStatus,
    reason: '$method $path 狀態碼不符\n${response.body}',
  );

  if (expectError) {
    expectErrorShape(response, code: errorCode);
    return;
  }

  var decoded = jsonDecode(response.body);
  // 部分端點包了 {data: {...}} 信封（service 端用 ApiClient.unwrapData 拆）。
  if (unwrap && decoded is Map<String, dynamic> && decoded['data'] != null) {
    decoded = decoded['data'];
  }
  expectShape(
    decoded,
    shape!,
    nullable: nullable,
    optional: optional,
    label: '$method $path',
  );

  if (listKey != null && itemShape != null) {
    expectEachShape(
      (decoded as Map<String, dynamic>)[listKey],
      itemShape,
      nullable: itemNullable,
      optional: itemOptional,
      label: '$method $path.$listKey',
    );
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
const Map<String, F> _meShape = {'uid': F.number, 'created_at': F.string};
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
  'birth_date': F.string,
  'needs_birth_date': F.boolean,
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

/// GET /api/videos/:id（source=youtube）：hls_url／duration_sec 為 null，多 youtube 物件。
const Map<String, F> _youtubeVideoDetailShape = {
  'id': F.number,
  'title': F.string,
  'category': F.string,
  'source': F.string,
  'hls_url': F.any,
  'duration_sec': F.any,
  'youtube': F.object,
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
  'is_host': F.boolean,
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
  // 第一張活動圖片的限時網址，沒有圖片為 null。
  'cover_image_url': F.string,
};

/// 活動圖片 → lib/models/event_model.dart EventImage.fromJson
const Map<String, F> _eventImageShape = {'id': F.number, 'url': F.string};

/// GET /api/terms → lib/models/terms_models.dart TermsDocument.fromJson
const Map<String, F> _termsDocShape = {
  'doc_type': F.string,
  'version': F.number,
  'title': F.string,
  'content_md': F.string,
  'published_at': F.string,
  'consented': F.boolean,
};

/// GET /api/data-sources → lib/models/data_source_models.dart DataSource.fromJson
const Map<String, F> _dataSourceShape = {
  'id': F.string,
  'name': F.string,
  'used_for': F.list,
  'attribution': F.string,
  'links': F.list,
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
const Map<String, F> _eventDetailShape = {
  'id': F.any,
  'title': F.string,
  'starts_at': F.string,
};

/// GET /api/events/joined 的每一筆 → EventSummary.fromJson 的 isHost、joinedAt。
const Map<String, F> _joinedEventShape = {
  ..._eventSummaryShape,
  'is_host': F.boolean,
  'joined_at': F.string,
};

const Map<String, F> _eventDetailOptional = {
  ..._eventSummaryOptional,
  // 未報名時為 null；有值時是 {joined_at, contact_email}（EventRegistration）。
  'my_registration': F.object,
  // 只有已取消的活動才有值。
  'cancel_reason': F.string,
  'description': F.string,
  'address': F.string,
  'contact_email': F.string,
  'contact_phone': F.string,
  'reminder_note': F.string,
  'created_at': F.string,
  'participants': F.list,
  // 沒有圖片為空陣列；每筆 {id, url}。
  'images': F.list,
};
