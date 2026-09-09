// 定向通話：撥給指定好友（見 Truku_backend backend/routes/friendCalls.ts）。
// 接通後複用既有 video_sessions／Agora，撥出方接通後用既有 VideoCallService.getToken
// 取得自己的 token；被叫方 accept 端點直接回自己的 session+token。

import '../core/constants/api.dart';
import '../core/network/api_client.dart';
import '../models/friend_model.dart';
import '../models/video_call_model.dart';

class DirectedCallService {
  /// 撥號給好友，回傳新建（或既有響鈴中同一通）的 call id。
  static Future<int> callFriend(int uid) async {
    final data = await ApiClient.post(ApiConfig.friendCall(uid));
    return (data['call_id'] as num).toInt();
  }

  static Future<DirectedCallStatus> getCall(int callId) async {
    final data = await ApiClient.get(ApiConfig.friendCallDetail(callId));
    return DirectedCallStatus.fromJson(data);
  }

  static Future<List<IncomingCall>> getIncomingCalls() async {
    final data = await ApiClient.get(ApiConfig.friendCallsIncoming);
    return ApiClient.unwrapList(data, 'incoming')
        .map((e) => IncomingCall.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 被叫方接聽，回傳可直接進通話畫面的 session + token。
  static Future<(VideoCallSession, VideoCallToken)> acceptCall(int callId) async {
    final data = await ApiClient.post(ApiConfig.friendCallAccept(callId));
    final sessionJson = data['session'] as Map<String, dynamic>;
    final session = VideoCallSession.fromJson(sessionJson);
    final token = VideoCallToken.fromJson({
      'token': data['token'],
      'app_id': data['app_id'],
      'channel': sessionJson['channel'],
      'uid': data['uid'],
      'peer_nickname': sessionJson['peer_nickname'],
      'expires_at': sessionJson['expires_at'],
    });
    return (session, token);
  }

  static Future<void> declineCall(int callId) async {
    await ApiClient.post(ApiConfig.friendCallDecline(callId));
  }

  static Future<void> cancelCall(int callId) async {
    await ApiClient.post(ApiConfig.friendCallCancel(callId));
  }

  static Future<void> endCall(int callId) async {
    await ApiClient.post(ApiConfig.friendCallEnd(callId));
  }

  /// 檢舉一通我參與過的通話，reason 為 1-500 字的檢舉原因。
  static Future<void> reportCall(int callId, String reason) async {
    await ApiClient.post(ApiConfig.friendCallReport(callId), {'reason': reason});
  }
}
