# 論壇前端 v2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 App 的論壇模組從寫死的假資料，換成串接 `Truku_backend` `feature/forum-v2` 全部使用者端功能的完整畫面，視覺沿用 `feature/forum-dcard` 分支的語彙。

**Architecture:** 資料層（model / service）全部重寫以對齊 v2 payload；畫面拆進 `lib/screens/forum/`，由既有的「廣場」分頁掛載。列表元件以 callback 注入資料來源，讓樂觀更新與分頁能在沒有網路的情況下被測試。共用的 `ApiClient` 先做可測試化與 multipart 擴充，後續所有 service 都建立在它之上。

**Tech Stack:** Flutter、`http`、`google_fonts`、`image_picker`、`flutter_image_compress`、`cached_network_image`、`http_parser`、`flutter_test`

**規格書：** `docs/superpowers/specs/2026-08-14-forum-frontend-v2-design.md`（下稱「規格」）。後端規格在 `Truku_backend` repo 的 `docs/superpowers/specs/2026-08-14-forum-v2-design.md`。

## Global Constraints

- Dart package 名稱為 `flutter_application_1`，測試中一律以 `package:flutter_application_1/...` 匯入。
- 所有 API 呼叫走 `ApiClient`，不得自行使用 `http` 頂層函式；401 由 `ApiClient` 統一處理，畫面不重複攔截。
- 所有 id 與計數欄位以 `int.tryParse(x?.toString()) ?? 0` 解析（pg driver 可能把 `BIGINT` 以字串回傳）。
- 缺欄位一律有安全預設：`images` / `tags` 缺少視為空陣列，`isBookmarked` 缺少視為 `false`。
- 後端硬性限制，前端須同步驗證：標題 ≤120 字、內文 ≤5000 字、留言 ≤2000 字、檢舉理由 ≤1000 字、標籤最多 5 個且每個 ≤20 字、附圖最多 4 張且每張 ≤5 MB（MIME 僅 `image/jpeg`、`image/png`、`image/webp`）、搜尋關鍵字 2–80 字、分頁 `limit` 上限 50。
- 顏色一律取自 `AppColors`（`lib/core/constants/app_colors.dart`），字體一律用 `GoogleFonts.notoSerifTc`（中文標題）與 `GoogleFonts.crimsonPro`（英文小標，斜體 + `letterSpacing: 3.0`），不得寫死色碼。
- 使用者是否為作者以 `UserService.currentUid` 與 `author.uid` 比對判斷；此判斷只影響 UI，權限由後端把關。
- 每個 task 結束時 `flutter analyze` 必須零 error。
- 全部 commit 訊息用中文，格式 `<type>: <說明>`。

---

## File Structure

| 檔案 | 責任 |
|---|---|
| `lib/core/network/api_client.dart` | 修改：可注入 http client、修 `delete()` 離線處理、新增 `postMultipart()` |
| `lib/core/constants/api.dart` | 修改：新增 forum 端點常數 |
| `lib/models/forum_models.dart` | 建立：全部 forum model 與 `groupComments()` |
| `lib/services/forum_service.dart` | 建立：forum 全部 API 呼叫 |
| `lib/screens/forum/widgets/forum_post_card.dart` | 建立：貼文列表卡片 |
| `lib/screens/forum/widgets/forum_image_grid.dart` | 建立：附圖網格 + 全螢幕檢視 |
| `lib/screens/forum/widgets/forum_comment_tile.dart` | 建立：留言 / 回覆列 |
| `lib/screens/forum/widgets/forum_report_sheet.dart` | 建立：檢舉 bottom sheet |
| `lib/screens/forum/forum_board_view.dart` | 建立：看板貼文列表（下拉刷新、分頁、樂觀更新） |
| `lib/screens/forum/forum_detail_screen.dart` | 建立：貼文詳情 + 兩層留言 |
| `lib/screens/forum/forum_compose_screen.dart` | 建立：發文 / 編輯 |
| `lib/screens/forum/forum_search_screen.dart` | 建立：關鍵字搜尋 |
| `lib/screens/forum/forum_notifications_screen.dart` | 建立：通知中心 |
| `lib/screens/forum/forum_bookmarks_screen.dart` | 建立：我的收藏 |
| `lib/screens/plaza/plaza_screen.dart` | 修改：看板 tab、貼文區換成 `ForumBoardView`、標題列三個入口 |
| `lib/screens/plaza/compose_screen.dart` | 刪除：假資料發文畫面，由 `ForumComposeScreen` 取代 |
| `lib/services/fcm_service.dart` | 修改：新增 `reply_post` / `reply_comment` 導頁 |
| `test/core/api_client_test.dart` | 建立：可注入 client、離線處理、multipart 組成 |
| `test/models/forum_models_test.dart` | 建立：model 解析與 `groupComments` |
| `test/services/forum_service_test.dart` | 建立：端點、query、multipart 欄位 |
| `test/widgets/forum_post_card_test.dart` | 建立：卡片渲染 |
| `test/widgets/forum_board_view_test.dart` | 建立：空狀態、載入更多、樂觀更新回滾 |
| `test/widgets/forum_report_sheet_test.dart` | 建立：檢舉送出與必填 |
| `test/widgets/forum_comment_tile_test.dart` | 建立：縮排、自己／別人的動作 |
| `test/widgets/forum_compose_validation_test.dart` | 建立：發文欄位驗證 |
| `test/widgets/forum_search_screen_test.dart` | 建立：關鍵字長度與結果顯示 |
| `test/widgets/forum_notifications_screen_test.dart` | 建立：通知列表與全部已讀 |
| `test/widgets/forum_bookmarks_screen_test.dart` | 建立：收藏列表與端點缺席時的錯誤 |

---

### Task 1: ApiClient 可測試化、修 delete()、新增 multipart

`ApiClient` 目前直接呼叫 `http.get` 等頂層函式，測試無法替換傳輸層，後續所有 service 測試都被卡住。同時 `delete()` 沒有包 `_send()`，離線時會漏出原始 `SocketException`，而論壇的取消讚與刪文都走 DELETE。發文需要一次送出文字欄位與最多 4 張圖，需要 multipart。三件事都動同一個檔案，合為一個 task。

**Files:**
- Modify: `lib/core/network/api_client.dart`
- Test: `test/core/api_client_test.dart`（建立）

**Interfaces:**
- Consumes: 無
- Produces:
  - `ApiClient.httpClient`（`static http.Client`，測試可覆寫，預設 `http.Client()`）
  - `class MultipartFileData({required String field, required List<int> bytes, required String filename, required String mimeType})`
  - `ApiClient.postMultipart(String path, {required Map<String, String> fields, required List<MultipartFileData> files}) → Future<Map<String, dynamic>>`
  - `ApiClient.delete()` 行為不變，但離線時丟 `ApiException(code: 'NETWORK_ERROR')`

- [ ] **Step 1: 加入 `http_parser` 依賴**

`multer` 的 `fileFilter` 以 part 的 `Content-Type` 判斷 MIME，未指定時 `http` 會送 `application/octet-stream`，後端會直接拒收。指定 `contentType` 需要 `MediaType`，由 `http_parser` 提供。

編輯 `pubspec.yaml`，在 `http: ^1.2.2` 下一行加入：

```yaml
  http_parser: ^4.1.2 # multipart 的 Content-Type（後端 multer 以 MIME 過濾附圖）
```

執行：`flutter pub get`
預期：`Got dependencies!`

- [ ] **Step 2: 寫失敗的測試**

建立 `test/core/api_client_test.dart`：

```dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_1/core/network/api_client.dart';

void main() {
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
```

檔案頂端還需要 `import 'dart:io';`（`SocketException`）。

- [ ] **Step 3: 執行測試，確認失敗**

Run: `flutter test test/core/api_client_test.dart`
Expected: FAIL，錯誤為 `The getter 'httpClient' isn't defined for the class 'ApiClient'` 等編譯錯誤。

- [ ] **Step 4: 讓 ApiClient 使用可注入的 client**

在 `lib/core/network/api_client.dart` 的 `class ApiClient {` 之後，`get()` 之前插入：

```dart
  /// 傳輸層。正式執行時是預設的 http client；測試可換成 MockClient。
  /// 換成可注入的原因：service 的端點、query、multipart 組成需要在沒有網路的
  /// 情況下驗證，直接呼叫 http 頂層函式無法做到。
  static http.Client httpClient = http.Client();
```

把 `get` / `post` / `patch` / `delete` 內的 `http.get(` → `httpClient.get(`，`http.post(` → `httpClient.post(`，`http.patch(` → `httpClient.patch(`，`http.delete(` → `httpClient.delete(`。

- [ ] **Step 5: 修 `delete()` 的離線處理**

把 `delete()` 的主體改為與其他方法一致地包進 `_send()`：

```dart
  static Future<Map<String, dynamic>> delete(
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final token = await AuthService.currentToken();
    final resp = await _send(() => httpClient.delete(
          Uri.parse(ApiConfig.baseUrl + path),
          headers: _headers(token),
          body: body == null ? null : jsonEncode(body),
        ));
    return _handle(resp);
  }
```

- [ ] **Step 6: 新增 multipart 支援**

在 `lib/core/network/api_client.dart` 頂端加入匯入：

```dart
import 'package:http_parser/http_parser.dart';
```

在 `class ApiException` 之前加入：

```dart
/// multipart 的單一檔案。bytes 由呼叫端準備好（論壇附圖在 App 端壓縮後上傳，
/// 後端不做伺服器端壓縮），mimeType 必填——後端 multer 以它過濾檔案類型。
class MultipartFileData {
  final String field;
  final List<int> bytes;
  final String filename;
  final String mimeType;

  const MultipartFileData({
    required this.field,
    required this.bytes,
    required this.filename,
    required this.mimeType,
  });
}
```

在 `ApiClient` 的 `patch()` 之後加入：

```dart
  /// multipart 送出。文字欄位與檔案一併送，供發文（文字 + 最多 4 張附圖）使用。
  static Future<Map<String, dynamic>> postMultipart(
    String path, {
    required Map<String, String> fields,
    required List<MultipartFileData> files,
  }) async {
    final token = await AuthService.currentToken();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse(ApiConfig.baseUrl + path),
    );
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.fields.addAll(fields);
    for (final file in files) {
      request.files.add(http.MultipartFile.fromBytes(
        file.field,
        file.bytes,
        filename: file.filename,
        contentType: MediaType.parse(file.mimeType),
      ));
    }
    final resp = await _send(
      () async => http.Response.fromStream(await httpClient.send(request)),
    );
    return _handle(resp);
  }
```

注意 `_headers()` 不能用在這裡——它會把 `Content-Type` 寫成 `application/json`，蓋掉 multipart 自己的 boundary。

- [ ] **Step 7: 執行測試，確認通過**

Run: `flutter test test/core/api_client_test.dart`
Expected: PASS，3 個測試全過。

- [ ] **Step 8: 確認沒有破壞既有呼叫端**

Run: `flutter analyze`
Expected: `No issues found!`（或至少沒有新增的 error）

Run: `flutter test`
Expected: 既有測試全部通過。

- [ ] **Step 9: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/core/network/api_client.dart test/core/api_client_test.dart
git commit -m "refactor: ApiClient 支援注入 http client 與 multipart，並修正 delete 的離線處理"
```

---

### Task 2: 端點常數與資料模型

**Files:**
- Modify: `lib/core/constants/api.dart`
- Create: `lib/models/forum_models.dart`
- Test: `test/models/forum_models_test.dart`

**Interfaces:**
- Consumes: 無
- Produces（後續全部 task 依賴這些型別與名稱）：
  - `ForumBoard(id, slug, name, description)`
  - `ForumAuthor(uid, displayName, avatarUrl)`
  - `ForumTag(name, slug)`、`ForumTagStat(tag, postCount)`
  - `ForumPost(id, board, title, body, likeCount, commentCount, isPinned, isLiked, isBookmarked, images, tags, createdAt, updatedAt, author)`，含 `copyWith()`、`toggledLike()`、`toggledBookmark()`
  - `ForumComment(id, postId, parentCommentId, body, likeCount, isLiked, createdAt, author)`，含 `copyWith()`、`toggledLike()`
  - `ForumPostPage(pinned, posts, nextCursor)`
  - `ForumCommentPage(comments, replies, nextCursor)`
  - `ForumNotification(id, type, postId, commentId, postTitle, isRead, createdAt, actor)`
  - `ForumNotificationPage(items, unreadCount, nextCursor)`
  - `ForumCommentThread(root, replies)` 與 `groupComments(comments, replies)`
  - `ApiConfig` 的 forum 端點常數（見 Step 2）

- [ ] **Step 1: 寫失敗的測試**

建立 `test/models/forum_models_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/forum_models.dart';

Map<String, dynamic> _postJson() => {
      // pg driver 會把 BIGINT 以字串回傳，這裡刻意用字串。
      'id': '1024',
      'board': {'id': 2, 'slug': 'culture', 'name': '文化傳承'},
      'title': '關於 mhuway',
      'body': '內文',
      'like_count': 3,
      'comment_count': 5,
      'is_pinned': false,
      'is_liked': true,
      'images': ['https://storage.googleapis.com/truku-media/forum/a.jpg'],
      'tags': [
        {'name': '族語', 'slug': 'yuyan'},
      ],
      'created_at': '2026-08-01T10:00:00.000Z',
      'updated_at': '2026-08-01T10:00:00.000Z',
      'author': {'uid': 7, 'display_name': 'Sayun', 'avatar_url': null},
    };

void main() {
  group('ForumPost.fromJson', () {
    test('解析完整欄位，id 為字串也能解析', () {
      final post = ForumPost.fromJson(_postJson());

      expect(post.id, 1024);
      expect(post.board.slug, 'culture');
      expect(post.board.name, '文化傳承');
      expect(post.title, '關於 mhuway');
      expect(post.likeCount, 3);
      expect(post.commentCount, 5);
      expect(post.isLiked, isTrue);
      expect(post.isPinned, isFalse);
      expect(post.images, hasLength(1));
      expect(post.tags.single.name, '族語');
      expect(post.author.displayName, 'Sayun');
    });

    test('images / tags 缺失視為空陣列，is_bookmarked 缺失視為 false', () {
      final json = _postJson()
        ..remove('images')
        ..remove('tags');

      final post = ForumPost.fromJson(json);

      expect(post.images, isEmpty);
      expect(post.tags, isEmpty);
      // 後端補上書籤端點前不會有這個欄位（規格 §9）。
      expect(post.isBookmarked, isFalse);
    });

    test('作者顯示名為 null 時退回匿名使用者', () {
      final json = _postJson()
        ..['author'] = {'uid': 9, 'display_name': null, 'avatar_url': null};

      expect(ForumPost.fromJson(json).author.displayName, '匿名使用者');
    });
  });

  group('ForumPost 樂觀更新', () {
    test('toggledLike 由未按讚變成已按讚並 +1', () {
      final post = ForumPost.fromJson(_postJson()..['is_liked'] = false);

      final toggled = post.toggledLike();

      expect(toggled.isLiked, isTrue);
      expect(toggled.likeCount, 4);
    });

    test('toggledLike 由已按讚變回未按讚並 -1，不會低於 0', () {
      final post = ForumPost.fromJson(
        _postJson()
          ..['is_liked'] = true
          ..['like_count'] = 0,
      );

      final toggled = post.toggledLike();

      expect(toggled.isLiked, isFalse);
      expect(toggled.likeCount, 0);
    });

    test('toggledBookmark 只改書籤狀態', () {
      final post = ForumPost.fromJson(_postJson());

      final toggled = post.toggledBookmark();

      expect(toggled.isBookmarked, isTrue);
      expect(toggled.likeCount, post.likeCount);
    });
  });

  group('ForumComment.fromJson', () {
    test('第一層留言的 parentCommentId 為 null', () {
      final comment = ForumComment.fromJson({
        'id': '5',
        'post_id': '1024',
        'parent_comment_id': null,
        'body': '推',
        'like_count': 0,
        'is_liked': false,
        'created_at': '2026-08-01T11:00:00.000Z',
        'author': {'uid': 8, 'display_name': 'Pisaw', 'avatar_url': null},
      });

      expect(comment.id, 5);
      expect(comment.postId, 1024);
      expect(comment.parentCommentId, isNull);
      expect(comment.body, '推');
    });
  });

  group('ForumPostPage.fromJson', () {
    test('置頂與一般貼文分開，next_cursor 為 null 時代表沒有下一頁', () {
      final page = ForumPostPage.fromJson({
        'pinned': [_postJson()..['is_pinned'] = true],
        'posts': [_postJson()],
        'next_cursor': null,
      });

      expect(page.pinned.single.isPinned, isTrue);
      expect(page.posts, hasLength(1));
      expect(page.nextCursor, isNull);
    });
  });

  group('ForumNotificationPage.fromJson', () {
    test('解析通知與未讀數', () {
      final page = ForumNotificationPage.fromJson({
        'notifications': [
          {
            'id': 3,
            'type': 'reply_post',
            'post_id': '1024',
            'comment_id': '5',
            'post_title': '關於 mhuway',
            'is_read': false,
            'created_at': '2026-08-01T11:00:00.000Z',
            'actor': {'uid': 8, 'display_name': 'Pisaw', 'avatar_url': null},
          },
        ],
        'unread_count': 1,
        'next_cursor': 3,
      });

      expect(page.items.single.type, 'reply_post');
      expect(page.items.single.postId, 1024);
      expect(page.items.single.isRead, isFalse);
      expect(page.unreadCount, 1);
      expect(page.nextCursor, 3);
    });
  });
}
```

- [ ] **Step 2: 執行測試，確認失敗**

Run: `flutter test test/models/forum_models_test.dart`
Expected: FAIL，`Target of URI doesn't exist: 'package:flutter_application_1/models/forum_models.dart'`。

- [ ] **Step 3: 新增端點常數**

在 `lib/core/constants/api.dart` 的 `checkinAction` 之後、closing brace 之前加入：

```dart

  // 論壇 v2（見 Truku_backend backend/routes/forum.ts）
  static const String forumBoards = '/api/forum/boards';
  static String forumBoardPosts(String slug) => '/api/forum/boards/$slug/posts';
  static const String forumPosts = '/api/forum/posts';
  static String forumPost(int id) => '/api/forum/posts/$id';
  static String forumPostComments(int id) => '/api/forum/posts/$id/comments';
  static String forumComment(int id) => '/api/forum/comments/$id';
  static String forumPostLike(int id) => '/api/forum/posts/$id/like';
  static String forumCommentLike(int id) => '/api/forum/comments/$id/like';
  static const String forumSearch = '/api/forum/search';
  static const String forumTags = '/api/forum/tags';
  static const String forumReports = '/api/forum/reports';
  static const String forumNotifications = '/api/forum/notifications';
  static const String forumNotificationsRead = '/api/forum/notifications/read';
  // 書籤端點由後端另行補上，前端依規格 §9 的約定先行實作。
  static String forumPostBookmark(int id) => '/api/forum/posts/$id/bookmark';
  static const String forumBookmarks = '/api/forum/bookmarks';
```

- [ ] **Step 4: 建立 model 檔**

建立 `lib/models/forum_models.dart`：

```dart
// 論壇 v2 資料模型。欄位依 Truku_backend feature/forum-v2 的 routes/forum.ts
// 實際回傳定義，與 feature/forum-dcard 的 v1 模型不相容（見規格 §2）。
//
// 解析原則：
//   - id 與計數一律經 _asInt：pg driver 會把 BIGINT 以字串回傳，v1 為此修過三個 commit。
//   - 缺欄位一律有安全預設，後端補欄位或前端搶先實作（如 is_bookmarked）都不會炸。

int _asInt(dynamic value) => int.tryParse(value?.toString() ?? '') ?? 0;

int? _asIntOrNull(dynamic value) =>
    value == null ? null : int.tryParse(value.toString());

DateTime _asDate(dynamic value) =>
    DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();

class ForumBoard {
  final int id;
  final String slug;
  final String name;
  final String? description;

  const ForumBoard({
    required this.id,
    required this.slug,
    required this.name,
    this.description,
  });

  factory ForumBoard.fromJson(Map<String, dynamic> j) => ForumBoard(
        id: _asInt(j['id']),
        slug: j['slug'] as String? ?? '',
        name: j['name'] as String? ?? '',
        description: j['description'] as String?,
      );
}

class ForumAuthor {
  final int uid;
  final String displayName;
  final String? avatarUrl;

  const ForumAuthor({
    required this.uid,
    required this.displayName,
    this.avatarUrl,
  });

  factory ForumAuthor.fromJson(Map<String, dynamic> j) => ForumAuthor(
        uid: _asInt(j['uid']),
        displayName: j['display_name'] as String? ?? '匿名使用者',
        avatarUrl: j['avatar_url'] as String?,
      );
}

class ForumTag {
  final String name;
  final String slug;

  const ForumTag({required this.name, required this.slug});

  factory ForumTag.fromJson(Map<String, dynamic> j) => ForumTag(
        name: j['name'] as String? ?? '',
        slug: j['slug'] as String? ?? '',
      );
}

/// `/forum/tags` 額外回傳貼文數，供「熱門標籤」排序。
class ForumTagStat {
  final ForumTag tag;
  final int postCount;

  const ForumTagStat({required this.tag, required this.postCount});

  factory ForumTagStat.fromJson(Map<String, dynamic> j) => ForumTagStat(
        tag: ForumTag.fromJson(j),
        postCount: _asInt(j['post_count']),
      );
}

class ForumPost {
  final int id;
  final ForumBoard board;
  final String title;
  final String body;
  final int likeCount;
  final int commentCount;
  final bool isPinned;
  final bool isLiked;
  final bool isBookmarked;
  final List<String> images;
  final List<ForumTag> tags;
  final DateTime createdAt;
  final DateTime updatedAt;
  final ForumAuthor author;

  const ForumPost({
    required this.id,
    required this.board,
    required this.title,
    required this.body,
    required this.likeCount,
    required this.commentCount,
    required this.isPinned,
    required this.isLiked,
    required this.isBookmarked,
    required this.images,
    required this.tags,
    required this.createdAt,
    required this.updatedAt,
    required this.author,
  });

  factory ForumPost.fromJson(Map<String, dynamic> j) => ForumPost(
        id: _asInt(j['id']),
        board: ForumBoard.fromJson(
          j['board'] as Map<String, dynamic>? ?? const {},
        ),
        title: j['title'] as String? ?? '',
        body: j['body'] as String? ?? '',
        likeCount: _asInt(j['like_count']),
        commentCount: _asInt(j['comment_count']),
        isPinned: j['is_pinned'] == true,
        isLiked: j['is_liked'] == true,
        // 後端補上書籤端點前不會有這個欄位（規格 §9）。
        isBookmarked: j['is_bookmarked'] == true,
        images: (j['images'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .toList(),
        tags: (j['tags'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(ForumTag.fromJson)
            .toList(),
        createdAt: _asDate(j['created_at']),
        updatedAt: _asDate(j['updated_at']),
        author: ForumAuthor.fromJson(
          j['author'] as Map<String, dynamic>? ?? const {},
        ),
      );

  ForumPost copyWith({
    int? likeCount,
    int? commentCount,
    bool? isPinned,
    bool? isLiked,
    bool? isBookmarked,
    String? title,
    String? body,
    List<ForumTag>? tags,
  }) =>
      ForumPost(
        id: id,
        board: board,
        title: title ?? this.title,
        body: body ?? this.body,
        likeCount: likeCount ?? this.likeCount,
        commentCount: commentCount ?? this.commentCount,
        isPinned: isPinned ?? this.isPinned,
        isLiked: isLiked ?? this.isLiked,
        isBookmarked: isBookmarked ?? this.isBookmarked,
        images: images,
        tags: tags ?? this.tags,
        createdAt: createdAt,
        updatedAt: updatedAt,
        author: author,
      );

  /// 樂觀更新用：先翻轉本地狀態，等後端回應再以真實計數校正。
  /// 計數以 0 為下限，避免併發或重送時出現負數。
  ForumPost toggledLike() => copyWith(
        isLiked: !isLiked,
        likeCount: isLiked ? (likeCount - 1).clamp(0, 1 << 31) : likeCount + 1,
      );

  /// 書籤是私人行為，不做公開計數（規格 §9），只翻轉狀態。
  ForumPost toggledBookmark() => copyWith(isBookmarked: !isBookmarked);
}

class ForumComment {
  final int id;
  final int postId;
  final int? parentCommentId;
  final String body;
  final int likeCount;
  final bool isLiked;
  final DateTime createdAt;
  final ForumAuthor author;

  const ForumComment({
    required this.id,
    required this.postId,
    required this.parentCommentId,
    required this.body,
    required this.likeCount,
    required this.isLiked,
    required this.createdAt,
    required this.author,
  });

  factory ForumComment.fromJson(Map<String, dynamic> j) => ForumComment(
        id: _asInt(j['id']),
        postId: _asInt(j['post_id']),
        parentCommentId: _asIntOrNull(j['parent_comment_id']),
        body: j['body'] as String? ?? '',
        likeCount: _asInt(j['like_count']),
        isLiked: j['is_liked'] == true,
        createdAt: _asDate(j['created_at']),
        author: ForumAuthor.fromJson(
          j['author'] as Map<String, dynamic>? ?? const {},
        ),
      );

  ForumComment copyWith({int? likeCount, bool? isLiked}) => ForumComment(
        id: id,
        postId: postId,
        parentCommentId: parentCommentId,
        body: body,
        likeCount: likeCount ?? this.likeCount,
        isLiked: isLiked ?? this.isLiked,
        createdAt: createdAt,
        author: author,
      );

  ForumComment toggledLike() => copyWith(
        isLiked: !isLiked,
        likeCount: isLiked ? (likeCount - 1).clamp(0, 1 << 31) : likeCount + 1,
      );
}

class ForumPostPage {
  final List<ForumPost> pinned;
  final List<ForumPost> posts;
  final int? nextCursor;

  const ForumPostPage({
    required this.pinned,
    required this.posts,
    required this.nextCursor,
  });

  factory ForumPostPage.fromJson(Map<String, dynamic> j) => ForumPostPage(
        pinned: (j['pinned'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(ForumPost.fromJson)
            .toList(),
        posts: (j['posts'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(ForumPost.fromJson)
            .toList(),
        nextCursor: _asIntOrNull(j['next_cursor']),
      );
}

class ForumCommentPage {
  final List<ForumComment> comments;
  final List<ForumComment> replies;
  final int? nextCursor;

  const ForumCommentPage({
    required this.comments,
    required this.replies,
    required this.nextCursor,
  });

  factory ForumCommentPage.fromJson(Map<String, dynamic> j) => ForumCommentPage(
        comments: (j['comments'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(ForumComment.fromJson)
            .toList(),
        replies: (j['replies'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(ForumComment.fromJson)
            .toList(),
        nextCursor: _asIntOrNull(j['next_cursor']),
      );
}

class ForumNotification {
  final int id;
  final String type;
  final int? postId;
  final int? commentId;
  final String? postTitle;
  final bool isRead;
  final DateTime createdAt;
  final ForumAuthor actor;

  const ForumNotification({
    required this.id,
    required this.type,
    required this.postId,
    required this.commentId,
    required this.postTitle,
    required this.isRead,
    required this.createdAt,
    required this.actor,
  });

  factory ForumNotification.fromJson(Map<String, dynamic> j) =>
      ForumNotification(
        id: _asInt(j['id']),
        type: j['type'] as String? ?? '',
        postId: _asIntOrNull(j['post_id']),
        commentId: _asIntOrNull(j['comment_id']),
        postTitle: j['post_title'] as String?,
        isRead: j['is_read'] == true,
        createdAt: _asDate(j['created_at']),
        actor: ForumAuthor.fromJson(
          j['actor'] as Map<String, dynamic>? ?? const {},
        ),
      );
}

class ForumNotificationPage {
  final List<ForumNotification> items;
  final int unreadCount;
  final int? nextCursor;

  const ForumNotificationPage({
    required this.items,
    required this.unreadCount,
    required this.nextCursor,
  });

  factory ForumNotificationPage.fromJson(Map<String, dynamic> j) =>
      ForumNotificationPage(
        items: (j['notifications'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(ForumNotification.fromJson)
            .toList(),
        unreadCount: _asInt(j['unread_count']),
        nextCursor: _asIntOrNull(j['next_cursor']),
      );
}
```

`groupComments` 與 `ForumCommentThread` 在 Task 3 加入同一個檔案。

- [ ] **Step 5: 執行測試，確認通過**

Run: `flutter test test/models/forum_models_test.dart`
Expected: PASS，9 個測試全過。

Run: `flutter analyze`
Expected: 無新增 error。

- [ ] **Step 6: Commit**

```bash
git add lib/core/constants/api.dart lib/models/forum_models.dart test/models/forum_models_test.dart
git commit -m "feat: 新增論壇 v2 資料模型與 API 端點常數"
```

---

### Task 3: 兩層留言的分組純函式

後端把第一層留言與第二層回覆分開放在 `comments` 與 `replies` 兩個陣列，畫面需要的是樹狀結構。抽成純函式才能在沒有 widget 的情況下測到邊界情況。

**Files:**
- Modify: `lib/models/forum_models.dart`
- Test: `test/models/forum_models_test.dart`（append）

**Interfaces:**
- Consumes: Task 2 的 `ForumComment`
- Produces:
  - `class ForumCommentThread { final ForumComment root; final List<ForumComment> replies; }`
  - `List<ForumCommentThread> groupComments(List<ForumComment> comments, List<ForumComment> replies)`

- [ ] **Step 1: 寫失敗的測試**

在 `test/models/forum_models_test.dart` 的 `main()` 內、最後一個 `group` 之後加入：

```dart
  group('groupComments', () {
    ForumComment comment(int id, {int? parent}) => ForumComment(
          id: id,
          postId: 1024,
          parentCommentId: parent,
          body: 'c$id',
          likeCount: 0,
          isLiked: false,
          createdAt: DateTime.parse('2026-08-01T11:00:00.000Z'),
          author: const ForumAuthor(uid: 1, displayName: 'A'),
        );

    test('回覆掛到所屬的第一層留言底下', () {
      final threads = groupComments(
        [comment(1), comment(2)],
        [comment(3, parent: 1), comment(4, parent: 1), comment(5, parent: 2)],
      );

      expect(threads.map((t) => t.root.id), [1, 2]);
      expect(threads[0].replies.map((r) => r.id), [3, 4]);
      expect(threads[1].replies.map((r) => r.id), [5]);
    });

    test('沒有回覆的留言 replies 為空', () {
      expect(groupComments([comment(1)], []).single.replies, isEmpty);
    });

    test('孤兒回覆（parent 不在本頁）被丟棄而非造成崩潰', () {
      final threads = groupComments([comment(1)], [comment(9, parent: 99)]);

      expect(threads, hasLength(1));
      expect(threads.single.replies, isEmpty);
    });

    test('保持 comments 傳入的順序，不重新排序', () {
      final threads = groupComments([comment(5), comment(2)], []);

      expect(threads.map((t) => t.root.id), [5, 2]);
    });
  });
```

- [ ] **Step 2: 執行測試，確認失敗**

Run: `flutter test test/models/forum_models_test.dart`
Expected: FAIL，`The function 'groupComments' isn't defined`。

- [ ] **Step 3: 實作**

在 `lib/models/forum_models.dart` 的 `ForumCommentPage` 之後加入：

```dart
/// 一則第一層留言與掛在它底下的回覆。論壇只有兩層，replies 不再有子節點。
class ForumCommentThread {
  final ForumComment root;
  final List<ForumComment> replies;

  const ForumCommentThread({required this.root, required this.replies});
}

/// 把後端分開回傳的第一層留言與第二層回覆合成樹。
///
/// 順序完全跟隨傳入順序（後端已依 created_at 排好），這裡不重新排序，
/// 以免與後端的分頁游標對不上。
///
/// parent 不在本頁的回覆會被丟棄：可能是 parent 已被軟刪除，也可能是分頁邊界。
/// 掛不上去的回覆沒有能顯示的位置，硬塞到第一層會讓對話看起來錯亂。
List<ForumCommentThread> groupComments(
  List<ForumComment> comments,
  List<ForumComment> replies,
) {
  final byParent = <int, List<ForumComment>>{};
  for (final reply in replies) {
    final parent = reply.parentCommentId;
    if (parent == null) continue;
    byParent.putIfAbsent(parent, () => []).add(reply);
  }
  return comments
      .map((c) => ForumCommentThread(
            root: c,
            replies: byParent[c.id] ?? const [],
          ))
      .toList();
}
```

- [ ] **Step 4: 執行測試，確認通過**

Run: `flutter test test/models/forum_models_test.dart`
Expected: PASS，13 個測試全過。

- [ ] **Step 5: Commit**

```bash
git add lib/models/forum_models.dart test/models/forum_models_test.dart
git commit -m "feat: 新增兩層留言的分組函式 groupComments"
```

---

### Task 4: ForumService

**Files:**
- Create: `lib/services/forum_service.dart`
- Test: `test/services/forum_service_test.dart`

**Interfaces:**
- Consumes: Task 1 的 `ApiClient.postMultipart` / `MultipartFileData`、Task 2 的全部 model 與 `ApiConfig` 端點
- Produces（後續畫面 task 全部依賴這些簽章）：

```dart
static Future<List<ForumBoard>> boards()
static Future<ForumPostPage> posts(String slug, {int? cursor, int? after, int limit = 20})
static Future<ForumPost> post(int id)
static Future<ForumPost> createPost({required int boardId, required String title, required String body, List<String> tags = const [], List<MultipartFileData> images = const []})
static Future<ForumPost> updatePost(int id, {String? title, String? body, List<String>? tags})
static Future<void> deletePost(int id)
static Future<ForumCommentPage> comments(int postId, {int? cursor})
static Future<ForumComment> createComment(int postId, String body, {int? parentCommentId})
static Future<void> deleteComment(int id)
static Future<({bool liked, int likeCount})> likePost(int id, {required bool like})
static Future<({bool liked, int likeCount})> likeComment(int id, {required bool like})
static Future<ForumPostPage> search(String q, {String? board, int? cursor})
static Future<List<ForumTagStat>> tags()
static Future<void> report({required String targetType, required int targetId, required String reason})
static Future<ForumNotificationPage> notifications({int? cursor})
static Future<void> markRead({List<int>? ids})
static Future<bool> bookmarkPost(int id, {required bool add})
static Future<ForumPostPage> bookmarks({int? cursor})
```

同時公開後端限制常數供畫面層驗證：`titleMax=120`、`bodyMax=5000`、`commentMax=2000`、`reasonMax=1000`、`tagMaxCount=5`、`tagNameMax=20`、`imageMaxCount=4`、`imageMaxBytes=5*1024*1024`、`searchMin=2`、`searchMax=80`。

- [ ] **Step 1: 寫失敗的測試**

建立 `test/services/forum_service_test.dart`：

```dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/services/forum_service.dart';

void main() {
  late List<http.BaseRequest> seen;

  /// 以固定 JSON 回應所有請求，並記錄收到的 request 供斷言。
  void respondWith(Map<String, dynamic> body, {int status = 200}) {
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

  Map<String, dynamic> postJson() => {
        'id': 1,
        'board': {'id': 2, 'slug': 'culture', 'name': '文化傳承'},
        'title': 't',
        'body': 'b',
        'like_count': 0,
        'comment_count': 0,
        'is_pinned': false,
        'is_liked': false,
        'created_at': '2026-08-01T10:00:00.000Z',
        'updated_at': '2026-08-01T10:00:00.000Z',
        'author': {'uid': 1, 'display_name': 'A', 'avatar_url': null},
      };

  tearDown(() => ApiClient.httpClient = http.Client());

  test('boards 打對端點並解析看板', () async {
    respondWith({
      'boards': [
        {'id': 1, 'slug': 'general', 'name': '綜合討論', 'description': null},
      ],
    });

    final boards = await ForumService.boards();

    expect(seen.single.url.path, '/api/forum/boards');
    expect(boards.single.slug, 'general');
  });

  test('posts 帶 cursor 與 limit', () async {
    respondWith({'pinned': [], 'posts': [], 'next_cursor': null});

    await ForumService.posts('culture', cursor: 500);

    expect(seen.single.url.path, '/api/forum/boards/culture/posts');
    expect(seen.single.url.queryParameters['cursor'], '500');
    expect(seen.single.url.queryParameters['limit'], '20');
    expect(seen.single.url.queryParameters.containsKey('after'), isFalse);
  });

  test('posts 帶 after 供下拉刷新，不同時帶 cursor', () async {
    respondWith({'pinned': [], 'posts': [], 'next_cursor': null});

    await ForumService.posts('culture', after: 900);

    expect(seen.single.url.queryParameters['after'], '900');
    expect(seen.single.url.queryParameters.containsKey('cursor'), isFalse);
  });

  test('likePost like=true 走 POST、like=false 走 DELETE', () async {
    respondWith({'liked': true, 'like_count': 4});
    final liked = await ForumService.likePost(7, like: true);
    expect(seen.single.method, 'POST');
    expect(seen.single.url.path, '/api/forum/posts/7/like');
    expect(liked.liked, isTrue);
    expect(liked.likeCount, 4);

    respondWith({'liked': false, 'like_count': 3});
    await ForumService.likePost(7, like: false);
    expect(seen.single.method, 'DELETE');
  });

  test('createComment 帶 parentCommentId 時送出第二層回覆', () async {
    respondWith({
      'comment': {
        'id': 11,
        'post_id': 7,
        'parent_comment_id': 5,
        'body': '回覆',
        'like_count': 0,
        'is_liked': false,
        'created_at': '2026-08-01T11:00:00.000Z',
        'author': {'uid': 1, 'display_name': 'A', 'avatar_url': null},
      },
    }, status: 201);

    final comment =
        await ForumService.createComment(7, '回覆', parentCommentId: 5);

    final body = jsonDecode((seen.single as http.Request).body);
    expect(body['body'], '回覆');
    expect(body['parent_comment_id'], 5);
    expect(comment.parentCommentId, 5);
  });

  test('createPost 沒有附圖時走 JSON', () async {
    respondWith({'post': postJson()}, status: 201);

    await ForumService.createPost(boardId: 2, title: 't', body: 'b');

    expect(seen.single, isA<http.Request>());
    final body = jsonDecode((seen.single as http.Request).body);
    expect(body['board_id'], 2);
  });

  test('createPost 有附圖時走 multipart，標籤以 JSON 字串傳遞', () async {
    respondWith({'post': postJson()}, status: 201);

    await ForumService.createPost(
      boardId: 2,
      title: 't',
      body: 'b',
      tags: ['族語', '走讀'],
      images: [
        const MultipartFileData(
          field: 'images',
          bytes: [1, 2],
          filename: 'a.jpg',
          mimeType: 'image/jpeg',
        ),
      ],
    );

    final request = seen.single;
    expect(request.method, 'POST');
    expect(request.headers['content-type'], contains('multipart/form-data'));
    final fields = (request as http.MultipartRequest).fields;
    expect(fields['board_id'], '2');
    expect(jsonDecode(fields['tags']!), ['族語', '走讀']);
  });

  test('search 少於 2 字直接丟錯，不發請求', () async {
    respondWith({'posts': [], 'next_cursor': null});

    expect(() => ForumService.search('族'), throwsA(isA<ArgumentError>()));
    expect(seen, isEmpty);
  });

  test('markRead 不帶 ids 時送出空 body 代表全部已讀', () async {
    respondWith({'ok': true});

    await ForumService.markRead();

    expect(seen.single.url.path, '/api/forum/notifications/read');
    expect(jsonDecode((seen.single as http.Request).body), <String, dynamic>{});
  });

  test('report 送出 target_type 與 target_id', () async {
    respondWith({'ok': true}, status: 201);

    await ForumService.report(
      targetType: 'comment',
      targetId: 11,
      reason: '廣告',
    );

    final body = jsonDecode((seen.single as http.Request).body);
    expect(body, {'target_type': 'comment', 'target_id': 11, 'reason': '廣告'});
  });

  test('bookmarkPost add=false 走 DELETE', () async {
    respondWith({'bookmarked': false});

    final result = await ForumService.bookmarkPost(7, add: false);

    expect(seen.single.method, 'DELETE');
    expect(seen.single.url.path, '/api/forum/posts/7/bookmark');
    expect(result, isFalse);
  });
}
```

- [ ] **Step 2: 執行測試，確認失敗**

Run: `flutter test test/services/forum_service_test.dart`
Expected: FAIL，`Target of URI doesn't exist: 'package:flutter_application_1/services/forum_service.dart'`。

- [ ] **Step 3: 實作 ForumService**

建立 `lib/services/forum_service.dart`：

```dart
// 論壇 v2 API 呼叫。沿用共用的 ApiClient（自動帶 JWT、401 自動導回登入、
// 統一 {error:{code,message}} 錯誤解析）。
// 對應後端 Truku_backend feature/forum-v2 的 backend/routes/forum.ts。
//
// 端點：
//   GET    /api/forum/boards                      看板列表
//   GET    /api/forum/boards/:slug/posts          看板貼文（cursor 分頁 / after 下拉刷新）
//   POST   /api/forum/posts                       發文（可帶附圖，multipart）
//   GET    /api/forum/posts/:id                   貼文詳情
//   PATCH  /api/forum/posts/:id                   編輯（僅文字欄位）
//   DELETE /api/forum/posts/:id                   軟刪除
//   GET    /api/forum/posts/:id/comments          留言（兩層）
//   POST   /api/forum/posts/:id/comments          新增留言／回覆
//   DELETE /api/forum/comments/:id                軟刪除留言
//   POST   / DELETE /api/forum/posts/:id/like     貼文按讚 / 取消
//   POST   / DELETE /api/forum/comments/:id/like  留言按讚 / 取消
//   GET    /api/forum/search                      關鍵字搜尋
//   GET    /api/forum/tags                        標籤列表
//   POST   /api/forum/reports                     檢舉
//   GET    /api/forum/notifications               我的通知
//   POST   /api/forum/notifications/read          標記已讀
//   POST   / DELETE /api/forum/posts/:id/bookmark 收藏 / 取消（後端待補，規格 §9）
//   GET    /api/forum/bookmarks                   我的收藏（後端待補，規格 §9）

import 'dart:convert';

import '../core/constants/api.dart';
import '../core/network/api_client.dart';
import '../models/forum_models.dart';

class ForumService {
  // 後端硬性限制，畫面層據此在送出前擋下必然失敗的請求。
  static const int titleMax = 120;
  static const int bodyMax = 5000;
  static const int commentMax = 2000;
  static const int reasonMax = 1000;
  static const int tagMaxCount = 5;
  static const int tagNameMax = 20;
  static const int imageMaxCount = 4;
  static const int imageMaxBytes = 5 * 1024 * 1024;
  static const int searchMin = 2;
  static const int searchMax = 80;

  // ── 看板 ──────────────────────────────────────────────────

  static Future<List<ForumBoard>> boards() async {
    final data = await ApiClient.get(ApiConfig.forumBoards);
    return (data['boards'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ForumBoard.fromJson)
        .toList();
  }

  // ── 貼文 ──────────────────────────────────────────────────

  /// 看板貼文。[cursor] 往下翻頁（取比它舊的），[after] 下拉刷新（取比它新的）。
  /// 兩者互斥，同時帶會讓後端的條件互相打架。
  static Future<ForumPostPage> posts(
    String slug, {
    int? cursor,
    int? after,
    int limit = 20,
  }) async {
    assert(cursor == null || after == null, 'cursor 與 after 不可同時使用');
    final data = await ApiClient.get(
      ApiConfig.forumBoardPosts(slug),
      query: {
        if (cursor != null) 'cursor': '$cursor',
        if (after != null) 'after': '$after',
        'limit': '$limit',
      },
    );
    return ForumPostPage.fromJson(data);
  }

  static Future<ForumPost> post(int id) async {
    final data = await ApiClient.get(ApiConfig.forumPost(id));
    return ForumPost.fromJson(data['post'] as Map<String, dynamic>);
  }

  /// 發文。後端同一個端點吃 JSON 與 multipart，有附圖時必須走 multipart。
  /// 附圖須由呼叫端先壓縮到 [imageMaxBytes] 以內——後端不做伺服器端壓縮。
  static Future<ForumPost> createPost({
    required int boardId,
    required String title,
    required String body,
    List<String> tags = const [],
    List<MultipartFileData> images = const [],
  }) async {
    final Map<String, dynamic> data;
    if (images.isEmpty) {
      data = await ApiClient.post(ApiConfig.forumPosts, {
        'board_id': boardId,
        'title': title,
        'body': body,
        if (tags.isNotEmpty) 'tags': tags,
      });
    } else {
      data = await ApiClient.postMultipart(
        ApiConfig.forumPosts,
        fields: {
          'board_id': '$boardId',
          'title': title,
          'body': body,
          // multipart 的欄位值只能是字串，陣列改以 JSON 字串傳遞。
          if (tags.isNotEmpty) 'tags': jsonEncode(tags),
        },
        files: images,
      );
    }
    return ForumPost.fromJson(data['post'] as Map<String, dynamic>);
  }

  /// 編輯。後端只接受文字欄位，附圖無法在此變更。
  static Future<ForumPost> updatePost(
    int id, {
    String? title,
    String? body,
    List<String>? tags,
  }) async {
    final data = await ApiClient.patch(ApiConfig.forumPost(id), {
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      if (tags != null) 'tags': tags,
    });
    return ForumPost.fromJson(data['post'] as Map<String, dynamic>);
  }

  static Future<void> deletePost(int id) =>
      ApiClient.delete(ApiConfig.forumPost(id));

  // ── 留言 ──────────────────────────────────────────────────

  static Future<ForumCommentPage> comments(int postId, {int? cursor}) async {
    final data = await ApiClient.get(
      ApiConfig.forumPostComments(postId),
      query: {if (cursor != null) 'cursor': '$cursor'},
    );
    return ForumCommentPage.fromJson(data);
  }

  /// [parentCommentId] 必須指向第一層留言；論壇只有兩層，後端會擋第三層。
  static Future<ForumComment> createComment(
    int postId,
    String body, {
    int? parentCommentId,
  }) async {
    final data = await ApiClient.post(ApiConfig.forumPostComments(postId), {
      'body': body,
      if (parentCommentId != null) 'parent_comment_id': parentCommentId,
    });
    return ForumComment.fromJson(data['comment'] as Map<String, dynamic>);
  }

  static Future<void> deleteComment(int id) =>
      ApiClient.delete(ApiConfig.forumComment(id));

  // ── 按讚 ──────────────────────────────────────────────────

  static Future<({bool liked, int likeCount})> likePost(
    int id, {
    required bool like,
  }) =>
      _toggleLike(ApiConfig.forumPostLike(id), like: like);

  static Future<({bool liked, int likeCount})> likeComment(
    int id, {
    required bool like,
  }) =>
      _toggleLike(ApiConfig.forumCommentLike(id), like: like);

  /// 回傳後端算出的真實計數，呼叫端不要自行累加——樂觀更新只是暫時值。
  static Future<({bool liked, int likeCount})> _toggleLike(
    String path, {
    required bool like,
  }) async {
    final data =
        like ? await ApiClient.post(path) : await ApiClient.delete(path);
    return (
      liked: data['liked'] == true,
      likeCount: int.tryParse(data['like_count']?.toString() ?? '') ?? 0,
    );
  }

  // ── 標籤與搜尋 ────────────────────────────────────────────

  static Future<List<ForumTagStat>> tags() async {
    final data = await ApiClient.get(ApiConfig.forumTags);
    return (data['tags'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ForumTagStat.fromJson)
        .toList();
  }

  /// 後端限制關鍵字 2-80 字，未達長度直接擋下，不送出必然失敗的請求。
  static Future<ForumPostPage> search(
    String q, {
    String? board,
    int? cursor,
  }) async {
    final trimmed = q.trim();
    if (trimmed.length < searchMin || trimmed.length > searchMax) {
      throw ArgumentError('搜尋關鍵字須為 $searchMin-$searchMax 字');
    }
    final data = await ApiClient.get(ApiConfig.forumSearch, query: {
      'q': trimmed,
      if (board != null && board.isNotEmpty) 'board': board,
      if (cursor != null) 'cursor': '$cursor',
    });
    return ForumPostPage.fromJson(data);
  }

  // ── 檢舉 ──────────────────────────────────────────────────

  /// [targetType] 為 'post' 或 'comment'。同一人重複檢舉後端不視為錯誤。
  static Future<void> report({
    required String targetType,
    required int targetId,
    required String reason,
  }) =>
      ApiClient.post(ApiConfig.forumReports, {
        'target_type': targetType,
        'target_id': targetId,
        'reason': reason,
      });

  // ── 通知 ──────────────────────────────────────────────────

  static Future<ForumNotificationPage> notifications({int? cursor}) async {
    final data = await ApiClient.get(
      ApiConfig.forumNotifications,
      query: {if (cursor != null) 'cursor': '$cursor'},
    );
    return ForumNotificationPage.fromJson(data);
  }

  /// 不帶 [ids] 代表全部標記已讀。
  static Future<void> markRead({List<int>? ids}) =>
      ApiClient.post(ApiConfig.forumNotificationsRead, {
        if (ids != null) 'ids': ids,
      });

  // ── 書籤（後端待補，規格 §9）────────────────────────────────

  /// 回傳操作後的收藏狀態。端點上線前會拿到 404，由畫面顯示錯誤訊息。
  static Future<bool> bookmarkPost(int id, {required bool add}) async {
    final path = ApiConfig.forumPostBookmark(id);
    final data = add ? await ApiClient.post(path) : await ApiClient.delete(path);
    return data['bookmarked'] == true;
  }

  static Future<ForumPostPage> bookmarks({int? cursor}) async {
    final data = await ApiClient.get(
      ApiConfig.forumBookmarks,
      query: {if (cursor != null) 'cursor': '$cursor'},
    );
    return ForumPostPage.fromJson(data);
  }
}
```

- [ ] **Step 4: 執行測試，確認通過**

Run: `flutter test test/services/forum_service_test.dart`
Expected: PASS，11 個測試全過。

- [ ] **Step 5: 全量測試與靜態檢查**

Run: `flutter test`
Expected: 全部通過。

Run: `flutter analyze`
Expected: 無新增 error。

- [ ] **Step 6: Commit**

```bash
git add lib/services/forum_service.dart test/services/forum_service_test.dart
git commit -m "feat: 新增 ForumService 串接論壇 v2 全部端點"
```

---

### Task 5: 附圖網格與貼文卡片

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/screens/forum/widgets/forum_image_grid.dart`
- Create: `lib/screens/forum/widgets/forum_post_card.dart`
- Test: `test/widgets/forum_post_card_test.dart`

**Interfaces:**
- Consumes: Task 2 的 `ForumPost` / `ForumTag`
- Produces:
  - `ForumImageGrid({required List<String> urls})` — 1 張滿版、2–4 張九宮格，點擊開全螢幕檢視
  - `ForumPostCard({required ForumPost post, required VoidCallback onTap, required VoidCallback onLike, required VoidCallback onBookmark})` — 無狀態，樂觀更新由父層負責

- [ ] **Step 1: 加入 `cached_network_image` 依賴**

編輯 `pubspec.yaml`，在 `better_player_plus: ^1.3.4` 之後加入：

```yaml

  # 論壇附圖：列表捲動時避免重複下載
  cached_network_image: ^3.4.1
```

Run: `flutter pub get`
Expected: `Got dependencies!`

- [ ] **Step 2: 寫失敗的測試**

建立 `test/widgets/forum_post_card_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/forum_models.dart';
import 'package:flutter_application_1/screens/forum/widgets/forum_post_card.dart';

ForumPost buildPost({
  String title = '關於 mhuway',
  int likeCount = 3,
  int commentCount = 5,
  bool isPinned = false,
  bool isLiked = false,
  List<ForumTag> tags = const [],
  List<String> images = const [],
}) =>
    ForumPost(
      id: 1,
      board: const ForumBoard(id: 2, slug: 'culture', name: '文化傳承'),
      title: title,
      body: '內文',
      likeCount: likeCount,
      commentCount: commentCount,
      isPinned: isPinned,
      isLiked: isLiked,
      isBookmarked: false,
      images: images,
      tags: tags,
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      updatedAt: DateTime.now(),
      author: const ForumAuthor(uid: 7, displayName: 'Sayun'),
    );

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('顯示標題、作者、看板名與計數', (tester) async {
    await tester.pumpWidget(wrap(ForumPostCard(
      post: buildPost(),
      onTap: () {},
      onLike: () {},
      onBookmark: () {},
    )));

    expect(find.text('關於 mhuway'), findsOneWidget);
    expect(find.text('Sayun'), findsOneWidget);
    expect(find.textContaining('文化傳承'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
  });

  testWidgets('置頂貼文顯示置頂標記，非置頂不顯示', (tester) async {
    await tester.pumpWidget(wrap(ForumPostCard(
      post: buildPost(isPinned: true),
      onTap: () {},
      onLike: () {},
      onBookmark: () {},
    )));
    expect(find.text('置頂'), findsOneWidget);

    await tester.pumpWidget(wrap(ForumPostCard(
      post: buildPost(),
      onTap: () {},
      onLike: () {},
      onBookmark: () {},
    )));
    expect(find.text('置頂'), findsNothing);
  });

  testWidgets('標籤以 # 前綴顯示，沒有標籤時不佔位', (tester) async {
    await tester.pumpWidget(wrap(ForumPostCard(
      post: buildPost(tags: const [ForumTag(name: '族語', slug: 'yuyan')]),
      onTap: () {},
      onLike: () {},
      onBookmark: () {},
    )));

    expect(find.text('#族語'), findsOneWidget);
  });

  testWidgets('點卡片觸發 onTap、點讚觸發 onLike', (tester) async {
    var tapped = 0;
    var liked = 0;
    await tester.pumpWidget(wrap(ForumPostCard(
      post: buildPost(),
      onTap: () => tapped++,
      onLike: () => liked++,
      onBookmark: () {},
    )));

    await tester.tap(find.byKey(const ValueKey('forum-post-like')));
    await tester.pump();
    expect(liked, 1);

    await tester.tap(find.text('關於 mhuway'));
    await tester.pump();
    expect(tapped, 1);
  });

  testWidgets('已按讚時顯示實心愛心', (tester) async {
    await tester.pumpWidget(wrap(ForumPostCard(
      post: buildPost(isLiked: true),
      onTap: () {},
      onLike: () {},
      onBookmark: () {},
    )));

    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsNothing);
  });
}
```

- [ ] **Step 3: 執行測試，確認失敗**

Run: `flutter test test/widgets/forum_post_card_test.dart`
Expected: FAIL，`Target of URI doesn't exist: '.../forum_post_card.dart'`。

- [ ] **Step 4: 實作附圖網格**

建立 `lib/screens/forum/widgets/forum_image_grid.dart`：

```dart
// 貼文附圖。後端最多 4 張，1 張時滿版、2-4 張時九宮格。
// 點任一張進入全螢幕檢視，可左右滑動切換。

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class ForumImageGrid extends StatelessWidget {
  final List<String> urls;

  const ForumImageGrid({super.key, required this.urls});

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) return const SizedBox.shrink();
    if (urls.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: AspectRatio(
          aspectRatio: 16 / 10,
          child: _Thumb(urls: urls, index: 0),
        ),
      );
    }
    return GridView.count(
      crossAxisCount: urls.length == 2 ? 2 : 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      children: [
        for (var i = 0; i < urls.length; i++)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _Thumb(urls: urls, index: i),
          ),
      ],
    );
  }
}

class _Thumb extends StatelessWidget {
  final List<String> urls;
  final int index;

  const _Thumb({required this.urls, required this.index});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ForumImageViewer(urls: urls, initialIndex: index),
          ),
        ),
        child: CachedNetworkImage(
          imageUrl: urls[index],
          fit: BoxFit.cover,
          placeholder: (_, _) => Container(color: AppColors.creamDeep),
          errorWidget: (_, _, _) => Container(
            color: AppColors.creamDeep,
            alignment: Alignment.center,
            child: const Icon(
              Icons.broken_image_outlined,
              color: AppColors.fog,
              size: 20,
            ),
          ),
        ),
      );
}

/// 全螢幕檢視。深色底讓照片本身成為主體。
class ForumImageViewer extends StatelessWidget {
  final List<String> urls;
  final int initialIndex;

  const ForumImageViewer({
    super.key,
    required this.urls,
    required this.initialIndex,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.midnight,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: AppColors.creamLight),
        ),
        extendBodyBehindAppBar: true,
        body: PageView.builder(
          controller: PageController(initialPage: initialIndex),
          itemCount: urls.length,
          itemBuilder: (_, i) => InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: Center(
              child: CachedNetworkImage(imageUrl: urls[i], fit: BoxFit.contain),
            ),
          ),
        ),
      );
}
```

- [ ] **Step 5: 實作貼文卡片**

建立 `lib/screens/forum/widgets/forum_post_card.dart`：

```dart
// 貼文列表卡片。視覺沿用 feature/forum-dcard 的語彙：cream 底、creamDeep 邊框、
// 圓角 16、圓形頭像描 gold 邊。
//
// 本元件無狀態：按讚與收藏只回呼給父層，樂觀更新與回滾由持有列表的一方負責，
// 避免同一筆貼文在列表與詳情頁各自持有互相打架的本地狀態。

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../models/forum_models.dart';
import 'forum_image_grid.dart';

String forumRelativeTime(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return '剛剛';
  if (diff.inMinutes < 60) return '${diff.inMinutes} 分鐘前';
  if (diff.inHours < 24) return '${diff.inHours} 小時前';
  if (diff.inDays < 7) return '${diff.inDays} 天前';
  return '${time.year}/${time.month}/${time.day}';
}

class ForumPostCard extends StatelessWidget {
  final ForumPost post;
  final VoidCallback onTap;
  final VoidCallback onLike;
  final VoidCallback onBookmark;

  const ForumPostCard({
    super.key,
    required this.post,
    required this.onTap,
    required this.onLike,
    required this.onBookmark,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 10),
          decoration: BoxDecoration(
            color: AppColors.cream,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.creamDeep),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(),
              const SizedBox(height: 10),
              Text(
                post.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.notoSerifTc(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                post.body,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.inkSoft,
                  height: 1.55,
                  letterSpacing: 0.5,
                ),
              ),
              if (post.images.isNotEmpty) ...[
                const SizedBox(height: 10),
                ForumImageGrid(urls: post.images),
              ],
              if (post.tags.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [for (final tag in post.tags) _tagChip(tag)],
                ),
              ],
              const SizedBox(height: 6),
              _footer(),
            ],
          ),
        ),
      );

  Widget _header() => Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
              border: Border.fromBorderSide(
                BorderSide(color: AppColors.gold, width: 1.5),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              post.author.displayName.characters.firstOrNull ?? '?',
              style: GoogleFonts.notoSerifTc(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.gold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.author.displayName,
                  style: GoogleFonts.notoSerifTc(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                    letterSpacing: 0.6,
                  ),
                ),
                Text(
                  '${post.board.name} · ${forumRelativeTime(post.createdAt)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.fog,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          if (post.isPinned)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '置頂',
                style: GoogleFonts.notoSerifTc(
                  fontSize: 11,
                  color: AppColors.goldDeep,
                  letterSpacing: 1.2,
                ),
              ),
            ),
        ],
      );

  Widget _tagChip(ForumTag tag) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '#${tag.name}',
          style: GoogleFonts.crimsonPro(
            fontStyle: FontStyle.italic,
            fontSize: 11,
            color: AppColors.primary,
            letterSpacing: 1.2,
          ),
        ),
      );

  Widget _footer() => Row(
        children: [
          _iconCount(
            key: const ValueKey('forum-post-like'),
            icon: post.isLiked ? Icons.favorite : Icons.favorite_border,
            color: post.isLiked ? AppColors.primary : AppColors.fog,
            count: post.likeCount,
            onTap: onLike,
          ),
          const SizedBox(width: 18),
          _iconCount(
            key: const ValueKey('forum-post-comment'),
            icon: Icons.mode_comment_outlined,
            color: AppColors.fog,
            count: post.commentCount,
            onTap: onTap,
          ),
          const Spacer(),
          IconButton(
            key: const ValueKey('forum-post-bookmark'),
            onPressed: onBookmark,
            visualDensity: VisualDensity.compact,
            icon: Icon(
              post.isBookmarked ? Icons.bookmark : Icons.bookmark_border,
              size: 18,
              color: post.isBookmarked ? AppColors.primary : AppColors.fog,
            ),
          ),
        ],
      );

  Widget _iconCount({
    required Key key,
    required IconData icon,
    required Color color,
    required int count,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        key: key,
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 5),
              Text(
                '$count',
                style: TextStyle(fontSize: 12, color: color),
              ),
            ],
          ),
        ),
      );
}
```

- [ ] **Step 6: 執行測試，確認通過**

Run: `flutter test test/widgets/forum_post_card_test.dart`
Expected: PASS，5 個測試全過。

Run: `flutter analyze`
Expected: 無新增 error。

- [ ] **Step 7: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/screens/forum/widgets/forum_image_grid.dart lib/screens/forum/widgets/forum_post_card.dart test/widgets/forum_post_card_test.dart
git commit -m "feat: 新增論壇貼文卡片與附圖網格"
```

---

### Task 6: 看板列表與廣場頁改造

**Files:**
- Create: `lib/screens/forum/forum_board_view.dart`
- Modify: `lib/screens/plaza/plaza_screen.dart`
- Delete: `lib/screens/plaza/compose_screen.dart`
- Test: `test/widgets/forum_board_view_test.dart`

**Interfaces:**
- Consumes: Task 2 的 `ForumPost` / `ForumPostPage`、Task 4 的 `ForumService`、Task 5 的 `ForumPostCard`
- Produces:

```dart
typedef ForumPageLoader = Future<ForumPostPage> Function({int? cursor, int? after});
typedef ForumLikeToggler = Future<({bool liked, int likeCount})> Function(int postId, {required bool like});
typedef ForumBookmarkToggler = Future<bool> Function(int postId, {required bool add});

class ForumBoardView extends StatefulWidget {
  const ForumBoardView({
    super.key,
    required this.loadPage,
    required this.toggleLike,
    required this.toggleBookmark,
    required this.onOpenPost,
    this.emptyMessage = '這個看板還沒有貼文',
  });
}
```

資料來源以 callback 注入而非直接呼叫 `ForumService`：測試才能在沒有網路的情況下驅動分頁與回滾，同一個元件也能被「我的收藏」與搜尋結果重複使用。

- [ ] **Step 1: 寫失敗的測試**

建立 `test/widgets/forum_board_view_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/models/forum_models.dart';
import 'package:flutter_application_1/screens/forum/forum_board_view.dart';

ForumPost post(int id, {int likeCount = 0, bool isLiked = false}) => ForumPost(
      id: id,
      board: const ForumBoard(id: 2, slug: 'culture', name: '文化傳承'),
      title: '標題 $id',
      body: '內文',
      likeCount: likeCount,
      commentCount: 0,
      isPinned: false,
      isLiked: isLiked,
      isBookmarked: false,
      images: const [],
      tags: const [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      author: const ForumAuthor(uid: 7, displayName: 'Sayun'),
    );

Widget wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: SizedBox(height: 800, child: child)));

void main() {
  testWidgets('沒有貼文時顯示空狀態', (tester) async {
    await tester.pumpWidget(wrap(ForumBoardView(
      loadPage: ({cursor, after}) async =>
          const ForumPostPage(pinned: [], posts: [], nextCursor: null),
      toggleLike: (_, {required like}) async => (liked: like, likeCount: 0),
      toggleBookmark: (_, {required add}) async => add,
      onOpenPost: (_) {},
    )));
    await tester.pumpAndSettle();

    expect(find.text('這個看板還沒有貼文'), findsOneWidget);
  });

  testWidgets('置頂貼文排在一般貼文之前', (tester) async {
    await tester.pumpWidget(wrap(ForumBoardView(
      loadPage: ({cursor, after}) async => ForumPostPage(
        pinned: [post(99)],
        posts: [post(1)],
        nextCursor: null,
      ),
      toggleLike: (_, {required like}) async => (liked: like, likeCount: 0),
      toggleBookmark: (_, {required add}) async => add,
      onOpenPost: (_) {},
    )));
    await tester.pumpAndSettle();

    final titles = tester
        .widgetList<Text>(find.textContaining('標題'))
        .map((t) => t.data)
        .toList();
    expect(titles.first, '標題 99');
  });

  testWidgets('載入失敗時顯示重試，按下重試會重新載入', (tester) async {
    var calls = 0;
    await tester.pumpWidget(wrap(ForumBoardView(
      loadPage: ({cursor, after}) async {
        calls++;
        if (calls == 1) {
          throw ApiException(
            statusCode: 0,
            code: 'NETWORK_ERROR',
            message: '無法連線到伺服器，請檢查網路',
          );
        }
        return ForumPostPage(pinned: const [], posts: [post(1)], nextCursor: null);
      },
      toggleLike: (_, {required like}) async => (liked: like, likeCount: 0),
      toggleBookmark: (_, {required add}) async => add,
      onOpenPost: (_) {},
    )));
    await tester.pumpAndSettle();

    expect(find.text('無法連線到伺服器，請檢查網路'), findsOneWidget);

    await tester.tap(find.text('重試'));
    await tester.pumpAndSettle();

    expect(find.text('標題 1'), findsOneWidget);
    expect(calls, 2);
  });

  testWidgets('按讚先樂觀更新，成功後以後端計數校正', (tester) async {
    await tester.pumpWidget(wrap(ForumBoardView(
      loadPage: ({cursor, after}) async => ForumPostPage(
        pinned: const [],
        posts: [post(1, likeCount: 3)],
        nextCursor: null,
      ),
      // 後端回的計數刻意與樂觀值不同，驗證前端有採用後端的值。
      toggleLike: (_, {required like}) async => (liked: true, likeCount: 10),
      toggleBookmark: (_, {required add}) async => add,
      onOpenPost: (_) {},
    )));
    await tester.pumpAndSettle();

    expect(find.text('3'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('forum-post-like')));
    await tester.pump(); // 樂觀更新後、後端回應前
    expect(find.text('4'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('10'), findsOneWidget);
  });

  testWidgets('按讚失敗時回滾到原本狀態', (tester) async {
    await tester.pumpWidget(wrap(ForumBoardView(
      loadPage: ({cursor, after}) async => ForumPostPage(
        pinned: const [],
        posts: [post(1, likeCount: 3)],
        nextCursor: null,
      ),
      toggleLike: (_, {required like}) async => throw ApiException(
        statusCode: 500,
        code: 'UNKNOWN',
        message: '發生未知錯誤',
      ),
      toggleBookmark: (_, {required add}) async => add,
      onOpenPost: (_) {},
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('forum-post-like')));
    await tester.pump();
    expect(find.text('4'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('3'), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
  });

  testWidgets('捲到底時以 cursor 載入下一頁', (tester) async {
    final seenCursors = <int?>[];
    await tester.pumpWidget(wrap(ForumBoardView(
      loadPage: ({cursor, after}) async {
        seenCursors.add(cursor);
        if (cursor == null) {
          return ForumPostPage(
            pinned: const [],
            posts: [for (var i = 20; i > 0; i--) post(i)],
            nextCursor: 1,
          );
        }
        return ForumPostPage(
          pinned: const [],
          posts: [post(0)],
          nextCursor: null,
        );
      },
      toggleLike: (_, {required like}) async => (liked: like, likeCount: 0),
      toggleBookmark: (_, {required add}) async => add,
      onOpenPost: (_) {},
    )));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -4000));
    await tester.pumpAndSettle();

    expect(seenCursors, [null, 1]);
    expect(find.text('標題 0'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 執行測試，確認失敗**

Run: `flutter test test/widgets/forum_board_view_test.dart`
Expected: FAIL，`Target of URI doesn't exist: '.../forum_board_view.dart'`。

- [ ] **Step 3: 實作 ForumBoardView**

建立 `lib/screens/forum/forum_board_view.dart`：

```dart
// 看板貼文列表。下拉刷新、觸底分頁、按讚與收藏的樂觀更新都在這裡。
//
// 資料來源以 callback 注入而不是直接呼叫 ForumService：測試才能在沒有網路的
// 情況下驅動分頁與回滾，同一個元件也能被「我的收藏」與搜尋結果重複使用。

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../models/forum_models.dart';
import '../../shared/widgets/truku_widgets.dart';
import 'widgets/forum_post_card.dart';

typedef ForumPageLoader = Future<ForumPostPage> Function({
  int? cursor,
  int? after,
});
typedef ForumLikeToggler = Future<({bool liked, int likeCount})> Function(
  int postId, {
  required bool like,
});
typedef ForumBookmarkToggler = Future<bool> Function(
  int postId, {
  required bool add,
});

class ForumBoardView extends StatefulWidget {
  final ForumPageLoader loadPage;
  final ForumLikeToggler toggleLike;
  final ForumBookmarkToggler toggleBookmark;
  final void Function(ForumPost post) onOpenPost;
  final String emptyMessage;

  const ForumBoardView({
    super.key,
    required this.loadPage,
    required this.toggleLike,
    required this.toggleBookmark,
    required this.onOpenPost,
    this.emptyMessage = '這個看板還沒有貼文',
  });

  @override
  State<ForumBoardView> createState() => ForumBoardViewState();
}

class ForumBoardViewState extends State<ForumBoardView> {
  final _scrollController = ScrollController();
  final List<ForumPost> _pinned = [];
  final List<ForumPost> _posts = [];

  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int? _nextCursor;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void didUpdateWidget(covariant ForumBoardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 切換看板時 loadPage 會換成新的 closure，須整份重載。
    if (oldWidget.loadPage != widget.loadPage) _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 300) _loadMore();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.loadPage();
      if (!mounted) return;
      setState(() {
        _pinned
          ..clear()
          ..addAll(page.pinned);
        _posts
          ..clear()
          ..addAll(page.posts);
        _nextCursor = page.nextCursor;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _nextCursor == null) return;
    setState(() => _loadingMore = true);
    try {
      final page = await widget.loadPage(cursor: _nextCursor);
      if (!mounted) return;
      setState(() {
        _posts.addAll(page.posts);
        _nextCursor = page.nextCursor;
        _loadingMore = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      _toast(e.message);
    }
  }

  /// 下拉刷新用 after 只取斷層後的新貼文，接在最前面。
  /// 列表為空時沒有可用的 after，退回整份重載。
  Future<void> refresh() async {
    if (_posts.isEmpty) return _load();
    try {
      final page = await widget.loadPage(after: _posts.first.id);
      if (!mounted) return;
      setState(() {
        _pinned
          ..clear()
          ..addAll(page.pinned);
        _posts.insertAll(0, page.posts);
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      _toast(e.message);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// 就地替換一筆貼文（置頂區與一般區都找）。
  void _replace(ForumPost post) {
    final pinnedIndex = _pinned.indexWhere((p) => p.id == post.id);
    if (pinnedIndex >= 0) _pinned[pinnedIndex] = post;
    final index = _posts.indexWhere((p) => p.id == post.id);
    if (index >= 0) _posts[index] = post;
  }

  Future<void> _like(ForumPost post) async {
    final original = post;
    setState(() => _replace(post.toggledLike()));
    try {
      final result = await widget.toggleLike(post.id, like: !post.isLiked);
      if (!mounted) return;
      // 以後端算出的真實計數校正，不沿用樂觀值。
      setState(() => _replace(
            original.copyWith(
              isLiked: result.liked,
              likeCount: result.likeCount,
            ),
          ));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _replace(original));
      _toast(e.message);
    }
  }

  Future<void> _bookmark(ForumPost post) async {
    final original = post;
    setState(() => _replace(post.toggledBookmark()));
    try {
      final added = await widget.toggleBookmark(
        post.id,
        add: !post.isBookmarked,
      );
      if (!mounted) return;
      setState(() => _replace(original.copyWith(isBookmarked: added)));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _replace(original));
      _toast(e.message);
    }
  }

  /// 貼文被刪除（詳情頁回報 404 或作者本人刪除）時從列表移除。
  void removePost(int postId) {
    setState(() {
      _pinned.removeWhere((p) => p.id == postId);
      _posts.removeWhere((p) => p.id == postId);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }
    if (_error != null) {
      return _ForumErrorState(message: _error!, onRetry: _load);
    }

    final all = [..._pinned, ..._posts];
    if (all.isEmpty) {
      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [_ForumEmptyState(message: widget.emptyMessage)],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: refresh,
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
        itemCount: all.length + (_loadingMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          if (i >= all.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
              ),
            );
          }
          final post = all[i];
          return ForumPostCard(
            post: post,
            onTap: () => widget.onOpenPost(post),
            onLike: () => _like(post),
            onBookmark: () => _bookmark(post),
          );
        },
      ),
    );
  }
}

class _ForumEmptyState extends StatelessWidget {
  final String message;

  const _ForumEmptyState({required this.message});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
        child: Column(
          children: [
            SizedBox(
              width: 76,
              height: 76,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.creamDeep,
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox.expand(),
                  ),
                  const Positioned(
                    right: -6,
                    top: -6,
                    child: Opacity(
                      opacity: 0.13,
                      child: TrukuDiamond(size: 40, color: AppColors.primary),
                    ),
                  ),
                  const Icon(
                    Icons.forum_outlined,
                    color: AppColors.primary,
                    size: 34,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: GoogleFonts.notoSerifTc(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '下拉重新整理，或成為第一位分享的人。',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.fog),
            ),
          ],
        ),
      );
}

class _ForumErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ForumErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
        child: Column(
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 40,
              color: AppColors.fog,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.inkSoft),
            ),
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
              ),
              child: const Text('重試'),
            ),
          ],
        ),
      );
}
```

`TrukuDiamond` 需要非 const 的建構，若 analyzer 對 `const` 有意見，把該行的 `const` 移除即可。

- [ ] **Step 4: 執行測試，確認通過**

Run: `flutter test test/widgets/forum_board_view_test.dart`
Expected: PASS，6 個測試全過。

- [ ] **Step 5: 改造廣場頁**

改寫 `lib/screens/plaza/plaza_screen.dart`：

- 移除 `_posts` 假資料常數、`_PostData`、`_PostCard` 三段，以及 `import 'compose_screen.dart';`
- 新增狀態：`List<ForumBoard> _boards = []`、`String? _boardSlug`、`bool _boardsLoading = true`、`int _unread = 0`、`final _boardViewKey = GlobalKey<ForumBoardViewState>()`
- `initState` 除 `_loadEvents()` 外，加上 `_loadBoards()` 與 `_loadUnread()`

```dart
  Future<void> _loadBoards() async {
    try {
      final boards = await ForumService.boards();
      if (!mounted) return;
      setState(() {
        _boards = boards;
        _boardSlug = boards.isEmpty ? null : boards.first.slug;
        _boardsLoading = false;
      });
    } on ApiException {
      // 看板載不到不應該讓整頁失效，活動小卡仍要顯示。
      if (!mounted) return;
      setState(() => _boardsLoading = false);
    }
  }

  Future<void> _loadUnread() async {
    try {
      final page = await ForumService.notifications();
      if (!mounted) return;
      setState(() => _unread = page.unreadCount);
    } on ApiException {
      // 紅點拿不到就不顯示，不干擾主要內容。
    }
  }
```

- `_buildTabBar()` 改為依 `_boards` 產生橫向捲動的看板 tab，沿用 dcard 的底線樣式：

```dart
  Widget _buildTabBar() => Container(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.creamDeep)),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              for (final board in _boards)
                _BoardTab(
                  label: board.name,
                  selected: board.slug == _boardSlug,
                  onTap: () => setState(() => _boardSlug = board.slug),
                ),
            ],
          ),
        ),
      );
```

`_Tab` 改名為 `_BoardTab`，加上 `selected` 與 `onTap`（樣式沿用原本：選中 `AppColors.primary` 文字 + 2px 底線，未選中 `AppColors.fog`、無底線，`padding: EdgeInsets.only(right: 22)`）。

- `_buildPostsSection()` 改為掛載 `ForumBoardView`：

```dart
  Widget _buildPostsSection() {
    final slug = _boardSlug;
    if (_boardsLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    if (slug == null) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(20, 40, 20, 40),
        child: Text('目前沒有可用的看板', style: TextStyle(color: AppColors.fog)),
      );
    }
    return ForumBoardView(
      key: ValueKey(slug),
      loadPage: ({cursor, after}) =>
          ForumService.posts(slug, cursor: cursor, after: after),
      toggleLike: ForumService.likePost,
      toggleBookmark: ForumService.bookmarkPost,
      // 詳情頁在 Task 8 才建立，此處先留空，Task 8 換成 _openPost。
      onOpenPost: (_) {},
    );
  }
```

- `build()` 的 `CustomScrollView` 改為 `Column`，讓 `ForumBoardView` 內的 `ListView` 能取得有界高度並自行捲動：

```dart
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.creamLight,
        body: Column(
          children: [
            _buildHeader(context),
            if (!_eventsLoading && _events.isNotEmpty) _buildMiniEventCards(),
            _buildTabBar(),
            Expanded(child: _buildPostsSection()),
          ],
        ),
      );
```

- `_buildHeader()` 的「發布」鈕左側加入三個入口（搜尋、書籤、鈴鐺），鈴鐺帶未讀紅點。**本 task 只放版面與紅點，三個 `onPressed` 一律先設為 `null`**——對應畫面分別在 Task 10、Task 12、Task 11 建立，各自的 task 會把導頁補上：

```dart
          IconButton(
            // Task 10 補上導向 ForumSearchScreen
            onPressed: null,
            icon: const Icon(Icons.search, color: AppColors.ink, size: 20),
          ),
          IconButton(
            // Task 12 補上導向 ForumBookmarksScreen
            onPressed: null,
            icon: const Icon(Icons.bookmark_border, color: AppColors.ink, size: 20),
          ),
          IconButton(
            // Task 11 補上導向 ForumNotificationsScreen，返回後呼叫 _loadUnread()
            onPressed: null,
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_none, color: AppColors.ink, size: 20),
                if (_unread > 0)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
```

- 「發布」鈕的 `onTap` 先設為 `null`（外觀不變），Task 9 建立 `ForumComposeScreen` 後再接上。

**本 task 的改動範圍**：看板 tab、`ForumBoardView` 掛載、`build()` 改成 `Column`、標題列版面與未讀紅點、刪除假資料。所有導頁（貼文詳情、發文、搜尋、收藏、通知）一律留到各自的 task，因此本 task 結束時 `plaza_screen.dart` 不需要 import 任何尚未建立的畫面，`flutter analyze` 應乾淨通過。

- [ ] **Step 6: 刪除假資料發文畫面**

```bash
git rm lib/screens/plaza/compose_screen.dart
```

`plaza_screen.dart` 對它的 `import` 與 `ComposeScreen` 用法在 Step 5 已一併移除。

- [ ] **Step 7: 驗證**

Run: `flutter analyze`
Expected: 無 error。

Run: `flutter test`
Expected: 全部通過。

- [ ] **Step 8: Commit**

```bash
git add lib/screens/forum/forum_board_view.dart lib/screens/plaza/plaza_screen.dart test/widgets/forum_board_view_test.dart
git rm --cached lib/screens/plaza/compose_screen.dart 2>/dev/null || true
git commit -m "feat: 廣場頁串接真實論壇看板列表，移除假資料"
```

---

### Task 7: 檢舉 bottom sheet

檢舉在貼文詳情與留言兩處都會用到，先做成獨立元件，Task 8 直接使用。

**Files:**
- Create: `lib/screens/forum/widgets/forum_report_sheet.dart`
- Test: `test/widgets/forum_report_sheet_test.dart`

**Interfaces:**
- Consumes: Task 4 的 `ForumService.report` / `ForumService.reasonMax`
- Produces:
  - `Future<void> showForumReportSheet(BuildContext context, {required String targetType, required int targetId})`

- [ ] **Step 1: 寫失敗的測試**

建立 `test/widgets/forum_report_sheet_test.dart`：

```dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/screens/forum/widgets/forum_report_sheet.dart';

void main() {
  tearDown(() => ApiClient.httpClient = http.Client());

  testWidgets('填寫理由後送出，帶上 target_type 與 target_id', (tester) async {
    Map<String, dynamic>? sent;
    ApiClient.httpClient = MockClient((req) async {
      sent = jsonDecode((req as http.Request).body) as Map<String, dynamic>;
      return http.Response(jsonEncode({'ok': true}), 201);
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showForumReportSheet(
              context,
              targetType: 'comment',
              targetId: 11,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '廣告');
    await tester.tap(find.text('送出檢舉'));
    await tester.pumpAndSettle();

    expect(sent, {'target_type': 'comment', 'target_id': 11, 'reason': '廣告'});
    expect(find.text('已收到檢舉'), findsOneWidget);
  });

  testWidgets('理由留空時送出鈕不可按', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showForumReportSheet(
              context,
              targetType: 'post',
              targetId: 1,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });
}
```

- [ ] **Step 2: 執行測試，確認失敗**

Run: `flutter test test/widgets/forum_report_sheet_test.dart`
Expected: FAIL，`Target of URI doesn't exist: '.../forum_report_sheet.dart'`。

- [ ] **Step 3: 實作**

建立 `lib/screens/forum/widgets/forum_report_sheet.dart`：

```dart
// 檢舉貼文或留言。同一人對同一目標重複檢舉，後端回 201 不視為錯誤
// （規格 §10），因此成功訊息一律是「已收到檢舉」。

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/network/api_client.dart';
import '../../../services/forum_service.dart';

Future<void> showForumReportSheet(
  BuildContext context, {
  required String targetType,
  required int targetId,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.creamLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => _ReportSheet(targetType: targetType, targetId: targetId),
    );

class _ReportSheet extends StatefulWidget {
  final String targetType;
  final int targetId;

  const _ReportSheet({required this.targetType, required this.targetId});

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _sending = true);
    try {
      await ForumService.report(
        targetType: widget.targetType,
        targetId: widget.targetId,
        reason: _controller.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text('已收到檢舉')));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final reason = _controller.text.trim();
    final valid = reason.isNotEmpty && reason.length <= ForumService.reasonMax;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '檢舉',
            style: GoogleFonts.notoSerifTc(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '請說明檢舉的原因，管理員會再確認。',
            style: TextStyle(fontSize: 13, color: AppColors.fog),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            maxLines: 4,
            maxLength: ForumService.reasonMax,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: '例如：廣告、人身攻擊、不實資訊',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: valid && !_sending ? _submit : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.creamLight,
              ),
              child: Text(_sending ? '送出中…' : '送出檢舉'),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: 執行測試，確認通過**

Run: `flutter test test/widgets/forum_report_sheet_test.dart`
Expected: PASS，2 個測試全過。

- [ ] **Step 5: Commit**

```bash
git add lib/screens/forum/widgets/forum_report_sheet.dart test/widgets/forum_report_sheet_test.dart
git commit -m "feat: 新增論壇檢舉 bottom sheet"
```

---

### Task 8: 貼文詳情與兩層留言

**Files:**
- Create: `lib/screens/forum/widgets/forum_comment_tile.dart`
- Create: `lib/screens/forum/forum_detail_screen.dart`
- Modify: `lib/screens/plaza/plaza_screen.dart`（接上 `_openPost`）
- Test: `test/widgets/forum_comment_tile_test.dart`

**Interfaces:**
- Consumes: Task 2 的 `ForumComment` / `ForumCommentThread` / `groupComments`、Task 4 的 `ForumService`、Task 5 的 `ForumImageGrid` / `forumRelativeTime`、Task 7 的 `showForumReportSheet`
- Produces:
  - `ForumCommentTile({required ForumComment comment, required bool isReply, required bool isMine, required VoidCallback onLike, required VoidCallback onReply, required VoidCallback onDelete, required VoidCallback onReport})`
  - `ForumDetailScreen({required int postId})` — `Navigator.pop` 回傳 `true` 代表貼文已被刪除，呼叫端應從列表移除

- [ ] **Step 1: 寫失敗的測試**

建立 `test/widgets/forum_comment_tile_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/forum_models.dart';
import 'package:flutter_application_1/screens/forum/widgets/forum_comment_tile.dart';

ForumComment comment({int likeCount = 0, bool isLiked = false}) => ForumComment(
      id: 5,
      postId: 1,
      parentCommentId: null,
      body: '推一個',
      likeCount: likeCount,
      isLiked: isLiked,
      createdAt: DateTime.now(),
      author: const ForumAuthor(uid: 7, displayName: 'Pisaw'),
    );

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('顯示作者、內容與讚數', (tester) async {
    await tester.pumpWidget(wrap(ForumCommentTile(
      comment: comment(likeCount: 2),
      isReply: false,
      isMine: false,
      onLike: () {},
      onReply: () {},
      onDelete: () {},
      onReport: () {},
    )));

    expect(find.text('Pisaw'), findsOneWidget);
    expect(find.text('推一個'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('自己的留言顯示刪除、別人的顯示檢舉', (tester) async {
    await tester.pumpWidget(wrap(ForumCommentTile(
      comment: comment(),
      isReply: false,
      isMine: true,
      onLike: () {},
      onReply: () {},
      onDelete: () {},
      onReport: () {},
    )));
    expect(find.text('刪除'), findsOneWidget);
    expect(find.text('檢舉'), findsNothing);

    await tester.pumpWidget(wrap(ForumCommentTile(
      comment: comment(),
      isReply: false,
      isMine: false,
      onLike: () {},
      onReply: () {},
      onDelete: () {},
      onReport: () {},
    )));
    expect(find.text('檢舉'), findsOneWidget);
    expect(find.text('刪除'), findsNothing);
  });

  testWidgets('第二層回覆有縮排，第一層沒有', (tester) async {
    await tester.pumpWidget(wrap(ForumCommentTile(
      comment: comment(),
      isReply: true,
      isMine: false,
      onLike: () {},
      onReply: () {},
      onDelete: () {},
      onReport: () {},
    )));

    final padding = tester.widget<Padding>(
      find.byKey(const ValueKey('forum-comment-indent')),
    );
    expect((padding.padding as EdgeInsets).left, greaterThan(0));
  });

  testWidgets('點回覆觸發 onReply', (tester) async {
    var replied = 0;
    await tester.pumpWidget(wrap(ForumCommentTile(
      comment: comment(),
      isReply: false,
      isMine: false,
      onLike: () {},
      onReply: () => replied++,
      onDelete: () {},
      onReport: () {},
    )));

    await tester.tap(find.text('回覆'));
    await tester.pump();

    expect(replied, 1);
  });
}
```

- [ ] **Step 2: 執行測試，確認失敗**

Run: `flutter test test/widgets/forum_comment_tile_test.dart`
Expected: FAIL，`Target of URI doesn't exist: '.../forum_comment_tile.dart'`。

- [ ] **Step 3: 實作留言列**

建立 `lib/screens/forum/widgets/forum_comment_tile.dart`：

```dart
// 單則留言。論壇只有兩層，[isReply] 決定是否縮排，沒有更深的層級。

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../models/forum_models.dart';
import 'forum_post_card.dart' show forumRelativeTime;

class ForumCommentTile extends StatelessWidget {
  final ForumComment comment;
  final bool isReply;
  final bool isMine;
  final VoidCallback onLike;
  final VoidCallback onReply;
  final VoidCallback onDelete;
  final VoidCallback onReport;

  const ForumCommentTile({
    super.key,
    required this.comment,
    required this.isReply,
    required this.isMine,
    required this.onLike,
    required this.onReply,
    required this.onDelete,
    required this.onReport,
  });

  @override
  Widget build(BuildContext context) => Padding(
        key: const ValueKey('forum-comment-indent'),
        padding: EdgeInsets.fromLTRB(isReply ? 34 : 0, 10, 0, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: isReply ? 24 : 30,
                  height: isReply ? 24 : 30,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.moss,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    comment.author.displayName.characters.firstOrNull ?? '?',
                    style: GoogleFonts.notoSerifTc(
                      fontSize: 12,
                      color: AppColors.gold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  comment.author.displayName,
                  style: GoogleFonts.notoSerifTc(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  forumRelativeTime(comment.createdAt),
                  style: const TextStyle(fontSize: 11, color: AppColors.fog),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Padding(
              padding: EdgeInsets.only(left: isReply ? 32 : 38),
              child: Text(
                comment.body,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.inkSoft,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: EdgeInsets.only(left: isReply ? 32 : 38),
              child: Row(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onLike,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          comment.isLiked
                              ? Icons.favorite
                              : Icons.favorite_border,
                          size: 14,
                          color: comment.isLiked
                              ? AppColors.primary
                              : AppColors.fog,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${comment.likeCount}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.fog,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  _action('回覆', onReply),
                  const SizedBox(width: 16),
                  if (isMine) _action('刪除', onDelete) else _action('檢舉', onReport),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _action(String label, VoidCallback onTap) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.fog),
        ),
      );
}
```

- [ ] **Step 4: 執行測試，確認通過**

Run: `flutter test test/widgets/forum_comment_tile_test.dart`
Expected: PASS，4 個測試全過。

- [ ] **Step 5: 實作詳情頁**

建立 `lib/screens/forum/forum_detail_screen.dart`：

```dart
// 貼文詳情 + 兩層留言。
//
// 回覆的層級規則：對第二層回覆按「回覆」時，parent 仍指向它所屬的第一層留言。
// 後端會擋第三層，前端不送出必然失敗的請求。

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../models/forum_models.dart';
import '../../services/forum_service.dart';
import '../../services/user_service.dart';
import 'widgets/forum_comment_tile.dart';
import 'widgets/forum_image_grid.dart';
import 'widgets/forum_post_card.dart' show forumRelativeTime;
import 'widgets/forum_report_sheet.dart';

class ForumDetailScreen extends StatefulWidget {
  final int postId;

  const ForumDetailScreen({super.key, required this.postId});

  @override
  State<ForumDetailScreen> createState() => _ForumDetailScreenState();
}

class _ForumDetailScreenState extends State<ForumDetailScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  ForumPost? _post;
  final List<ForumComment> _comments = [];
  final List<ForumComment> _replies = [];
  int? _nextCursor;
  bool _loading = true;
  bool _sending = false;
  String? _error;

  /// 正在回覆的第一層留言；null 代表回覆貼文本身。
  ForumComment? _replyTarget;

  bool get _isMine => _post?.author.uid == UserService.currentUid;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final post = await ForumService.post(widget.postId);
      final page = await ForumService.comments(widget.postId);
      if (!mounted) return;
      setState(() {
        _post = post;
        _comments
          ..clear()
          ..addAll(page.comments);
        _replies
          ..clear()
          ..addAll(page.replies);
        _nextCursor = page.nextCursor;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'POST_NOT_FOUND') {
        _popDeleted('這篇貼文已被刪除');
        return;
      }
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _loadMoreComments() async {
    final cursor = _nextCursor;
    if (cursor == null) return;
    try {
      final page = await ForumService.comments(widget.postId, cursor: cursor);
      if (!mounted) return;
      setState(() {
        _comments.addAll(page.comments);
        _replies.addAll(page.replies);
        _nextCursor = page.nextCursor;
      });
    } on ApiException catch (e) {
      _toast(e.message);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// 貼文已不存在：回到列表並回報 true，讓呼叫端把它移除。
  void _popDeleted(String message) {
    if (!mounted) return;
    Navigator.pop(context, true);
    _toast(message);
  }

  Future<void> _likePost() async {
    final post = _post;
    if (post == null) return;
    setState(() => _post = post.toggledLike());
    try {
      final result = await ForumService.likePost(post.id, like: !post.isLiked);
      if (!mounted) return;
      setState(() => _post = post.copyWith(
            isLiked: result.liked,
            likeCount: result.likeCount,
          ));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _post = post);
      _toast(e.message);
    }
  }

  Future<void> _likeComment(ForumComment comment) async {
    void replace(ForumComment next) {
      final i = _comments.indexWhere((c) => c.id == next.id);
      if (i >= 0) _comments[i] = next;
      final j = _replies.indexWhere((c) => c.id == next.id);
      if (j >= 0) _replies[j] = next;
    }

    setState(() => replace(comment.toggledLike()));
    try {
      final result = await ForumService.likeComment(
        comment.id,
        like: !comment.isLiked,
      );
      if (!mounted) return;
      setState(() => replace(comment.copyWith(
            isLiked: result.liked,
            likeCount: result.likeCount,
          )));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => replace(comment));
      _toast(e.message);
    }
  }

  Future<void> _send() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || text.length > ForumService.commentMax) return;
    setState(() => _sending = true);
    try {
      final created = await ForumService.createComment(
        widget.postId,
        text,
        parentCommentId: _replyTarget?.id,
      );
      if (!mounted) return;
      setState(() {
        if (created.parentCommentId == null) {
          _comments.add(created);
        } else {
          _replies.add(created);
        }
        final post = _post;
        if (post != null) {
          _post = post.copyWith(commentCount: post.commentCount + 1);
        }
        _inputController.clear();
        _replyTarget = null;
        _sending = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      if (e.code == 'POST_NOT_FOUND') {
        _popDeleted('這篇貼文已被刪除');
        return;
      }
      _toast(e.message);
    }
  }

  Future<void> _deleteComment(ForumComment comment) async {
    final confirmed = await _confirm('刪除這則留言？');
    if (confirmed != true) return;
    try {
      await ForumService.deleteComment(comment.id);
      if (!mounted) return;
      setState(() {
        _comments.removeWhere((c) => c.id == comment.id);
        _replies.removeWhere((c) => c.id == comment.id);
        // 第一層被刪時，掛在它底下的回覆也失去容身之處。
        _replies.removeWhere((c) => c.parentCommentId == comment.id);
        final post = _post;
        if (post != null) {
          _post = post.copyWith(
            commentCount: (post.commentCount - 1).clamp(0, 1 << 31),
          );
        }
      });
    } on ApiException catch (e) {
      if (e.code == 'COMMENT_NOT_FOUND') {
        if (!mounted) return;
        setState(() {
          _comments.removeWhere((c) => c.id == comment.id);
          _replies.removeWhere((c) => c.id == comment.id);
        });
        return;
      }
      _toast(e.message);
    }
  }

  Future<void> _deletePost() async {
    final confirmed = await _confirm('刪除這篇貼文？');
    if (confirmed != true) return;
    try {
      await ForumService.deletePost(widget.postId);
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      _toast(e.message);
    }
  }

  Future<bool?> _confirm(String message) => showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('刪除'),
            ),
          ],
        ),
      );

  // 編輯（_edit）在 Task 9 建立 ForumComposeScreen 後補上。

  @override
  Widget build(BuildContext context) {
    final post = _post;
    return Scaffold(
      backgroundColor: AppColors.creamLight,
      appBar: AppBar(
        backgroundColor: AppColors.creamLight,
        elevation: 0,
        foregroundColor: AppColors.ink,
        title: Text(
          '貼文',
          style: GoogleFonts.notoSerifTc(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
        actions: [
          if (post != null)
            PopupMenuButton<String>(
              onSelected: (value) {
                // 'edit' 由 Task 9 加入
                if (value == 'delete') _deletePost();
                if (value == 'report') {
                  showForumReportSheet(
                    context,
                    targetType: 'post',
                    targetId: post.id,
                  );
                }
              },
              itemBuilder: (_) => _isMine
                  ? const [
                      // Task 9 在此加入 PopupMenuItem(value: 'edit', child: Text('編輯'))
                      PopupMenuItem(value: 'delete', child: Text('刪除')),
                    ]
                  : const [
                      PopupMenuItem(value: 'report', child: Text('檢舉')),
                    ],
            ),
        ],
      ),
      body: _buildBody(post),
    );
  }

  Widget _buildBody(ForumPost? post) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    final error = _error;
    if (error != null || post == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(error ?? '載入失敗', style: const TextStyle(color: AppColors.inkSoft)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('重試')),
          ],
        ),
      );
    }

    final threads = groupComments(_comments, _replies);
    return Column(
      children: [
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.metrics.pixels >= n.metrics.maxScrollExtent - 200) {
                _loadMoreComments();
              }
              return false;
            },
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              children: [
                _postBody(post),
                const Divider(color: AppColors.creamDeep, height: 28),
                Text(
                  '留言 ${post.commentCount}',
                  style: GoogleFonts.notoSerifTc(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                if (threads.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      '還沒有人留言，來說第一句吧。',
                      style: TextStyle(color: AppColors.fog),
                    ),
                  ),
                for (final thread in threads) ...[
                  ForumCommentTile(
                    comment: thread.root,
                    isReply: false,
                    isMine: thread.root.author.uid == UserService.currentUid,
                    onLike: () => _likeComment(thread.root),
                    onReply: () => setState(() => _replyTarget = thread.root),
                    onDelete: () => _deleteComment(thread.root),
                    onReport: () => showForumReportSheet(
                      context,
                      targetType: 'comment',
                      targetId: thread.root.id,
                    ),
                  ),
                  for (final reply in thread.replies)
                    ForumCommentTile(
                      comment: reply,
                      isReply: true,
                      isMine: reply.author.uid == UserService.currentUid,
                      onLike: () => _likeComment(reply),
                      // 論壇只有兩層：回覆「回覆」時，parent 仍是第一層那則。
                      onReply: () => setState(() => _replyTarget = thread.root),
                      onDelete: () => _deleteComment(reply),
                      onReport: () => showForumReportSheet(
                        context,
                        targetType: 'comment',
                        targetId: reply.id,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
        _inputBar(),
      ],
    );
  }

  Widget _postBody(ForumPost post) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            post.title,
            style: GoogleFonts.notoSerifTc(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${post.author.displayName} · ${post.board.name} · '
            '${forumRelativeTime(post.createdAt)}',
            style: const TextStyle(fontSize: 12, color: AppColors.fog),
          ),
          const SizedBox(height: 14),
          Text(
            post.body,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.inkSoft,
              height: 1.7,
            ),
          ),
          if (post.images.isNotEmpty) ...[
            const SizedBox(height: 14),
            ForumImageGrid(urls: post.images),
          ],
          if (post.tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              children: [
                for (final tag in post.tags)
                  Text(
                    '#${tag.name}',
                    style: GoogleFonts.crimsonPro(
                      fontStyle: FontStyle.italic,
                      fontSize: 12,
                      color: AppColors.primary,
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _likePost,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  post.isLiked ? Icons.favorite : Icons.favorite_border,
                  size: 18,
                  color: post.isLiked ? AppColors.primary : AppColors.fog,
                ),
                const SizedBox(width: 6),
                Text(
                  '${post.likeCount}',
                  style: const TextStyle(fontSize: 13, color: AppColors.fog),
                ),
              ],
            ),
          ),
        ],
      );

  Widget _inputBar() {
    final target = _replyTarget;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cream,
        border: Border(top: BorderSide(color: AppColors.creamDeep)),
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        8 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (target != null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    '回覆 @${target.author.displayName}',
                    style: const TextStyle(fontSize: 12, color: AppColors.fog),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _replyTarget = null),
                  child: const Icon(Icons.close, size: 16, color: AppColors.fog),
                ),
              ],
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inputController,
                  maxLength: ForumService.commentMax,
                  minLines: 1,
                  maxLines: 4,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: '說點什麼…',
                    counterText: '',
                    border: InputBorder.none,
                  ),
                ),
              ),
              IconButton(
                onPressed: _sending || _inputController.text.trim().isEmpty
                    ? null
                    : _send,
                icon: const Icon(Icons.send, color: AppColors.primary, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 6: 接上廣場頁的開啟貼文**

在 `lib/screens/plaza/plaza_screen.dart` 加入 `import '../forum/forum_detail_screen.dart';`，並實作：

```dart
  Future<void> _openPost(ForumPost post) async {
    final deleted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ForumDetailScreen(postId: post.id)),
    );
    if (deleted == true) _boardViewKey.currentState?.removePost(post.id);
  }
```

並把 `_buildPostsSection()` 內 `ForumBoardView` 的 `key:` 改為 `_boardViewKey`（原本是 `ValueKey(slug)`；改為同時需要兩者時，把 `ForumBoardView` 包在 `KeyedSubtree(key: ValueKey(slug), child: ForumBoardView(key: _boardViewKey, ...))`，讓切換看板仍會重建，而 `_boardViewKey` 保持可用）。

- [ ] **Step 7: 驗證**

Run: `flutter test`
Expected: 全部通過。

Run: `flutter analyze`
Expected: 無 error。編輯功能（`_edit()`、選單的「編輯」項、`forum_compose_screen.dart` 的 import）刻意留到 Task 9，本 task 不引用尚未存在的畫面。

- [ ] **Step 8: Commit**

```bash
git add lib/screens/forum/forum_detail_screen.dart lib/screens/forum/widgets/forum_comment_tile.dart lib/screens/plaza/plaza_screen.dart test/widgets/forum_comment_tile_test.dart
git commit -m "feat: 新增論壇貼文詳情與兩層留言"
```

---

### Task 9: 發文與編輯

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/screens/forum/forum_compose_screen.dart`
- Modify: `lib/screens/plaza/plaza_screen.dart`（「發布」鈕接上發文）
- Modify: `lib/screens/forum/forum_detail_screen.dart`（補上 `_edit()` 與 import）
- Test: `test/widgets/forum_compose_validation_test.dart`

**Interfaces:**
- Consumes: Task 2 的 `ForumBoard` / `ForumPost`、Task 4 的 `ForumService` 與其限制常數、Task 1 的 `MultipartFileData`
- Produces:
  - `ForumComposeScreen({required List<ForumBoard> boards, ForumPost? editing})` — `Navigator.pop` 回傳 `true` 代表有成功建立或更新
  - `String? forumComposeError({required int? boardId, required String title, required String body, required List<String> tags})` — 純函式，回傳第一個違反後端限制的錯誤訊息，全部通過回 `null`

驗證抽成純函式的理由：規則來自後端的硬性限制，逐條都要測，而拉起整個畫面去測字數上限既慢又脆。

- [ ] **Step 1: 加入選圖與壓縮依賴**

編輯 `pubspec.yaml`，在 `cached_network_image: ^3.4.1` 之後加入：

```yaml
  image_picker: ^1.1.2 # 論壇發文選圖／拍照
  flutter_image_compress: ^2.3.0 # 上傳前壓縮（後端不做伺服器端壓縮）
```

Run: `flutter pub get`
Expected: `Got dependencies!`

- [ ] **Step 2: 寫失敗的測試**

建立 `test/widgets/forum_compose_validation_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/screens/forum/forum_compose_screen.dart';

void main() {
  String? check({
    int? boardId = 1,
    String title = '標題',
    String body = '內文',
    List<String> tags = const [],
  }) =>
      forumComposeError(
        boardId: boardId,
        title: title,
        body: body,
        tags: tags,
      );

  test('全部合法時回傳 null', () {
    expect(check(), isNull);
  });

  test('沒選看板', () {
    expect(check(boardId: null), '請選擇看板');
  });

  test('標題空白或只有空格', () {
    expect(check(title: '   '), '請填寫標題');
  });

  test('標題超過 120 字', () {
    expect(check(title: 'a' * 121), '標題不能超過 120 字');
  });

  test('內文空白', () {
    expect(check(body: ''), '請填寫內文');
  });

  test('內文超過 5000 字', () {
    expect(check(body: 'a' * 5001), '內文不能超過 5000 字');
  });

  test('標籤超過 5 個', () {
    expect(check(tags: ['1', '2', '3', '4', '5', '6']), '標籤最多 5 個');
  });

  test('單一標籤超過 20 字', () {
    expect(check(tags: ['a' * 21]), '每個標籤不能超過 20 字');
  });
}
```

- [ ] **Step 3: 執行測試，確認失敗**

Run: `flutter test test/widgets/forum_compose_validation_test.dart`
Expected: FAIL，`Target of URI doesn't exist: '.../forum_compose_screen.dart'`。

- [ ] **Step 4: 實作發文畫面**

建立 `lib/screens/forum/forum_compose_screen.dart`：

```dart
// 發文 / 編輯。排版沿用 feature/forum-dcard 的結構：看板 segment、標題、內文、
// 底部工具列。
//
// 編輯模式只送文字欄位：後端 PATCH /forum/posts/:id 不處理附圖，所以編輯時
// 附圖區唯讀——讓使用者以為改得動但實際沒生效，比不給改更糟。

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../models/forum_models.dart';
import '../../services/forum_service.dart';

/// 依後端硬性限制檢查，回傳第一個錯誤訊息；全部通過回 null。
String? forumComposeError({
  required int? boardId,
  required String title,
  required String body,
  required List<String> tags,
}) {
  if (boardId == null) return '請選擇看板';
  if (title.trim().isEmpty) return '請填寫標題';
  if (title.trim().length > ForumService.titleMax) {
    return '標題不能超過 ${ForumService.titleMax} 字';
  }
  if (body.trim().isEmpty) return '請填寫內文';
  if (body.trim().length > ForumService.bodyMax) {
    return '內文不能超過 ${ForumService.bodyMax} 字';
  }
  if (tags.length > ForumService.tagMaxCount) {
    return '標籤最多 ${ForumService.tagMaxCount} 個';
  }
  if (tags.any((t) => t.length > ForumService.tagNameMax)) {
    return '每個標籤不能超過 ${ForumService.tagNameMax} 字';
  }
  return null;
}

class ForumComposeScreen extends StatefulWidget {
  final List<ForumBoard> boards;
  final ForumPost? editing;

  const ForumComposeScreen({super.key, required this.boards, this.editing});

  @override
  State<ForumComposeScreen> createState() => _ForumComposeScreenState();
}

class _PickedImage {
  final Uint8List bytes;
  final String filename;

  const _PickedImage({required this.bytes, required this.filename});
}

class _ForumComposeScreenState extends State<ForumComposeScreen> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _tagController = TextEditingController();
  final List<String> _tags = [];
  final List<_PickedImage> _images = [];

  int? _boardId;
  bool _saving = false;
  List<ForumTagStat> _hotTags = [];

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final editing = widget.editing;
    if (editing != null) {
      _titleController.text = editing.title;
      _bodyController.text = editing.body;
      _tags.addAll(editing.tags.map((t) => t.name));
      _boardId = editing.board.id;
    } else {
      _boardId = widget.boards.isEmpty ? null : widget.boards.first.id;
    }
    _loadHotTags();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _loadHotTags() async {
    try {
      final tags = await ForumService.tags();
      if (!mounted) return;
      setState(() => _hotTags = tags.take(10).toList());
    } on ApiException {
      // 熱門標籤只是輔助輸入，拿不到就不顯示。
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickImages() async {
    if (_images.length >= ForumService.imageMaxCount) {
      _toast('最多只能附 ${ForumService.imageMaxCount} 張圖');
      return;
    }
    final picked = await ImagePicker().pickMultiImage(limit: ForumService.imageMaxCount - _images.length);
    if (picked.isEmpty) return;

    for (final file in picked) {
      // 後端不做伺服器端壓縮，且限制單張 5 MB，所以壓縮必須在這裡完成。
      final compressed = await FlutterImageCompress.compressWithFile(
        file.path,
        minWidth: 1920,
        minHeight: 1920,
        quality: 85,
        format: CompressFormat.jpeg,
      );
      if (compressed == null) {
        _toast('無法處理 ${file.name}，請換一張');
        continue;
      }
      if (compressed.length > ForumService.imageMaxBytes) {
        _toast('${file.name} 壓縮後仍超過 5 MB，請換一張較小的圖');
        continue;
      }
      if (!mounted) return;
      setState(() => _images.add(_PickedImage(
            bytes: compressed,
            // 一律轉成 JPEG，副檔名跟著改，避免與 Content-Type 不一致。
            filename: '${DateTime.now().microsecondsSinceEpoch}.jpg',
          )));
      if (_images.length >= ForumService.imageMaxCount) break;
    }
  }

  void _addTag() {
    final name = _tagController.text.trim();
    if (name.isEmpty) return;
    if (_tags.contains(name)) {
      _tagController.clear();
      return;
    }
    if (_tags.length >= ForumService.tagMaxCount) {
      _toast('標籤最多 ${ForumService.tagMaxCount} 個');
      return;
    }
    setState(() {
      _tags.add(name);
      _tagController.clear();
    });
  }

  Future<void> _save() async {
    final error = forumComposeError(
      boardId: _boardId,
      title: _titleController.text,
      body: _bodyController.text,
      tags: _tags,
    );
    if (error != null) {
      _toast(error);
      return;
    }

    setState(() => _saving = true);
    try {
      final editing = widget.editing;
      if (editing != null) {
        await ForumService.updatePost(
          editing.id,
          title: _titleController.text.trim(),
          body: _bodyController.text.trim(),
          tags: _tags,
        );
      } else {
        await ForumService.createPost(
          boardId: _boardId!,
          title: _titleController.text.trim(),
          body: _bodyController.text.trim(),
          tags: _tags,
          images: [
            for (final image in _images)
              MultipartFileData(
                field: 'images',
                bytes: image.bytes,
                filename: image.filename,
                mimeType: 'image/jpeg',
              ),
          ],
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast(e.message);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.creamLight,
        appBar: AppBar(
          backgroundColor: AppColors.creamLight,
          elevation: 0,
          foregroundColor: AppColors.ink,
          title: Text(
            _isEditing ? '編輯貼文' : '發文',
            style: GoogleFonts.notoSerifTc(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          actions: [
            TextButton(
              onPressed: _saving ? null : _save,
              child: Text(
                _saving ? '送出中…' : '送出',
                style: const TextStyle(color: AppColors.primary),
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            _boardSegment(),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              maxLength: ForumService.titleMax,
              onChanged: (_) => setState(() {}),
              style: GoogleFonts.notoSerifTc(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
              decoration: const InputDecoration(
                hintText: '標題',
                border: InputBorder.none,
              ),
            ),
            const Divider(color: AppColors.creamDeep),
            TextField(
              controller: _bodyController,
              maxLength: ForumService.bodyMax,
              minLines: 8,
              maxLines: null,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: '想說的話…',
                border: InputBorder.none,
              ),
            ),
            const SizedBox(height: 12),
            _tagSection(),
            const SizedBox(height: 16),
            _imageSection(),
          ],
        ),
      );

  Widget _boardSegment() => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final board in widget.boards)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  // 編輯模式不能換看板：後端 PATCH 不接受 board_id。
                  onTap: _isEditing
                      ? null
                      : () => setState(() => _boardId = board.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: board.id == _boardId
                          ? AppColors.primary
                          : AppColors.cream,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.creamDeep),
                    ),
                    child: Text(
                      board.name,
                      style: GoogleFonts.notoSerifTc(
                        fontSize: 13,
                        color: board.id == _boardId
                            ? AppColors.creamLight
                            : AppColors.inkSoft,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );

  Widget _tagSection() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tagController,
                  maxLength: ForumService.tagNameMax,
                  onSubmitted: (_) => _addTag(),
                  decoration: const InputDecoration(
                    hintText: '加入標籤',
                    counterText: '',
                    isDense: true,
                  ),
                ),
              ),
              TextButton(onPressed: _addTag, child: const Text('加入')),
            ],
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final tag in _tags)
                Chip(
                  label: Text('#$tag'),
                  onDeleted: () => setState(() => _tags.remove(tag)),
                  backgroundColor: AppColors.cream,
                ),
            ],
          ),
          if (_hotTags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'HOT · 熱門標籤',
              style: GoogleFonts.crimsonPro(
                fontStyle: FontStyle.italic,
                fontSize: 10,
                color: AppColors.fog,
                letterSpacing: 3.0,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final stat in _hotTags)
                  ActionChip(
                    label: Text('#${stat.tag.name}'),
                    backgroundColor: AppColors.cream,
                    onPressed: () {
                      _tagController.text = stat.tag.name;
                      _addTag();
                    },
                  ),
              ],
            ),
          ],
        ],
      );

  Widget _imageSection() {
    if (_isEditing) {
      final images = widget.editing!.images;
      if (images.isEmpty) return const SizedBox.shrink();
      return const Text(
        '附圖無法在編輯時變更',
        style: TextStyle(fontSize: 12, color: AppColors.fog),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _pickImages,
              icon: const Icon(Icons.image_outlined, size: 18),
              label: Text('加入圖片（${_images.length}/${ForumService.imageMaxCount}）'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.creamDeep),
              ),
            ),
          ],
        ),
        if (_images.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 88,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _images.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      _images[i].bytes,
                      width: 88,
                      height: 88,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    right: 2,
                    top: 2,
                    child: GestureDetector(
                      onTap: () => setState(() => _images.removeAt(i)),
                      child: const CircleAvatar(
                        radius: 10,
                        backgroundColor: AppColors.ink,
                        child: Icon(
                          Icons.close,
                          size: 12,
                          color: AppColors.creamLight,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
```

- [ ] **Step 5: 執行測試，確認通過**

Run: `flutter test test/widgets/forum_compose_validation_test.dart`
Expected: PASS，8 個測試全過。

- [ ] **Step 6: 接上廣場頁的「發布」鈕**

在 `lib/screens/plaza/plaza_screen.dart` 加入 `import '../forum/forum_compose_screen.dart';`，把「發布」鈕的 `onTap` 改為：

```dart
            onTap: _boards.isEmpty
                ? null
                : () async {
                    final created = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ForumComposeScreen(boards: _boards),
                      ),
                    );
                    if (created == true) {
                      _boardViewKey.currentState?.refresh();
                    }
                  },
```

- [ ] **Step 7: 補上詳情頁的編輯**

在 `lib/screens/forum/forum_detail_screen.dart` 加入 `import 'forum_compose_screen.dart';`，加入 `_edit()`：

```dart
  Future<void> _edit() async {
    final post = _post;
    if (post == null) return;
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ForumComposeScreen(boards: [post.board], editing: post),
      ),
    );
    if (updated == true && mounted) _load();
  }
```

把 `PopupMenuButton` 的 `onSelected` 補上 `if (value == 'edit') _edit();`，並在 `_isMine` 的選單項最前面加回 `PopupMenuItem(value: 'edit', child: Text('編輯'))`。

- [ ] **Step 8: 驗證**

Run: `flutter analyze`
Expected: 無 error。

Run: `flutter test`
Expected: 全部通過。

- [ ] **Step 9: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/screens/forum/forum_compose_screen.dart lib/screens/forum/forum_detail_screen.dart lib/screens/plaza/plaza_screen.dart test/widgets/forum_compose_validation_test.dart
git commit -m "feat: 新增論壇發文與編輯，附圖上傳前於 App 端壓縮"
```

---

### Task 10: 關鍵字搜尋

**Files:**
- Create: `lib/screens/forum/forum_search_screen.dart`
- Modify: `lib/screens/plaza/plaza_screen.dart`（搜尋 icon 接上導頁）
- Test: `test/widgets/forum_search_screen_test.dart`

**Interfaces:**
- Consumes: Task 4 的 `ForumService.search` 與 `searchMin` / `searchMax`、Task 5 的 `ForumPostCard`、Task 6 的 `ForumBoardView`
- Produces: `ForumSearchScreen({List<ForumBoard> boards = const []})`

搜尋結果重複使用 `ForumBoardView`：它已經有分頁、空狀態、錯誤重試與樂觀更新。差別只在 `loadPage` 換成搜尋，且搜尋沒有置頂與下拉刷新語意（`after` 傳入時直接回空頁）。

- [ ] **Step 1: 寫失敗的測試**

建立 `test/widgets/forum_search_screen_test.dart`：

```dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/screens/forum/forum_search_screen.dart';

void main() {
  tearDown(() => ApiClient.httpClient = http.Client());

  testWidgets('關鍵字未達 2 字時不送出請求', (tester) async {
    var calls = 0;
    ApiClient.httpClient = MockClient((_) async {
      calls++;
      return http.Response(jsonEncode({'posts': [], 'next_cursor': null}), 200);
    });

    await tester.pumpWidget(const MaterialApp(home: ForumSearchScreen()));
    await tester.enterText(find.byType(TextField), '族');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(calls, 0);
    expect(find.text('請輸入 2-80 字的關鍵字'), findsOneWidget);
  });

  testWidgets('送出搜尋後顯示結果', (tester) async {
    ApiClient.httpClient = MockClient((req) async {
      expect(req.url.queryParameters['q'], '族語');
      return http.Response(
        jsonEncode({
          'posts': [
            {
              'id': 1,
              'board': {'id': 2, 'slug': 'culture', 'name': '文化傳承'},
              'title': '族語學習心得',
              'body': '內文',
              'like_count': 0,
              'comment_count': 0,
              'is_pinned': false,
              'is_liked': false,
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

    await tester.pumpWidget(const MaterialApp(home: ForumSearchScreen()));
    await tester.enterText(find.byType(TextField), '族語');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('族語學習心得'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 執行測試，確認失敗**

Run: `flutter test test/widgets/forum_search_screen_test.dart`
Expected: FAIL，`Target of URI doesn't exist: '.../forum_search_screen.dart'`。

- [ ] **Step 3: 實作**

建立 `lib/screens/forum/forum_search_screen.dart`：

```dart
// 關鍵字搜尋。
//
// 後端用 pg_trgm 做子字串比對，沒有相關度排序，結果依 id 遞減，
// 所以介面不宣稱「最相關」，只說「搜尋結果」。

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../models/forum_models.dart';
import '../../services/forum_service.dart';
import 'forum_board_view.dart';
import 'forum_detail_screen.dart';

class ForumSearchScreen extends StatefulWidget {
  final List<ForumBoard> boards;

  const ForumSearchScreen({super.key, this.boards = const []});

  @override
  State<ForumSearchScreen> createState() => _ForumSearchScreenState();
}

class _ForumSearchScreenState extends State<ForumSearchScreen> {
  final _controller = TextEditingController();
  String? _query;
  String? _boardSlug;
  String? _hint;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.length < ForumService.searchMin ||
        text.length > ForumService.searchMax) {
      setState(() {
        _hint = '請輸入 ${ForumService.searchMin}-${ForumService.searchMax} 字的關鍵字';
        _query = null;
      });
      return;
    }
    setState(() {
      _hint = null;
      _query = text;
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = _query;
    return Scaffold(
      backgroundColor: AppColors.creamLight,
      appBar: AppBar(
        backgroundColor: AppColors.creamLight,
        elevation: 0,
        foregroundColor: AppColors.ink,
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _submit(),
          decoration: const InputDecoration(
            hintText: '搜尋貼文',
            border: InputBorder.none,
          ),
        ),
        actions: [
          IconButton(onPressed: _submit, icon: const Icon(Icons.search)),
        ],
      ),
      body: Column(
        children: [
          if (widget.boards.isNotEmpty) _boardFilter(),
          if (_hint != null)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                _hint!,
                style: const TextStyle(color: AppColors.fog),
              ),
            ),
          if (query == null && _hint == null)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Text(
                '輸入關鍵字開始搜尋',
                style: GoogleFonts.notoSerifTc(color: AppColors.fog),
              ),
            ),
          if (query != null)
            Expanded(
              child: ForumBoardView(
                key: ValueKey('$query|$_boardSlug'),
                emptyMessage: '找不到符合的貼文',
                loadPage: ({cursor, after}) async {
                  // 搜尋沒有下拉刷新語意，after 直接回空頁。
                  if (after != null) {
                    return const ForumPostPage(
                      pinned: [],
                      posts: [],
                      nextCursor: null,
                    );
                  }
                  return ForumService.search(
                    query,
                    board: _boardSlug,
                    cursor: cursor,
                  );
                },
                toggleLike: ForumService.likePost,
                toggleBookmark: ForumService.bookmarkPost,
                onOpenPost: (post) => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ForumDetailScreen(postId: post.id),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _boardFilter() => SizedBox(
        height: 48,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            _chip('全部看板', null),
            for (final board in widget.boards) _chip(board.name, board.slug),
          ],
        ),
      );

  Widget _chip(String label, String? slug) => Padding(
        padding: const EdgeInsets.only(right: 8, top: 6, bottom: 6),
        child: ChoiceChip(
          label: Text(label),
          selected: _boardSlug == slug,
          backgroundColor: AppColors.cream,
          selectedColor: AppColors.primary.withValues(alpha: 0.12),
          onSelected: (_) => setState(() => _boardSlug = slug),
        ),
      );
}
```

`ForumPostPage` 需要 `const` 建構子；Task 2 已將所有欄位定義為 `final` 且建構子為 `const`，若 analyzer 抱怨，確認 `ForumPostPage` 的建構子有 `const`。

- [ ] **Step 4: 執行測試，確認通過**

Run: `flutter test test/widgets/forum_search_screen_test.dart`
Expected: PASS，2 個測試全過。

- [ ] **Step 5: 接上廣場頁的搜尋 icon**

在 `lib/screens/plaza/plaza_screen.dart` 加入 `import '../forum/forum_search_screen.dart';`，把搜尋 `IconButton` 的 `onPressed` 改為：

```dart
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ForumSearchScreen(boards: _boards),
              ),
            ),
```

- [ ] **Step 6: 驗證與 Commit**

Run: `flutter analyze` → 無 error
Run: `flutter test` → 全部通過

```bash
git add lib/screens/forum/forum_search_screen.dart lib/screens/plaza/plaza_screen.dart test/widgets/forum_search_screen_test.dart
git commit -m "feat: 新增論壇關鍵字搜尋"
```

---

### Task 11: 通知中心與 FCM 導頁

**Files:**
- Create: `lib/screens/forum/forum_notifications_screen.dart`
- Modify: `lib/services/fcm_service.dart`
- Modify: `lib/main.dart`（掛上論壇通知的導頁 callback）
- Modify: `lib/screens/plaza/plaza_screen.dart`（鈴鐺接上導頁與紅點）
- Test: `test/widgets/forum_notifications_screen_test.dart`

**Interfaces:**
- Consumes: Task 2 的 `ForumNotification` / `ForumNotificationPage`、Task 4 的 `ForumService.notifications` / `markRead`、Task 8 的 `ForumDetailScreen`
- Produces:
  - `ForumNotificationsScreen()`
  - `FcmService.onForumReplyTapped`（`void Function(int postId)?`）

- [ ] **Step 1: 寫失敗的測試**

建立 `test/widgets/forum_notifications_screen_test.dart`：

```dart
import 'dart:convert';
import 'package:flutter/material.dart';
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
  tearDown(() => ApiClient.httpClient = http.Client());

  testWidgets('顯示通知，內容包含回覆者與貼文標題', (tester) async {
    ApiClient.httpClient = MockClient((_) async => http.Response(
          jsonEncode({
            'notifications': [notification(id: 3, isRead: false)],
            'unread_count': 1,
            'next_cursor': null,
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ));

    await tester.pumpWidget(const MaterialApp(home: ForumNotificationsScreen()));
    await tester.pumpAndSettle();

    expect(find.textContaining('Pisaw'), findsOneWidget);
    expect(find.textContaining('關於 mhuway'), findsOneWidget);
  });

  testWidgets('沒有通知時顯示空狀態', (tester) async {
    ApiClient.httpClient = MockClient((_) async => http.Response(
          jsonEncode({
            'notifications': [],
            'unread_count': 0,
            'next_cursor': null,
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ));

    await tester.pumpWidget(const MaterialApp(home: ForumNotificationsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('還沒有新的回覆'), findsOneWidget);
  });

  testWidgets('點「全部已讀」送出不帶 ids 的請求', (tester) async {
    String? sentPath;
    Map<String, dynamic>? sentBody;
    ApiClient.httpClient = MockClient((req) async {
      if (req.method == 'POST') {
        sentPath = req.url.path;
        sentBody = jsonDecode((req as http.Request).body) as Map<String, dynamic>;
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

    await tester.pumpWidget(const MaterialApp(home: ForumNotificationsScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('全部已讀'));
    await tester.pumpAndSettle();

    expect(sentPath, '/api/forum/notifications/read');
    expect(sentBody, <String, dynamic>{});
  });
}
```

- [ ] **Step 2: 執行測試，確認失敗**

Run: `flutter test test/widgets/forum_notifications_screen_test.dart`
Expected: FAIL，`Target of URI doesn't exist: '.../forum_notifications_screen.dart'`。

- [ ] **Step 3: 實作通知中心**

建立 `lib/screens/forum/forum_notifications_screen.dart`：

```dart
// 通知中心。只有「有人回覆你的貼文／留言」兩種類型（後端 forum_notifications.type）。

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../models/forum_models.dart';
import '../../services/forum_service.dart';
import 'forum_detail_screen.dart';
import 'widgets/forum_post_card.dart' show forumRelativeTime;

class ForumNotificationsScreen extends StatefulWidget {
  const ForumNotificationsScreen({super.key});

  @override
  State<ForumNotificationsScreen> createState() =>
      _ForumNotificationsScreenState();
}

class _ForumNotificationsScreenState extends State<ForumNotificationsScreen> {
  final _scrollController = ScrollController();
  final List<ForumNotification> _items = [];
  int? _nextCursor;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) _loadMore();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await ForumService.notifications();
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(page.items);
        _nextCursor = page.nextCursor;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    final cursor = _nextCursor;
    if (_loadingMore || cursor == null) return;
    setState(() => _loadingMore = true);
    try {
      final page = await ForumService.notifications(cursor: cursor);
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _nextCursor = page.nextCursor;
        _loadingMore = false;
      });
    } on ApiException {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  Future<void> _markAllRead() async {
    try {
      await ForumService.markRead();
      if (!mounted) return;
      setState(() {
        for (var i = 0; i < _items.length; i++) {
          final item = _items[i];
          _items[i] = ForumNotification(
            id: item.id,
            type: item.type,
            postId: item.postId,
            commentId: item.commentId,
            postTitle: item.postTitle,
            isRead: true,
            createdAt: item.createdAt,
            actor: item.actor,
          );
        }
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _open(ForumNotification item) async {
    final postId = item.postId;
    if (!item.isRead) {
      // 標記失敗不該擋住導頁，紅點下次進來會再對齊。
      ForumService.markRead(ids: [item.id]).catchError((_) {});
    }
    if (postId == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ForumDetailScreen(postId: postId)),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.creamLight,
        appBar: AppBar(
          backgroundColor: AppColors.creamLight,
          elevation: 0,
          foregroundColor: AppColors.ink,
          title: Text(
            '通知',
            style: GoogleFonts.notoSerifTc(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          actions: [
            TextButton(
              onPressed: _items.isEmpty ? null : _markAllRead,
              child: const Text(
                '全部已讀',
                style: TextStyle(color: AppColors.primary),
              ),
            ),
          ],
        ),
        body: _buildBody(),
      );

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    final error = _error;
    if (error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(error, style: const TextStyle(color: AppColors.inkSoft)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('重試')),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Text(
          '還沒有新的回覆',
          style: GoogleFonts.notoSerifTc(color: AppColors.fog),
        ),
      );
    }
    return ListView.separated(
      controller: _scrollController,
      itemCount: _items.length + (_loadingMore ? 1 : 0),
      separatorBuilder: (_, _) =>
          const Divider(height: 1, color: AppColors.creamDeep),
      itemBuilder: (_, i) {
        if (i >= _items.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
            ),
          );
        }
        final item = _items[i];
        final action =
            item.type == 'reply_post' ? '回覆了你的貼文' : '回覆了你的留言';
        return Container(
          color: item.isRead ? null : AppColors.cream,
          child: ListTile(
            onTap: () => _open(item),
            title: Text(
              '${item.actor.displayName} $action',
              style: GoogleFonts.notoSerifTc(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
            subtitle: Text(
              '${item.postTitle ?? '（貼文已刪除）'} · '
              '${forumRelativeTime(item.createdAt)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColors.fog),
            ),
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 4: 執行測試，確認通過**

Run: `flutter test test/widgets/forum_notifications_screen_test.dart`
Expected: PASS，3 個測試全過。

- [ ] **Step 5: FCM 支援論壇回覆通知**

在 `lib/services/fcm_service.dart` 做四處修改。

其一，在 `onReminderReceivedForOpenScreen` 宣告之後加入：

```dart
  /// 點擊論壇回覆通知時的導頁 callback。由 UI 層設定（用 navigatorKey 導到貼文詳情）。
  static void Function(int postId)? onForumReplyTapped;
```

其二，新增論壇通知的 payload 解析。在 `_parseReminderPayload` 之後加入：

```dart
  /// 解析論壇回覆通知的 payload，非論壇類型回傳 null。
  /// 後端送出的 data：{ type: 'reply_post' | 'reply_comment', post_id, comment_id }
  static int? _parseForumPayload(Map<String, dynamic> data) {
    final type = data['type'];
    if (type != 'reply_post' && type != 'reply_comment') return null;
    final postId = int.tryParse(data['post_id']?.toString() ?? '');
    if (postId == null) {
      debugPrint('FcmService: post_id 缺失或無法解析，忽略：${data['post_id']}');
    }
    return postId;
  }
```

其三，讓前景與點擊都認得論壇通知。`_onForegroundMessage` 開頭改為：

```dart
  static void _onForegroundMessage(RemoteMessage message) {
    final forumPostId = _parseForumPayload(message.data);
    if (forumPostId != null) {
      final title = message.notification?.title ?? '有人回覆你';
      final body = message.notification?.body ?? '';
      unawaited(_localNotifications.show(
        message.hashCode,
        title,
        body,
        const NotificationDetails(android: _reminderAndroidDetails),
        // 事件通知的 payload 是純數字的 event_id，論壇加前綴區分兩者。
        payload: 'forum:$forumPostId',
      ));
      scaffoldMessengerKey.currentState
        ?..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: Text(body.isNotEmpty ? body : title),
          action: SnackBarAction(
            label: '查看',
            onPressed: () => onForumReplyTapped?.call(forumPostId),
          ),
        ));
      return;
    }

    final parsed = _parseReminderPayload(message.data);
    // …以下維持原本的活動提醒邏輯不變
```

`_handleOpened` 開頭加入：

```dart
  static void _handleOpened(RemoteMessage message) {
    final forumPostId = _parseForumPayload(message.data);
    if (forumPostId != null) {
      onForumReplyTapped?.call(forumPostId);
      return;
    }
    final parsed = _parseReminderPayload(message.data);
    // …以下維持不變
```

其四，本機通知的點擊回呼要能分辨兩種 payload。把 `_initLocalNotifications` 的 `onDidReceiveNotificationResponse` 改為：

```dart
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload ?? '';
        if (payload.startsWith('forum:')) {
          final postId = int.tryParse(payload.substring('forum:'.length));
          if (postId != null) onForumReplyTapped?.call(postId);
          return;
        }
        onReminderTapped?.call(int.tryParse(payload));
      },
```

- [ ] **Step 6: 掛上導頁 callback**

在 `lib/main.dart` 中設定 `FcmService.onReminderTapped` 的同一處，加入：

```dart
  FcmService.onForumReplyTapped = (postId) {
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => ForumDetailScreen(postId: postId)),
    );
  };
```

並加入 `import 'screens/forum/forum_detail_screen.dart';`。

若 `main.dart` 目前沒有集中設定 `onReminderTapped` 的位置，就設在既有的 `FcmService.init()` 呼叫之後、`runApp()` 之前——冷啟動的暫存訊息由 `consumePendingInitialMessage()` 在 SplashScreen 之後才處理，那時 callback 已就緒。

- [ ] **Step 7: 接上廣場頁的鈴鐺**

在 `lib/screens/plaza/plaza_screen.dart` 加入 `import '../forum/forum_notifications_screen.dart';`，把鈴鐺 `IconButton` 的 `onPressed` 改為導向 `ForumNotificationsScreen`，回來後呼叫 `_loadUnread()`（程式碼見 Task 6 Step 5 的標題列片段）。

- [ ] **Step 8: 驗證與 Commit**

Run: `flutter analyze` → 無 error
Run: `flutter test` → 全部通過

```bash
git add lib/screens/forum/forum_notifications_screen.dart lib/services/fcm_service.dart lib/main.dart lib/screens/plaza/plaza_screen.dart test/widgets/forum_notifications_screen_test.dart
git commit -m "feat: 新增論壇通知中心與回覆推播導頁"
```

---

### Task 12: 我的收藏

書籤的後端端點由使用者另行補上（規格 §9）。前端依約定完整實作；端點就緒前，點收藏會拿到 404 並顯示錯誤訊息，收藏頁會顯示錯誤與重試——這是開發期間的預期狀態。

**Files:**
- Create: `lib/screens/forum/forum_bookmarks_screen.dart`
- Modify: `lib/screens/plaza/plaza_screen.dart`（書籤 icon 接上導頁）
- Test: `test/widgets/forum_bookmarks_screen_test.dart`

**Interfaces:**
- Consumes: Task 4 的 `ForumService.bookmarks` / `bookmarkPost`、Task 6 的 `ForumBoardView`、Task 8 的 `ForumDetailScreen`
- Produces: `ForumBookmarksScreen()`

- [ ] **Step 1: 寫失敗的測試**

建立 `test/widgets/forum_bookmarks_screen_test.dart`：

```dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/screens/forum/forum_bookmarks_screen.dart';

void main() {
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
```

- [ ] **Step 2: 執行測試，確認失敗**

Run: `flutter test test/widgets/forum_bookmarks_screen_test.dart`
Expected: FAIL，`Target of URI doesn't exist: '.../forum_bookmarks_screen.dart'`。

- [ ] **Step 3: 實作**

建立 `lib/screens/forum/forum_bookmarks_screen.dart`：

```dart
// 我的收藏。重複使用 ForumBoardView：分頁、空狀態、錯誤重試、樂觀更新都現成。
//
// 後端端點由使用者另行補上（規格 §9）。端點上線前這頁會顯示錯誤與重試，
// 屬開發期間的預期狀態。

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../models/forum_models.dart';
import '../../services/forum_service.dart';
import 'forum_board_view.dart';
import 'forum_detail_screen.dart';

class ForumBookmarksScreen extends StatefulWidget {
  const ForumBookmarksScreen({super.key});

  @override
  State<ForumBookmarksScreen> createState() => _ForumBookmarksScreenState();
}

class _ForumBookmarksScreenState extends State<ForumBookmarksScreen> {
  final _viewKey = GlobalKey<ForumBoardViewState>();

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.creamLight,
        appBar: AppBar(
          backgroundColor: AppColors.creamLight,
          elevation: 0,
          foregroundColor: AppColors.ink,
          title: Text(
            '我的收藏',
            style: GoogleFonts.notoSerifTc(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
        ),
        body: ForumBoardView(
          key: _viewKey,
          emptyMessage: '還沒有收藏任何貼文',
          loadPage: ({cursor, after}) async {
            // 收藏頁沒有下拉刷新語意，after 直接重取第一頁。
            if (after != null) return ForumService.bookmarks();
            return ForumService.bookmarks(cursor: cursor);
          },
          toggleLike: ForumService.likePost,
          toggleBookmark: (postId, {required add}) async {
            final result = await ForumService.bookmarkPost(postId, add: add);
            // 取消收藏後這筆就不屬於本頁，直接移除比留著一個空心書籤誠實。
            if (!result) _viewKey.currentState?.removePost(postId);
            return result;
          },
          onOpenPost: (post) => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ForumDetailScreen(postId: post.id),
            ),
          ),
        ),
      );
}
```

`ForumPostPage` 在此不需直接建構，`models` 的 import 供 `ForumBoardView` 的型別推導使用；若 analyzer 提示未使用，移除該行 import。

- [ ] **Step 4: 執行測試，確認通過**

Run: `flutter test test/widgets/forum_bookmarks_screen_test.dart`
Expected: PASS，2 個測試全過。

- [ ] **Step 5: 接上廣場頁的書籤 icon**

在 `lib/screens/plaza/plaza_screen.dart` 加入 `import '../forum/forum_bookmarks_screen.dart';`，把書籤 `IconButton` 的 `onPressed` 改為導向 `ForumBookmarksScreen`。

- [ ] **Step 6: 驗證與 Commit**

Run: `flutter analyze` → 無 error
Run: `flutter test` → 全部通過

```bash
git add lib/screens/forum/forum_bookmarks_screen.dart lib/screens/plaza/plaza_screen.dart test/widgets/forum_bookmarks_screen_test.dart
git commit -m "feat: 新增我的收藏頁與貼文收藏"
```

---

### Task 13: 端到端檢查與收尾

**Files:**
- Modify: `docs/superpowers/specs/2026-08-14-forum-frontend-v2-design.md`（如實作過程有偏離，補記決策）

- [ ] **Step 1: 全量驗證**

Run: `flutter analyze`
Expected: `No issues found!`

Run: `flutter test`
Expected: 全部通過，無 skip。

- [ ] **Step 2: 確認沒有殘留的假資料與死程式**

Run: `git grep -n "Sayun\|Pisaw\|Bakan" -- lib`
Expected: 只在測試以外的地方沒有命中（`lib/` 底下應為空結果）。

Run: `git grep -rn "compose_screen" -- lib`
Expected: 只命中 `forum_compose_screen.dart` 自身與其 import，不應再有 `plaza/compose_screen.dart`。

- [ ] **Step 3: 在實機或模擬器上走一次主要流程**

依序確認：看板切換 → 下拉刷新 → 捲到底載入更多 → 開貼文 → 按讚 → 留言 → 回覆留言 → 檢舉 → 發文（含選 2 張圖）→ 編輯自己的貼文 → 刪除 → 搜尋 → 通知中心 → 全部已讀。

書籤相關的兩處（卡片書籤鈕、我的收藏頁）在後端端點上線前預期會顯示錯誤訊息，這是規格 §9 記載的預期狀態，不視為缺陷。

- [ ] **Step 4: 若有偏離設計，補記到規格**

實作過程若做了與規格不同的決定（例如某個限制改在別處驗證），在規格對應章節補一句說明與理由，然後：

```bash
git add docs/superpowers/specs/2026-08-14-forum-frontend-v2-design.md
git commit -m "docs: 補記論壇前端實作時的設計調整"
```

若沒有偏離，跳過此步。
