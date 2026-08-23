import '../core/constants/api.dart';
import '../core/network/api_client.dart';
import '../models/article_models.dart';

class ArticleService {
  static Future<ArticleListResponse> fetchArticles({
    String? category,
    String sort = 'latest',
    int page = 1,
    int pageSize = 20,
  }) async {
    final json = await ApiClient.get(
      ApiConfig.articles,
      query: {
        'category': ?category,
        'sort': sort,
        'page': '$page',
        'page_size': '$pageSize',
      },
    );
    return ArticleListResponse.fromJson(json);
  }

  static Future<ArticleDetail> fetchArticleDetail(int id) async {
    final json = await ApiClient.get(ApiConfig.articleDetail(id));
    return ArticleDetail.fromJson(json);
  }

  /// 回傳後端算出的真實計數，呼叫端不要自行累加——樂觀更新只是暫時值。
  static Future<({bool liked, int likeCount})> likeArticle(
    int id, {
    required bool like,
  }) async {
    final path = ApiConfig.articleLike(id);
    final data = like
        ? await ApiClient.post(path)
        : await ApiClient.delete(path);
    return (
      liked: data['liked'] == true,
      likeCount: int.tryParse(data['like_count']?.toString() ?? '') ?? 0,
    );
  }

  static Future<bool> bookmarkArticle(int id, {required bool add}) async {
    final path = ApiConfig.articleBookmark(id);
    final data = add
        ? await ApiClient.post(path)
        : await ApiClient.delete(path);
    return data['bookmarked'] == true;
  }

  static Future<ArticleListResponse> fetchArticleBookmarks({
    int page = 1,
    int pageSize = 20,
  }) async {
    final json = await ApiClient.get(
      ApiConfig.articleBookmarks,
      query: {'page': '$page', 'page_size': '$pageSize'},
    );
    return ArticleListResponse.fromJson(json);
  }

  static Future<ArticleListResponse> fetchLikedArticles({
    int page = 1,
    int pageSize = 20,
  }) async {
    final json = await ApiClient.get(
      ApiConfig.articleLikes,
      query: {'page': '$page', 'page_size': '$pageSize'},
    );
    return ArticleListResponse.fromJson(json);
  }
}
