import '../core/constants/api.dart';
import '../core/network/api_client.dart';
import '../models/forum_models.dart';

class ForumService {
  static Future<List<ForumPost>> fetchPosts({String? category}) async {
    final response = await ApiClient.get(
      ApiConfig.forumPosts,
      query: {'category': ?category, 'limit': '30'},
    );
    final posts = response['posts'] as List<dynamic>? ?? const [];
    return posts
        .map((item) => ForumPost.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  static Future<ForumPost> createPost({
    required String category,
    required String title,
    required String content,
  }) async {
    final response = await ApiClient.post(ApiConfig.forumPosts, {
      'category': category,
      'title': title,
      'content': content,
    });
    return ForumPost.fromJson(response['post'] as Map<String, dynamic>);
  }

  static Future<List<ForumComment>> fetchComments(int postId) async {
    final response = await ApiClient.get(ApiConfig.forumComments(postId));
    final comments = response['comments'] as List<dynamic>? ?? const [];
    return comments
        .map((item) => ForumComment.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  static Future<ForumComment> createComment(int postId, String content) async {
    final response = await ApiClient.post(
      ApiConfig.forumComments(postId),
      {'content': content},
    );
    return ForumComment.fromJson(response['comment'] as Map<String, dynamic>);
  }
}
