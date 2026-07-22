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
        if (category != null) 'category': category,
        'sort': sort,
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
}
