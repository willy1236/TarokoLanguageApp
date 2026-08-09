import '../core/constants/api.dart';
import '../core/network/api_client.dart';
import '../models/forum_models.dart';

class ForumService {
  static Future<ForumPage> fetchPosts({
    String? category,
    String? cursor,
    String? search,
  }) async {
    final r = await ApiClient.get(
      ApiConfig.forumPosts,
      query: {
        if (category != null) 'category': category,
        if (cursor != null) 'cursor': cursor,
        if (search != null && search.trim().isNotEmpty) 'q': search.trim(),
        'limit': '20',
      },
    );
    return ForumPage(
      (r['posts'] as List<dynamic>? ?? const [])
          .map((x) => ForumPost.fromJson(x as Map<String, dynamic>))
          .toList(),
      r['next_cursor'] as String?,
    );
  }

  static Future<ForumPost> fetchPost(int id) async {
    final r = await ApiClient.get(ApiConfig.forumPost(id));
    return ForumPost.fromJson(r['post'] as Map<String, dynamic>);
  }

  static Future<ForumPost> createPost({
    required String category,
    required String title,
    required String content,
    List<String> imageUrls = const [],
  }) async {
    final r = await ApiClient.post(ApiConfig.forumPosts, {
      'category': category,
      'title': title,
      'content': content,
      'image_urls': imageUrls,
    });
    return ForumPost.fromJson(r['post'] as Map<String, dynamic>);
  }

  static Future<ForumPost> updatePost(
    int id, {
    String? category,
    String? title,
    String? content,
    List<String>? imageUrls,
  }) async {
    final r = await ApiClient.patch(ApiConfig.forumPost(id), {
      if (category != null) 'category': category,
      if (title != null) 'title': title,
      if (content != null) 'content': content,
      if (imageUrls != null) 'image_urls': imageUrls,
    });
    return ForumPost.fromJson(r['post'] as Map<String, dynamic>);
  }

  static Future<void> deletePost(int id) =>
      ApiClient.delete(ApiConfig.forumPost(id));
  static Future<List<ForumComment>> fetchComments(int id) async {
    final r = await ApiClient.get(ApiConfig.forumComments(id));
    return (r['comments'] as List<dynamic>? ?? const [])
        .map((x) => ForumComment.fromJson(x as Map<String, dynamic>))
        .toList();
  }

  static Future<ForumComment> createComment(int id, String content) async {
    final r = await ApiClient.post(ApiConfig.forumComments(id), {
      'content': content,
    });
    return ForumComment.fromJson(r['comment'] as Map<String, dynamic>);
  }

  static Future<ForumComment> updateComment(int id, String content) async {
    final r = await ApiClient.patch(ApiConfig.forumComment(id), {
      'content': content,
    });
    return ForumComment.fromJson(r['comment'] as Map<String, dynamic>);
  }

  static Future<void> deleteComment(int id) =>
      ApiClient.delete(ApiConfig.forumComment(id));
  static Future<Map<String, dynamic>> toggleLike(int id) =>
      ApiClient.post(ApiConfig.forumLike(id));
  static Future<Map<String, dynamic>> toggleBookmark(int id) =>
      ApiClient.post(ApiConfig.forumBookmark(id));
  static Future<void> report({
    int? postId,
    int? commentId,
    required String reason,
  }) => ApiClient.post(ApiConfig.forumReports, {
    if (postId != null) 'post_id': postId,
    if (commentId != null) 'comment_id': commentId,
    'reason': reason,
  });
  static Future<List<ForumPost>> bookmarks() async {
    final r = await ApiClient.get(ApiConfig.forumBookmarks);
    return (r['posts'] as List<dynamic>? ?? const [])
        .map((x) => ForumPost.fromJson(x as Map<String, dynamic>))
        .toList();
  }

  static Future<List<ForumNotification>> notifications() async {
    final r = await ApiClient.get(ApiConfig.forumNotifications);
    return (r['notifications'] as List<dynamic>? ?? const [])
        .map((x) => ForumNotification.fromJson(x as Map<String, dynamic>))
        .toList();
  }

  static Future<void> markNotificationRead(int id) =>
      ApiClient.post(ApiConfig.forumNotificationRead(id));

  static Future<List<ForumReport>> adminReports() async {
    final r = await ApiClient.get(
      ApiConfig.forumAdminReports,
      query: {'status': 'pending'},
    );
    return (r['reports'] as List<dynamic>? ?? const [])
        .map((x) => ForumReport.fromJson(x as Map<String, dynamic>))
        .toList();
  }

  static Future<void> reviewReport(int id, String action) =>
      ApiClient.post(ApiConfig.forumAdminReportReview(id), {'action': action});

  static Future<String> uploadImage({
    required List<int> bytes,
    required String filename,
    required String mimeType,
  }) async {
    final r = await ApiClient.postMultipartBytes(
      ApiConfig.forumMedia,
      bytes: bytes,
      filename: filename,
      contentType: mimeType,
    );
    return r['url'] as String;
  }
}
