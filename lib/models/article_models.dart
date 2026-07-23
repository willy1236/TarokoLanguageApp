// 對應文章模組 API：GET /api/articles、GET /api/articles/:id
// 規格：Truku_backend/說明文件/API/文章模組.md

class ArticleCategory {
  static const tribalIntro = 'tribal_intro';
  static const cultural = 'cultural';
  static const event = 'event';
  static const education = 'education';
  static const other = 'other';

  static const all = [tribalIntro, cultural, event, education, other];

  static String label(String category) {
    switch (category) {
      case tribalIntro:
        return '部落宣傳';
      case cultural:
        return '文化紀錄';
      case event:
        return '活動紀錄';
      case education:
        return '教學延伸';
      default:
        return '其他';
    }
  }
}

class ArticleSummary {
  final int id;
  final String title;
  final String? summary;
  final String? coverImageUrl;
  final String category;
  final int viewCount;
  final int weeklyViewCount;
  final DateTime? publishedAt;

  const ArticleSummary({
    required this.id,
    required this.title,
    this.summary,
    this.coverImageUrl,
    required this.category,
    required this.viewCount,
    required this.weeklyViewCount,
    this.publishedAt,
  });

  factory ArticleSummary.fromJson(Map<String, dynamic> json) {
    return ArticleSummary(
      id: json['id'] as int,
      title: json['title'] as String,
      summary: json['summary'] as String?,
      coverImageUrl: json['cover_image_url'] as String?,
      category: json['category'] as String,
      viewCount: json['view_count'] as int? ?? 0,
      weeklyViewCount: json['weekly_view_count'] as int? ?? 0,
      publishedAt: json['published_at'] != null
          ? DateTime.tryParse(json['published_at'] as String)
          : null,
    );
  }
}

class ArticleDetail extends ArticleSummary {
  final String contentMd;
  final DateTime? createdAt;

  const ArticleDetail({
    required super.id,
    required super.title,
    super.summary,
    super.coverImageUrl,
    required super.category,
    required super.viewCount,
    required super.weeklyViewCount,
    super.publishedAt,
    required this.contentMd,
    this.createdAt,
  });

  factory ArticleDetail.fromJson(Map<String, dynamic> json) {
    return ArticleDetail(
      id: json['id'] as int,
      title: json['title'] as String,
      summary: json['summary'] as String?,
      coverImageUrl: json['cover_image_url'] as String?,
      category: json['category'] as String,
      viewCount: json['view_count'] as int? ?? 0,
      weeklyViewCount: json['weekly_view_count'] as int? ?? 0,
      publishedAt: json['published_at'] != null
          ? DateTime.tryParse(json['published_at'] as String)
          : null,
      contentMd: json['content_md'] as String,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }
}

class ArticleListResponse {
  final int total;
  final int page;
  final int pageSize;
  final String sort;
  final List<ArticleSummary> articles;

  const ArticleListResponse({
    required this.total,
    required this.page,
    required this.pageSize,
    required this.sort,
    required this.articles,
  });

  factory ArticleListResponse.fromJson(Map<String, dynamic> json) {
    final list = json['articles'] as List<dynamic>? ?? [];
    return ArticleListResponse(
      total: json['total'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      pageSize: json['page_size'] as int? ?? 20,
      sort: json['sort'] as String? ?? 'latest',
      articles: list
          .cast<Map<String, dynamic>>()
          .map(ArticleSummary.fromJson)
          .toList(),
    );
  }
}
