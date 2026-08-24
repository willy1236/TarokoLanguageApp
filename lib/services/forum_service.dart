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
//   POST   / DELETE /api/forum/posts/:id/bookmark 收藏 / 取消
//   GET    /api/forum/bookmarks                   我的收藏（游標是書籤 id，非貼文 id）
//   GET    /api/forum/posts                       跨看板總覽（board 選填）
//   GET    /api/forum/posts/likes                 我按讚過的貼文（游標是 liked_at）
//   GET    /api/forum/comments/likes               我按讚過的留言（游標是 liked_at）

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
  static const int searchMin = 1;
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

  /// 跨看板總覽（廣場的「全部」tab）。
  ///
  /// 總覽的 pinned 一律為空陣列，置頂貼文混在 posts 裡依 id 排序——置頂是各看板
  /// 自己的事，把所有看板的置頂堆在總覽最上面只會變成雜訊（後端 API 文件 §2.2）。
  /// 因此這裡不需要另外渲染置頂區塊。
  static Future<ForumPostPage> allPosts({
    int? cursor,
    int? after,
    int limit = 20,
  }) async {
    assert(cursor == null || after == null, 'cursor 與 after 不可同時使用');
    final data = await ApiClient.get(
      ApiConfig.forumPosts,
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
          // multipart 的欄位值只能是字串，後端在此格式下以逗號分隔解析
          // （後端 API 文件 §3.1），不是 JSON。
          if (tags.isNotEmpty) 'tags': tags.join(','),
        },
        files: images,
      );
    }
    return ForumPost.fromJson(data['post'] as Map<String, dynamic>);
  }

  /// 編輯。後端只接受 title 與 body，且兩者至少要給一個，否則回 400；
  /// board_id、tags、images 一律不可變更（後端 API 文件 §3.3）。
  static Future<ForumPost> updatePost(
    int id, {
    String? title,
    String? body,
  }) async {
    assert(title != null || body != null, 'title 與 body 至少要給一個');
    final data = await ApiClient.patch(ApiConfig.forumPost(id), {
      if (title != null) 'title': title,
      if (body != null) 'body': body,
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
  }) => _toggleLike(ApiConfig.forumPostLike(id), like: like);

  static Future<({bool liked, int likeCount})> likeComment(
    int id, {
    required bool like,
  }) => _toggleLike(ApiConfig.forumCommentLike(id), like: like);

  /// 回傳後端算出的真實計數，呼叫端不要自行累加——樂觀更新只是暫時值。
  static Future<({bool liked, int likeCount})> _toggleLike(
    String path, {
    required bool like,
  }) async {
    final data = like
        ? await ApiClient.post(path)
        : await ApiClient.delete(path);
    return (
      liked: data['liked'] == true,
      likeCount: int.tryParse(data['like_count']?.toString() ?? '') ?? 0,
    );
  }

  /// 我按讚過的貼文。[cursor] 為上一頁 next_cursor（liked_at 時間戳字串）。
  static Future<ForumLikedPostPage> likedPosts({String? cursor}) async {
    final data = await ApiClient.get(
      ApiConfig.forumPostLikes,
      query: {if (cursor != null) 'cursor': cursor},
    );
    return ForumLikedPostPage.fromJson(data);
  }

  /// 我按讚過的留言。留言沒有獨立頁面，每筆多帶 postId/postTitle/boardSlug
  /// 供前端連回原貼文。
  static Future<ForumLikedCommentPage> likedComments({String? cursor}) async {
    final data = await ApiClient.get(
      ApiConfig.forumCommentLikes,
      query: {if (cursor != null) 'cursor': cursor},
    );
    return ForumLikedCommentPage.fromJson(data);
  }

  // ── 標籤與搜尋 ────────────────────────────────────────────

  static Future<List<ForumTagStat>> tags() async {
    final data = await ApiClient.get(ApiConfig.forumTags);
    return (data['tags'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ForumTagStat.fromJson)
        .toList();
  }

  /// 後端限制關鍵字 1-80 字，未達長度直接擋下，不送出必然失敗的請求。
  /// [range]／[tribeId] 與 [board] 一樣皆選填、可任意組合。
  static Future<ForumPostPage> search(
    String q, {
    String? board,
    String? range,
    int? tribeId,
    int? cursor,
  }) async {
    final trimmed = q.trim();
    if (trimmed.length < searchMin || trimmed.length > searchMax) {
      throw ArgumentError('搜尋關鍵字須為 $searchMin-$searchMax 字');
    }
    final data = await ApiClient.get(
      ApiConfig.forumSearch,
      query: {
        'q': trimmed,
        if (board != null && board.isNotEmpty) 'board': board,
        if (range != null) 'range': range,
        if (tribeId != null) 'tribe_id': '$tribeId',
        if (cursor != null) 'cursor': '$cursor',
      },
    );
    return ForumPostPage.fromJson(data);
  }

  // ── 檢舉 ──────────────────────────────────────────────────

  /// [targetType] 為 'post' 或 'comment'。同一人重複檢舉後端不視為錯誤。
  static Future<void> report({
    required String targetType,
    required int targetId,
    required String reason,
  }) => ApiClient.post(ApiConfig.forumReports, {
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
  static Future<void> markRead({List<int>? ids}) => ApiClient.post(
    ApiConfig.forumNotificationsRead,
    {if (ids != null) 'ids': ids},
  );

  // ── 書籤 ──────────────────────────────────────────────────

  /// 回傳操作後的收藏狀態。重複收藏或重複取消後端都回 200，不必防連點。
  static Future<bool> bookmarkPost(int id, {required bool add}) async {
    final path = ApiConfig.forumPostBookmark(id);
    final data = add
        ? await ApiClient.post(path)
        : await ApiClient.delete(path);
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
