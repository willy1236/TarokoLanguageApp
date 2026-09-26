import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/video_models.dart';

void main() {
  Map<String, dynamic> base() => {
    'id': 5,
    'title': '太魯閣族',
    'category': 'cultural',
    'view_count': 0,
    'weekly_view_count': 0,
  };

  test('YouTube 影片：hls_url／duration_sec 為 null，解析 youtube 物件', () {
    final v = VideoDetail.fromJson({
      ...base(),
      'source': 'youtube',
      'hls_url': null,
      'duration_sec': null,
      'thumbnail_url': 'https://i.ytimg.com/vi/g4KvRyUVTxE/hqdefault.jpg',
      'youtube': {
        'video_id': 'g4KvRyUVTxE',
        'embed_url': 'https://www.youtube.com/embed/g4KvRyUVTxE',
        'watch_url': 'https://www.youtube.com/watch?v=g4KvRyUVTxE',
        'embeddable': false,
      },
    });
    expect(v.isYoutube, isTrue);
    expect(v.hlsUrl, isNull);
    expect(v.durationSec, isNull);
    expect(v.youtube!.videoId, 'g4KvRyUVTxE');
    expect(v.youtube!.watchUrl, 'https://www.youtube.com/watch?v=g4KvRyUVTxE');
    expect(v.youtube!.embeddable, isFalse);
    // 樂觀更新不可弄丟來源資訊。
    expect(v.toggledLike().youtube, isNotNull);
    expect(v.toggledLike().isYoutube, isTrue);
  });

  test('沒有 source 的舊回應視為自家 HLS 影片', () {
    final v = VideoDetail.fromJson({
      ...base(),
      'hls_url': 'https://cdn/x.m3u8',
    });
    expect(v.isYoutube, isFalse);
    expect(v.hlsUrl, 'https://cdn/x.m3u8');
    expect(v.youtube, isNull);
  });

  test('清單項目帶 source', () {
    final v = VideoSummary.fromJson({...base(), 'source': 'youtube'});
    expect(v.isYoutube, isTrue);
  });
}
