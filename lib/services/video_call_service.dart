// 1 對 1 視訊配對 API 呼叫（issue #10）。
//
// 沿用共用的 ApiClient（自動帶 JWT、401 自動導回登入、統一 {error:{code,message}}
// 錯誤解析）。對應後端 Truku_backend backend/routes/video.ts。
//
// 命名為 VideoCallService（而非 VideoService）避免與既有影音模組的
// lib/services/video_service.dart（video_models.dart / GET /api/videos，播放
// 上片影片用）撞名衝突。
//
// 端點：
//   POST   /api/video/queue              進佇列（入列即試配；配到直接回 token）
//   DELETE /api/video/queue              離開佇列
//   GET    /api/video/session/current    查我目前 active 房
//   POST   /api/video/session/:id/token  （重）取得 Agora token
//   POST   /api/video/session/:id/end    掛斷/結束（通知對方）

import '../core/constants/api.dart';
import '../core/network/api_client.dart';
import '../models/video_call_model.dart';

class VideoCallService {
  /// 進佇列（入列即試配，冪等）。matched=true 時直接可用 session/credentials
  /// 加入房間；matched=false 表示已進入等待佇列，需另外輪詢/等 FCM。
  /// 503 VIDEO_UNAVAILABLE（Agora 未設定）由 ApiException 往上拋，交呼叫端處理。
  static Future<QueueJoinResult> joinQueue() async {
    final data = await ApiClient.post(ApiConfig.videoQueue);
    return QueueJoinResult.fromJson(data);
  }

  /// 離開佇列（取消配對）。
  static Future<void> leaveQueue() async {
    await ApiClient.delete(ApiConfig.videoQueue);
  }

  /// 查詢我目前 active 且未逾時的房；沒有則回 null。
  static Future<VideoSession?> fetchCurrentSession() async {
    final data = await ApiClient.get(ApiConfig.videoSessionCurrent);
    final session = data['session'] as Map<String, dynamic>?;
    return session == null ? null : VideoSession.fromJson(session);
  }

  /// （重）取得該房的 Agora token。session 已結束或逾時時，ApiException.code
  /// 為 'SESSION_ENDED'（410），呼叫端要判斷並導離通話畫面。
  static Future<RefreshedTokenResult> refreshToken(int sessionId) async {
    final data = await ApiClient.post(ApiConfig.videoSessionToken(sessionId));
    return RefreshedTokenResult.fromJson(data);
  }

  /// 掛斷/結束通話（冪等）。成功後對方會收到 FCM video_session_ended。
  static Future<void> endSession(int sessionId) async {
    await ApiClient.post(ApiConfig.videoSessionEnd(sessionId));
  }
}
