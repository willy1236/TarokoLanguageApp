# 論壇前端 v2 設計規格

**日期**：2026-08-14
**狀態**：設計定稿，待實作
**適用**：TarokoLanguageApp（Flutter）
**對應後端**：`Truku_backend` 的 `feature/forum-v2`，規格見該 repo 的 `docs/superpowers/specs/2026-08-14-forum-v2-design.md`
**視覺參考**：`feature/forum-dcard` 分支的 `lib/screens/plaza/forum_screen.dart`

---

## 1. 背景與目標

後端論壇已改版為 v2，資料模型與 v1 不相容。前端目前的狀態是：

- 本分支（master 系）的 `lib/screens/plaza/plaza_screen.dart` 論壇區塊是**寫死的假資料**，沒有 forum 的 model / service / API 常數。
- `feature/forum-dcard` 分支有一版完整 UI（`forum_screen.dart`，1500+ 行、7 個畫面），但綁定 v1 模型：`category` 字串分類、`content`、`image_urls[]`、`is_bookmarked`、單一 `toggleLike` 端點、WebSocket 即時層、App 內檢舉審核後台。

**本次目標**：沿用 dcard 的視覺語彙（配色、字體、卡片與 tab 樣式、空狀態的菱形紋樣），資料層與部分畫面依 v2 重寫，完成 App 端所有 forum-v2 使用者功能。

**範圍**：看板、貼文（含附圖與標籤）、兩層留言、按讚、書籤、搜尋、通知中心、檢舉。

**明確不做**：檢舉審核後台（v2 改走 `requireInternal`，不對 App 使用者開放）、WebSocket 即時層（v2 改下拉刷新）、瀏覽數、私訊。

---

## 2. v1 → v2 的模型差異

| v1（dcard） | v2 | 影響 |
|---|---|---|
| `category`（字串） | `board`（看板物件，後端維護） | 分類 tab 改為動態拉取 |
| `content` | `body` | 欄位改名 |
| `image_urls: string[]` | `images: string[]`（獨立資料表） | 欄位改名 |
| 無標籤 | `tags: [{name, slug}]` | 新功能 |
| 單層留言 | 兩層留言（`parent_comment_id`） | 詳情頁需重寫 |
| `POST /forum/posts/:id/like`（toggle） | `POST` 按讚 / `DELETE` 取消，分開 | Service 改寫 |
| 留言不能按讚 | 留言可按讚 | 新功能 |
| `is_mine` | 後端不再回傳 | 改用當前 uid 比對 `author.uid` |
| `is_bookmarked` + `/bookmark` | v2 移除 | 見 §9，後端另行補回 |
| 檢舉 `post_id` / `comment_id` | `target_type` + `target_id` | Service 改寫 |
| WebSocket 即時更新 | 下拉刷新 | 移除 `forum_realtime_service.dart` |
| App 內檢舉審核畫面 | 走 `requireInternal` | 不移植 |

---

## 3. 檔案結構

```
lib/models/forum_models.dart              全部重寫
lib/services/forum_service.dart           全部重寫
lib/core/constants/api.dart               新增 forum 端點常數
lib/core/network/api_client.dart          新增多檔 multipart；修 delete() 的離線處理
lib/screens/forum/
  forum_board_view.dart                   看板貼文列表（嵌入廣場頁）
  forum_detail_screen.dart                貼文詳情 + 兩層留言
  forum_compose_screen.dart               發文 / 編輯（含選圖）
  forum_search_screen.dart                關鍵字搜尋
  forum_notifications_screen.dart         通知中心
  forum_bookmarks_screen.dart             我的收藏
  widgets/
    forum_post_card.dart                  列表卡片
    forum_comment_tile.dart               留言 / 回覆
    forum_image_grid.dart                 附圖網格 + 全螢幕檢視
    forum_report_sheet.dart               檢舉 bottom sheet
lib/screens/plaza/plaza_screen.dart       改：貼文區換成 ForumBoardView，頂部加入口
lib/services/fcm_service.dart             改：新增 reply_post / reply_comment 導頁
```

`feature/forum-dcard` 的 `forum_realtime_service.dart` 不移植。dcard 的 `forum_screen.dart` 僅作為視覺參考，不 cherry-pick。

拆檔理由：dcard 版單檔已 1500+ 行，v2 功能更多，維持單檔預估超過 2500 行，難以閱讀與局部修改。

---

## 4. 資料模型

全部依 v2 後端 `routes/forum.ts` 的實際回傳定義。所有 id 與計數欄位以 `int.tryParse(x?.toString())` 解析——pg driver 可能把 `BIGINT` 以字串回傳，v1 為此修過三個 commit。

| Model | 欄位 |
|---|---|
| `ForumBoard` | `id, slug, name, description` |
| `ForumAuthor` | `uid, displayName, avatarUrl` |
| `ForumTag` | `name, slug`（`/forum/tags` 另回 `postCount`，以 `ForumTagStat` 表示） |
| `ForumPost` | `id, board, title, body, likeCount, commentCount, isPinned, isLiked, isBookmarked, images[], tags[], createdAt, updatedAt, author` |
| `ForumComment` | `id, postId, parentCommentId, body, likeCount, isLiked, createdAt, author` |
| `ForumPostPage` | `pinned[], posts[], nextCursor` |
| `ForumCommentPage` | `comments[]`（第一層）、`replies[]`（第二層）、`nextCursor` |
| `ForumNotification` | `id, type, postId, commentId, postTitle, isRead, createdAt, actor` |
| `ForumNotificationPage` | `items[], unreadCount, nextCursor` |

**缺欄位一律有安全預設**：`isBookmarked` 在後端補上端點之前不會出現在 payload，缺少時視為 `false`（見 §9）。`images` / `tags` 缺少時視為空陣列。

**`isMine` 的替代**：後端不再回傳。前端以 `AuthService` 的當前 uid 與 `post.author.uid` / `comment.author.uid` 比對，決定是否顯示編輯／刪除。此判斷僅影響 UI；真正的權限由後端把關（非作者會收到 403）。

**留言分組**：後端把第一層與第二層分別放在 `comments` 與 `replies`。前端以純函式 `groupComments(comments, replies)` 依 `parentCommentId` 分組成 `List<({ForumComment root, List<ForumComment> replies})>`。抽成純函式以便單測。

---

## 5. Service 層

`ForumService`，沿用專案既有的 static method 風格（同 `EventService` / `ShopService`），全部走 `ApiClient`。

| 方法 | 端點 |
|---|---|
| `boards()` | `GET /forum/boards` |
| `posts(slug, {cursor, after, limit})` | `GET /forum/boards/:slug/posts` |
| `post(id)` | `GET /forum/posts/:id` |
| `createPost({boardId, title, body, tags, images})` | `POST /forum/posts`（multipart） |
| `updatePost(id, {title, body, tags})` | `PATCH /forum/posts/:id` |
| `deletePost(id)` | `DELETE /forum/posts/:id` |
| `comments(postId, {cursor})` | `GET /forum/posts/:id/comments` |
| `createComment(postId, body, {parentCommentId})` | `POST /forum/posts/:id/comments` |
| `deleteComment(id)` | `DELETE /forum/comments/:id` |
| `likePost(id, {required bool like})` | `POST` / `DELETE /forum/posts/:id/like` |
| `likeComment(id, {required bool like})` | `POST` / `DELETE /forum/comments/:id/like` |
| `search(q, {board, cursor})` | `GET /forum/search` |
| `tags()` | `GET /forum/tags` |
| `report({targetType, targetId, reason})` | `POST /forum/reports` |
| `notifications({cursor})` | `GET /forum/notifications` |
| `markRead({ids})` | `POST /forum/notifications/read`（不帶 ids 表示全部） |
| `bookmarkPost(id, {required bool add})` | `POST` / `DELETE /forum/posts/:id/bookmark`（見 §9） |
| `bookmarks({cursor})` | `GET /forum/bookmarks`（見 §9） |

按讚類方法回傳 `({bool liked, int likeCount})`，直接取後端的 `{liked, like_count}`，不自行推算。

**後端限制（前端須同步驗證，避免無謂的 400）**：標題 ≤120 字、內文 ≤5000 字、留言 ≤2000 字、檢舉理由 ≤1000 字、標籤最多 5 個且每個 ≤20 字、附圖最多 4 張且每張 ≤5MB（MIME 限 JPEG / PNG / WebP）、搜尋關鍵字 2–80 字、分頁 limit 上限 50。

---

## 6. ApiClient 改動

1. **新增 `postMultipart(path, {Map<String, String> fields, List<MultipartFileData> files})`**：發文需要一次送出文字欄位與最多 4 張圖。後端 `POST /forum/posts` 同時吃 JSON 與 multipart，但有附圖時必須走 multipart。
2. **修 `delete()` 未包 `_send()`**：現有 `delete()` 直接呼叫 `http.delete`，離線時會漏出原始 `SocketException`，而 `get` / `post` / `patch` 都已轉成 `NETWORK_ERROR`。論壇的取消讚與刪文都走 DELETE，順手補齊，讓錯誤處理一致。

兩者皆為既有共用元件的小幅擴充，不改變現有呼叫端行為。

---

## 7. 畫面

### 7.1 廣場頁（改造 `plaza_screen.dart`）

保留現有骨架：`ALANG · 廣場` 標題列、`SMRATUC · 近期活動` 橫向小卡。改動三處。

- **標題列右側**：在既有「發布」鈕左側依序加入三個 icon——搜尋、書籤（我的收藏）、鈴鐺（通知）。鈴鐺右上角顯示未讀紅點，數字取自 `notifications()` 的 `unreadCount`，進頁時抓一次，下拉刷新時更新。
- **Tab 列**：目前寫死單一「動態」。改為從 `/forum/boards` 動態載入的看板橫向捲動 tab，沿用 dcard `_CategoryTab` 的底線樣式（選中為 `AppColors.primary` + 2px 底線，未選中為 `AppColors.fog`）。看板載入失敗時顯示重試，不阻擋活動小卡。
- **貼文區**：`PATAS · 族人發文` 標題下換成 `ForumBoardView`。

### 7.2 `ForumBoardView`

- `RefreshIndicator` 下拉刷新：呼叫 `?after=<目前最新 post id>`，把新貼文接在頂端。列表為空時退回一般載入。
- 觸底自動載下一頁：`?cursor=<最後一筆 id>`，沿用 dcard 的 `_onScroll` 判斷。
- 置頂貼文（回傳的 `pinned`）永遠排在最上方，卡片加「置頂」標記。置頂不參與分頁。
- 首次載入顯示 loading，空看板顯示沿用 dcard 的空狀態（`TrukuDiamond` 紋樣 + `Icons.forum_outlined`）。
- 載入失敗顯示錯誤訊息與重試鈕，不留白畫面。

### 7.3 `ForumPostCard`

沿用 dcard 卡片視覺：`AppColors.cream` 底、`creamDeep` 邊框、圓角 16、圓形頭像描 `AppColors.gold` 邊、標題 `GoogleFonts.notoSerifTc`。內容依 v2 欄位調整：

```
[頭像] 作者名                                   [置頂]
       看板名 · 相對時間
標題
內文（3 行截斷）
[附圖網格：1 張滿版 / 2-4 張九宮格]
#標籤 #標籤
♡ likeCount    💬 commentCount    ⤴ 書籤
```

按讚與書籤在卡片上可直接點，採**樂觀更新**：先改本地狀態，失敗則回滾並跳 SnackBar。成功後以後端回傳的 `like_count` 校正，不用本地累加值。

### 7.4 `ForumDetailScreen`

- 上半：完整貼文。附圖可點開全螢幕檢視、左右滑動切換。
- 下半：兩層留言。第一層留言下方縮排顯示其回覆。每則留言可按讚、回覆、檢舉；作者本人多一個刪除。
- 底部固定輸入列：預設回覆貼文。點某則留言的「回覆」後，輸入列上方出現「回覆 @某人 ✕」的 chip，送出時帶 `parentCommentId`。
- **兩層限制**：對第二層回覆按「回覆」時，`parentCommentId` 仍指向其所屬的第一層留言（後端會擋第三層，前端不應送出必然失敗的請求）。
- 貼文作者本人：右上 `⋯` 提供編輯／刪除；非本人提供檢舉。
- 第一層留言以 `cursor` 分頁載更多。新增留言成功後插入本地清單並把 `commentCount + 1`。

### 7.5 `ForumComposeScreen`（發文 / 編輯）

沿用 dcard 的排版結構（看板 segment、作者列、標題輸入、內文輸入、底部工具列）。

- 看板選擇（必填）
- 標題 ≤120 字、內文 ≤5000 字，即時字數提示，超過即禁止送出
- 標籤：最多 5 個、每個 ≤20 字，chip 輸入；可從 `/forum/tags` 的熱門標籤點選
- 選圖：最多 4 張。`image_picker` 取原檔 →`flutter_image_compress` 壓縮（長邊上限 1920、品質 85、輸出 JPEG）→ 縮圖列可刪除與調整順序。壓縮後仍超過 5MB 則提示改選較小的圖。
- 送出一次 multipart 完成；上傳中鎖住送出鈕並顯示進度
- **編輯模式走 PATCH，不處理附圖**——後端 `PATCH /forum/posts/:id` 只接受文字欄位。編輯畫面的附圖區在編輯模式下唯讀（顯示現有圖但不可增刪），避免造成「改了沒生效」的錯覺。

### 7.6 `ForumSearchScreen`

- 關鍵字 2–80 字才送出（後端硬性限制，未達 2 字時送出鈕停用並提示）
- 可選「限定看板」
- 結果沿用 `ForumPostCard`，以 cursor 分頁
- 無結果顯示空狀態
- 後端 `pg_trgm` 只做子字串比對、無相關度排序，結果依 id 遞減。介面不宣稱「相關度排序」。

### 7.7 `ForumNotificationsScreen`

- 列出「有人回覆你的貼文／留言」，未讀項底色不同
- 點一則 → 呼叫 `markRead(ids: [id])` → 導到該貼文詳情
- 右上「全部已讀」→ `markRead()`（不帶 ids）
- cursor 分頁

### 7.8 `ForumBookmarksScreen`

`GET /forum/bookmarks` 的貼文列表，沿用 `ForumPostCard` 與 cursor 分頁。取消收藏後從清單移除。空狀態沿用同一套樣式。

---

## 8. FCM 導頁

`lib/services/fcm_service.dart` 目前只解析 `event_reminder` / `event_cancelled`。新增解析論壇通知：

- payload：`{ type: 'reply_post' | 'reply_comment', post_id, comment_id }`（皆為字串）
- 點擊通知 → 導到 `ForumDetailScreen(postId)`
- 沿用既有的 `navigatorKey` 與「Navigator 尚未掛載時先暫存、待 SplashScreen 後再導頁」機制
- `post_id` 缺失或無法解析時忽略並記 log，與既有 `event_id` 的處理一致

---

## 9. 書籤（後端由使用者另行補上）

v2 後端規格 §1 將書籤列為 YAGNI，§7.0 拆除了 v1 的 `forum_bookmarks` 表；§8 則將其列為「未來擴充（不影響現有模型）」。本次前端**完整實作書籤 UI 與 service**，後端端點由使用者在 `Truku_backend` 另行補上。

**前端依循的約定**（與 `is_liked` 同構，請後端據此實作）：

| 項目 | 約定 |
|---|---|
| 加入收藏 | `POST /api/forum/posts/:id/bookmark` → `201 { bookmarked: true }` |
| 取消收藏 | `DELETE /api/forum/posts/:id/bookmark` → `200 { bookmarked: false }` |
| 收藏列表 | `GET /api/forum/bookmarks?cursor=&limit=` → `{ posts: [...], next_cursor }`，貼文結構與 `enrichPosts()` 完全相同 |
| 貼文欄位 | `enrichPosts()` 與 `onePost()` 的回傳加上 `is_bookmarked: boolean`，與 `is_liked` 同一批查詢，不新增 N+1 |
| 資料表 | `forum_bookmarks(post_id BIGINT, uid INT, created_at TIMESTAMPTZ)`，`PRIMARY KEY (post_id, uid)`，`post_id` FK `ON DELETE CASCADE` |
| 重複操作 | `ON CONFLICT DO NOTHING` / 刪除不存在的收藏皆視為成功，不回錯誤 |
| 計數 | **不做** `bookmark_count`。書籤是私人行為，不需要公開計數，也就不需要反正規化計數與其一致性維護。 |

**端點上線前的行為**：`is_bookmarked` 缺欄位視為 `false`；點擊書籤會收到 404 並顯示錯誤 SnackBar。這是開發期間的預期狀態，不另做 feature flag——加一個之後必然要移除的開關，比暫時的錯誤訊息成本更高。

---

## 10. 錯誤處理

- 全部走既有 `ApiException`。401 由 `ApiClient._forceLogout()` 統一踢回登入頁，各畫面不重複處理。
- 其餘錯誤顯示 `e.message` 的 SnackBar（後端錯誤訊息本來就是中文使用者可讀的）。
- `POST_NOT_FOUND`：貼文詳情頁提示「這篇貼文已被刪除」並退回列表；列表頁把該筆移除。
- `COMMENT_NOT_FOUND`：把該則留言從清單移除。
- 重複檢舉後端回 `201 { ok: true }` 不視為錯誤，前端一律顯示「已收到檢舉」。
- `NETWORK_ERROR`（離線）：列表顯示錯誤訊息與重試鈕，不顯示空白或無限 loading。
- 樂觀更新（按讚、書籤）失敗一律回滾到操作前狀態。

---

## 11. 測試

專案已有 `test/` 與 `integration_test/`。本次補：

- **Model 測試**：各 `fromJson` 對照 v2 實際 payload，涵蓋 BIGINT 以字串回傳、`images` / `tags` 為空、`parent_comment_id` 為 null、`is_bookmarked` 欄位不存在。
- **純函式測試**：`groupComments(comments, replies)` 的分組結果，含孤兒 reply（parent 已被刪）的處理。
- **Service 測試**：以假 http client 驗證各端點的 URL、query 參數、multipart 欄位組成與回傳解析；按讚的 POST / DELETE 分流。
- **Widget 測試**：`ForumPostCard` 按讚樂觀更新成功與失敗回滾；`ForumBoardView` 的空狀態、載入更多、錯誤重試。

---

## 12. 實作順序

1. **資料層**：`forum_models.dart`、`api.dart` 端點常數、`ApiClient` 的 multipart 與 `delete()` 修正、`forum_service.dart`（不含書籤）+ model / service 測試
2. **列表**：`ForumPostCard`、`ForumBoardView`、改造 `plaza_screen.dart`（看板 tab、下拉刷新、分頁）+ widget 測試
3. **詳情與留言**：`ForumDetailScreen`、`ForumCommentTile`、`groupComments`、按讚
4. **發文**：新增 image_picker / flutter_image_compress / cached_network_image 依賴、`ForumComposeScreen`、`ForumImageGrid`、編輯與刪除
5. **搜尋與標籤**：`ForumSearchScreen`、標籤選取
6. **通知**：`ForumNotificationsScreen`、廣場頁紅點、`fcm_service.dart` 導頁
7. **檢舉**：`ForumReportSheet`
8. **書籤**：service 方法、卡片與詳情的書籤鈕、`ForumBookmarksScreen`（後端端點就緒後才能端到端驗證）

---

## 13. 新增依賴

| 套件 | 用途 |
|---|---|
| `image_picker` | 從相簿選圖 / 拍照 |
| `flutter_image_compress` | 上傳前壓縮至後端 5MB 限制內（後端不做伺服器端壓縮，見後端規格 §5） |
| `cached_network_image` | 貼文附圖快取，避免列表捲動時重複下載 |

---

## 14. 實作偏離記錄

實作過程中與本規格不同的決定，連同理由記錄於此。

| 項目 | 規格原本 | 實際做法 | 理由 |
|---|---|---|---|
| `http_parser` 依賴 | §13 未列 | 加入 `http_parser: ^4.1.2` | multipart 每個 part 必須帶 `Content-Type`，後端 multer 的 `fileFilter` 以它過濾；`http` 預設送 `application/octet-stream` 會被拒收 |
| `ApiClient` 可測試性 | 未提 | 新增可注入的 `static http.Client httpClient` | service 的端點、query、multipart 組成需在無網路下驗證；原本直接呼叫 `http` 頂層函式無法替換傳輸層 |
| `ForumBoardView.prependOnRefresh` | §7.2 只描述下拉刷新用 `after` 前置 | 新增參數，預設 `true`；收藏頁與搜尋頁傳 `false` 改為整份重載 | 收藏與搜尋沒有「比某 id 更新」的語意，硬套前置模型會讓下拉刷新把整頁重複一次 |
| `ForumBoardView.reloadKey` | 未提 | 以身分字串比對決定是否重載，取代比對 `loadPage` closure | Dart 的 closure 不會相等，原本任何 `setState` 都會讓列表退回第一頁 |
| 詳情頁的狀態回傳 | §7.4 未定義 | 新增 `onPostChanged` 回呼即時通知列表，刪除仍走 pop 結果 | 先前以 `PopScope(canPop: false)` 攜帶結果，會讓 iOS 邊緣滑動返回整個失效（`isPopGestureEnabled` 在 `doNotPop` 時為 false） |
| 詳情頁的書籤鈕 | §7.4 未列，§12 步驟 8 有列 | 已實作，與按讚並列 | 依 §12 |
| 發文附圖排序 | §7.5「縮圖列可刪可排序」 | **只做刪除，未做排序** | 未實作，列為後續項目 |
| 廣場頁 `PATAS · 族人發文` 小標 | §7.1 保留 | 已移除 | 看板 tab 已標示內容分類，小標成為重複資訊 |
| 上傳進度 | §7.5「顯示進度」 | 只顯示「送出中…」文字 | 未實作進度百分比，列為後續項目 |

### 跨看板貼文（廣場的「全部」tab，後端待補）

廣場的看板 tab 最前面是「全部」，且為進頁預設。v2 後端只有 `GET /api/forum/boards/:slug/posts`，沒有跨看板端點，因此需要後端補上一支，約定與看板貼文同構：

| 項目 | 約定 |
|---|---|
| 端點 | `GET /api/forum/posts?cursor=&after=&limit=` |
| 回傳 | `{ pinned, posts, next_cursor }`，貼文結構與 `enrichPosts()` 完全相同 |
| 排序 | 與看板貼文一致：置頂在前，其餘依 id 遞減 |
| 分頁 | keyset，`cursor` 取更舊、`after` 取更新，兩者互斥 |

**端點上線前**：廣場預設停在「全部」，會顯示錯誤與重試。改成預設停在第一個看板只需把 `plaza_screen.dart` 的 `_boardSlug` 初值設為 `_boards.first.slug`。

### 分類（看板）名稱

看板名稱一律由後端 `forum_boards.name` 提供，前端直接顯示，**不做前端縮寫對照表**。`feature/forum-dcard` 把分類寫死在前端（`_categories` 常數），分類一改就要改 App 送審，v2 改用資料表正是為了解決這件事。要短名稱就改 seed 的 `name` 欄位。

### 已知後續項目（不阻擋合併）

- `ForumDetailScreen` 無 widget 測試；風險最高的三處為回覆層級收斂、按讚回滾、`POST_NOT_FOUND` 導回並移除。
- `ForumComposeScreen` 無 widget 測試，僅驗證函式 `forumComposeError` 有覆蓋。
- `ForumImageGrid` / `ForumImageViewer` 無測試；`ForumImageViewer` 的 `PageController` 建在 `build()` 內未 dispose，旋轉螢幕會跳回起始頁。
- FCM 的論壇／事件推播分流無自動化測試；`_parseForumPayload` 在 `post_id` 無法解析時整則丟棄，事件提醒路徑則仍會顯示通知只是不能點。
- 搜尋頁改用持久的 `GlobalKey` 後，切換關鍵字時舊查詢的第二頁回應可能落進新結果（窄競態）。
- `ForumBoardView` 的按讚／收藏完成時以 await 前的快照重建貼文，兩者同時進行會互相覆蓋（詳情頁已修，列表未修）。
- `ForumService.posts()` 的 cursor/after 互斥只用 `assert`，release build 會被移除。
