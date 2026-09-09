import '../core/constants/api.dart';
import '../core/network/api_client.dart';
import '../models/video_call_model.dart';

/// 用戶間互動視訊配對（見 Truku_backend backend/routes/video.ts）。
/// 只負責 REST 端的配對/session/token；Agora 引擎操作見 AgoraCallService。
class VideoCallService {
  static Future<VideoQueueResult> joinQueue() async {
    final json = await ApiClient.post(ApiConfig.videoQueue);
    return VideoQueueResult.fromJson(json);
  }

  static Future<void> leaveQueue() async {
    await ApiClient.delete(ApiConfig.videoQueue);
  }

  static Future<VideoCallSession?> getCurrentSession() async {
    final json = await ApiClient.get(ApiConfig.videoSessionCurrent);
    final sessionJson = json['session'] as Map<String, dynamic>?;
    if (sessionJson == null) return null;
    return VideoCallSession.fromJson(sessionJson);
  }

  static Future<VideoCallToken> getToken(int sessionId) async {
    final json = await ApiClient.post(ApiConfig.videoSessionToken(sessionId));
    return VideoCallToken.fromJson(json);
  }

  static Future<void> endSession(int sessionId) async {
    await ApiClient.post(ApiConfig.videoSessionEnd(sessionId));
  }
}
