class ForumAuthor {
  const ForumAuthor({
    required this.uid,
    required this.displayName,
    this.avatarUrl,
  });
  final int uid;
  final String displayName;
  final String? avatarUrl;
  factory ForumAuthor.fromJson(Map<String, dynamic> j) => ForumAuthor(
    // The production PostgreSQL driver may serialise BIGINT IDs as strings.
    uid: int.tryParse(j['uid']?.toString() ?? '') ?? 0,
    displayName: j['display_name'] as String? ?? 'Anonymous',
    avatarUrl: j['avatar_url'] as String?,
  );
}

class ForumPost {
  const ForumPost({
    required this.id,
    required this.category,
    required this.title,
    required this.content,
    required this.imageUrls,
    required this.commentCount,
    required this.likeCount,
    required this.isLiked,
    required this.isBookmarked,
    required this.isMine,
    required this.createdAt,
    required this.author,
  });
  final int id;
  final String category, title, content;
  final List<String> imageUrls;
  final int commentCount, likeCount;
  final bool isLiked, isBookmarked, isMine;
  final DateTime createdAt;
  final ForumAuthor author;
  factory ForumPost.fromJson(Map<String, dynamic> j) => ForumPost(
    id: (j['id'] as num).toInt(),
    category: j['category'] as String? ?? 'general',
    title: j['title'] as String? ?? '',
    content: j['content'] as String? ?? '',
    imageUrls: (j['image_urls'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList(),
    commentCount: (j['comment_count'] as num?)?.toInt() ?? 0,
    likeCount: (j['like_count'] as num?)?.toInt() ?? 0,
    isLiked: j['is_liked'] == true,
    isBookmarked: j['is_bookmarked'] == true,
    isMine: j['is_mine'] == true,
    createdAt:
        DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
    author: ForumAuthor.fromJson(
      j['author'] as Map<String, dynamic>? ?? const {},
    ),
  );
}

class ForumComment {
  const ForumComment({
    required this.id,
    required this.postId,
    required this.content,
    required this.isMine,
    required this.createdAt,
    required this.author,
  });
  final int id, postId;
  final String content;
  final bool isMine;
  final DateTime createdAt;
  final ForumAuthor author;
  factory ForumComment.fromJson(Map<String, dynamic> j) => ForumComment(
    id: (j['id'] as num).toInt(),
    postId: (j['post_id'] as num?)?.toInt() ?? 0,
    content: j['content'] as String? ?? '',
    isMine: j['is_mine'] == true,
    createdAt:
        DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
    author: ForumAuthor.fromJson(
      j['author'] as Map<String, dynamic>? ?? const {},
    ),
  );
}

class ForumPage {
  const ForumPage(this.posts, this.nextCursor);
  final List<ForumPost> posts;
  final String? nextCursor;
}
