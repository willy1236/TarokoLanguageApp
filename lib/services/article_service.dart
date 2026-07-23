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
        if (category != null) 'category': category,
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
}
