import '../core/constants/api.dart';
import '../core/network/api_client.dart';
import '../models/video_models.dart';

class VideoService {
  static Future<VideoListResponse> fetchVideos({
    String? category,
    String sort = 'latest',
    int page = 1,
    int pageSize = 20,
  }) async {
    final json = await ApiClient.get(
      ApiConfig.videos,
      query: {
        'category': ?category,
        'sort': sort,
        'page': '$page',
        'page_size': '$pageSize',
      },
    );
    return VideoListResponse.fromJson(json);
  }

  /// 關鍵字／時間區間／部落搜尋，三個維度皆選填、可任意組合。
  static Future<VideoListResponse> searchVideos({
    String? q,
    String? range,
    int? tribeId,
    int page = 1,
    int pageSize = 20,
  }) async {
    final trimmed = q?.trim();
    final json = await ApiClient.get(
      ApiConfig.videoSearch,
      query: {
        'q': ?(trimmed != null && trimmed.isNotEmpty ? trimmed : null),
        'range': ?range,
        'tribe_id': ?tribeId?.toString(),
        'page': '$page',
        'page_size': '$pageSize',
      },
    );
    return VideoListResponse.fromJson(json);
  }

  static Future<VideoDetail> fetchVideoDetail(int id) async {
    final json = await ApiClient.get(ApiConfig.videoDetail(id));
    return VideoDetail.fromJson(json);
  }

  /// 回傳後端算出的真實計數，呼叫端不要自行累加——樂觀更新只是暫時值。
  static Future<({bool liked, int likeCount})> likeVideo(
    int id, {
    required bool like,
  }) async {
    final path = ApiConfig.videoLike(id);
    final data = like
        ? await ApiClient.post(path)
        : await ApiClient.delete(path);
    return (
      liked: data['liked'] == true,
      likeCount: int.tryParse(data['like_count']?.toString() ?? '') ?? 0,
    );
  }

  static Future<bool> bookmarkVideo(int id, {required bool add}) async {
    final path = ApiConfig.videoBookmark(id);
    final data = add
        ? await ApiClient.post(path)
        : await ApiClient.delete(path);
    return data['bookmarked'] == true;
  }

  static Future<VideoListResponse> fetchVideoBookmarks({
    int page = 1,
    int pageSize = 20,
  }) async {
    final json = await ApiClient.get(
      ApiConfig.videoBookmarks,
      query: {'page': '$page', 'page_size': '$pageSize'},
    );
    return VideoListResponse.fromJson(json);
  }

  static Future<VideoListResponse> fetchLikedVideos({
    int page = 1,
    int pageSize = 20,
  }) async {
    final json = await ApiClient.get(
      ApiConfig.videoLikes,
      query: {'page': '$page', 'page_size': '$pageSize'},
    );
    return VideoListResponse.fromJson(json);
  }
}
