// 對應影音模組 API：GET /api/videos、GET /api/videos/:id
// 規格：API設計/資料交換表_影音模組.md v0.4

class VideoCategory {
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

class VideoSummary {
  final int id;
  final String title;
  final String? description;
  final String category;
  final int? durationSec;
  final String? thumbnailUrl;
  final int viewCount;
  final DateTime? publishedAt;

  const VideoSummary({
    required this.id,
    required this.title,
    this.description,
    required this.category,
    this.durationSec,
    this.thumbnailUrl,
    required this.viewCount,
    this.publishedAt,
  });

  factory VideoSummary.fromJson(Map<String, dynamic> json) {
    return VideoSummary(
      id: json['id'] as int,
      title: json['title'] as String,
      description: json['description'] as String?,
      category: json['category'] as String,
      durationSec: json['duration_sec'] as int?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      viewCount: json['view_count'] as int? ?? 0,
      publishedAt: json['published_at'] != null
          ? DateTime.tryParse(json['published_at'] as String)
          : null,
    );
  }
}

class VideoDetail extends VideoSummary {
  final String hlsUrl;
  final int? originalSizeMb;

  const VideoDetail({
    required super.id,
    required super.title,
    super.description,
    required super.category,
    super.durationSec,
    super.thumbnailUrl,
    required super.viewCount,
    super.publishedAt,
    required this.hlsUrl,
    this.originalSizeMb,
  });

  factory VideoDetail.fromJson(Map<String, dynamic> json) {
    return VideoDetail(
      id: json['id'] as int,
      title: json['title'] as String,
      description: json['description'] as String?,
      category: json['category'] as String,
      durationSec: json['duration_sec'] as int?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      viewCount: json['view_count'] as int? ?? 0,
      publishedAt: json['published_at'] != null
          ? DateTime.tryParse(json['published_at'] as String)
          : null,
      hlsUrl: json['hls_url'] as String,
      originalSizeMb: json['original_size_mb'] as int?,
    );
  }
}

class VideoListResponse {
  final int total;
  final int page;
  final int pageSize;
  final String sort;
  final List<VideoSummary> videos;

  const VideoListResponse({
    required this.total,
    required this.page,
    required this.pageSize,
    required this.sort,
    required this.videos,
  });

  factory VideoListResponse.fromJson(Map<String, dynamic> json) {
    final list = json['videos'] as List<dynamic>? ?? [];
    return VideoListResponse(
      total: json['total'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      pageSize: json['page_size'] as int? ?? 20,
      sort: json['sort'] as String? ?? 'latest',
      videos: list
          .cast<Map<String, dynamic>>()
          .map(VideoSummary.fromJson)
          .toList(),
    );
  }
}
