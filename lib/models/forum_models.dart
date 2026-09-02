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
    board: ForumBoard.fromJson(j['board'] as Map<String, dynamic>? ?? const {}),
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
  }) => ForumPost(
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

  /// 已刪除、但底下還有存活回覆的第一層留言，後端保留成佔位，
  /// 此時 body 與 author 都是 null（後端 API 文件 §4.4）。
  final bool isDeleted;

  final DateTime createdAt;

  /// 佔位留言沒有作者——已刪除的身分不外洩。
  final ForumAuthor? author;

  const ForumComment({
    required this.id,
    required this.postId,
    required this.parentCommentId,
    required this.body,
    required this.likeCount,
    required this.isLiked,
    required this.isDeleted,
    required this.createdAt,
    required this.author,
  });

  factory ForumComment.fromJson(Map<String, dynamic> j) {
    final author = j['author'];
    return ForumComment(
      id: _asInt(j['id']),
      postId: _asInt(j['post_id']),
      parentCommentId: _asIntOrNull(j['parent_comment_id']),
      body: j['body'] as String? ?? '',
      likeCount: _asInt(j['like_count']),
      isLiked: j['is_liked'] == true,
      isDeleted: j['is_deleted'] == true,
      createdAt: _asDate(j['created_at']),
      author: author is Map<String, dynamic>
          ? ForumAuthor.fromJson(author)
          : null,
    );
  }

  ForumComment copyWith({int? likeCount, bool? isLiked}) => ForumComment(
    id: id,
    postId: postId,
    parentCommentId: parentCommentId,
    body: body,
    likeCount: likeCount ?? this.likeCount,
    isLiked: isLiked ?? this.isLiked,
    isDeleted: isDeleted,
    createdAt: createdAt,
    author: author,
  );

  /// 把一則第一層留言就地轉成佔位：後端刪除第一層留言時會保留它，
  /// 好讓底下的回覆有東西可以掛（後端 API 文件 §4.3）。
  ForumComment asDeletedPlaceholder() => ForumComment(
    id: id,
    postId: postId,
    parentCommentId: parentCommentId,
    body: '',
    likeCount: 0,
    isLiked: false,
    isDeleted: true,
    createdAt: createdAt,
    author: null,
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

/// GET /api/forum/posts/likes —— 我按讚過的貼文。游標是 liked_at 時間戳字串
/// （非 ForumPostPage 用的貼文 id），故獨立一個分頁型別。
class ForumLikedPostPage {
  final List<ForumPost> posts;
  final String? nextCursor;

  const ForumLikedPostPage({required this.posts, required this.nextCursor});

  factory ForumLikedPostPage.fromJson(Map<String, dynamic> j) =>
      ForumLikedPostPage(
        posts: (j['posts'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(ForumPost.fromJson)
            .toList(),
        nextCursor: j['next_cursor'] as String?,
      );
}

/// GET /api/forum/comments/likes —— 我按讚過的留言。留言沒有獨立頁面，
/// 多帶 postId/postTitle/boardSlug 供前端連回原貼文。
class ForumLikedComment {
  final ForumComment comment;
  final int postId;
  final String? postTitle;
  final String? boardSlug;
  final DateTime? likedAt;

  const ForumLikedComment({
    required this.comment,
    required this.postId,
    this.postTitle,
    this.boardSlug,
    this.likedAt,
  });

  factory ForumLikedComment.fromJson(Map<String, dynamic> j) =>
      ForumLikedComment(
        comment: ForumComment.fromJson(j),
        postId: _asInt(j['post_id']),
        postTitle: j['post_title'] as String?,
        boardSlug: j['board_slug'] as String?,
        likedAt: j['liked_at'] != null
            ? DateTime.tryParse(j['liked_at'] as String)
            : null,
      );
}

class ForumLikedCommentPage {
  final List<ForumLikedComment> comments;
  final String? nextCursor;

  const ForumLikedCommentPage({
    required this.comments,
    required this.nextCursor,
  });

  factory ForumLikedCommentPage.fromJson(Map<String, dynamic> j) =>
      ForumLikedCommentPage(
        comments: (j['comments'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(ForumLikedComment.fromJson)
            .toList(),
        nextCursor: j['next_cursor'] as String?,
      );
}

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
      .map(
        (c) => ForumCommentThread(root: c, replies: byParent[c.id] ?? const []),
      )
      .toList();
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
