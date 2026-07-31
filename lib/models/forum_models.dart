class ForumAuthor {
  const ForumAuthor({required this.uid, required this.displayName, this.avatarUrl});

  final int uid;
  final String displayName;
  final String? avatarUrl;

  factory ForumAuthor.fromJson(Map<String, dynamic> json) => ForumAuthor(
        uid: (json['uid'] as num?)?.toInt() ?? 0,
        displayName: json['display_name'] as String? ?? '族人朋友',
        avatarUrl: json['avatar_url'] as String?,
      );
}

class ForumPost {
  const ForumPost({
    required this.id,
    required this.category,
    required this.title,
    required this.content,
    required this.commentCount,
    required this.createdAt,
    required this.author,
  });

  final int id;
  final String category;
  final String title;
  final String content;
  final int commentCount;
  final DateTime createdAt;
  final ForumAuthor author;

  factory ForumPost.fromJson(Map<String, dynamic> json) => ForumPost(
        id: (json['id'] as num).toInt(),
        category: json['category'] as String? ?? 'general',
        title: json['title'] as String? ?? '',
        content: json['content'] as String? ?? '',
        commentCount: (json['comment_count'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
        author: ForumAuthor.fromJson(json['author'] as Map<String, dynamic>? ?? const {}),
      );
}

class ForumComment {
  const ForumComment({
    required this.id,
    required this.content,
    required this.createdAt,
    required this.author,
  });

  final int id;
  final String content;
  final DateTime createdAt;
  final ForumAuthor author;

  factory ForumComment.fromJson(Map<String, dynamic> json) => ForumComment(
        id: (json['id'] as num).toInt(),
        content: json['content'] as String? ?? '',
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
        author: ForumAuthor.fromJson(json['author'] as Map<String, dynamic>? ?? const {}),
      );
}
