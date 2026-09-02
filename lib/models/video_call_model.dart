// 對應 video_queue / video_sessions 資料表，以及
// POST /api/video/queue、GET /api/video/session/current、
// POST /api/video/session/:id/token 回傳 JSON。
// 後端規格：Truku_backend backend/routes/video.ts
//
// 後端回傳為 snake_case，這裡轉成 Dart 慣用的 camelCase。id/uid 數字欄位沿用
// event_model.dart 的 asEventInt() 容錯解析（後端偶爾把 bigint 序列化成字串）。

import 'event_model.dart' show asEventInt;

/// 一次配對成立的通話房。peerNickname 為對方的視訊暱稱；理論上配對雙方都已
/// 必填視訊暱稱才能入列，但仍保留 null 容錯，顯示端 fallback 用通用「語伴」文案。
class VideoSession {
  final int id;
  final String channel;
  final int peerUid;
  final String? peerNickname;
  final DateTime expiresAt; // 通話硬上限（token 效期即為此時間）

  const VideoSession({
    required this.id,
    required this.channel,
    required this.peerUid,
    this.peerNickname,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAt);

  factory VideoSession.fromJson(Map<String, dynamic> json) {
    return VideoSession(
      id: asEventInt(json['id'])!,
      channel: json['channel'] as String,
      peerUid: asEventInt(json['peer_uid'])!,
      peerNickname: json['peer_nickname'] as String?,
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }
}

/// POST /api/video/queue 配對成功時，平鋪於回應外層的 Agora 加入房間憑證。
class AgoraCallCredentials {
  final String token;
  final String appId;
  final int uid;

  const AgoraCallCredentials({
    required this.token,
    required this.appId,
    required this.uid,
  });

  factory AgoraCallCredentials.fromJson(Map<String, dynamic> json) {
    return AgoraCallCredentials(
      token: json['token'] as String,
      appId: json['app_id'] as String,
      uid: asEventInt(json['uid'])!,
    );
  }
}

/// POST /api/video/queue 的回應：配到直接回 session + token，否則進入等待佇列。
class QueueJoinResult {
  final bool matched;
  final VideoSession? session;
  final AgoraCallCredentials? credentials;

  const QueueJoinResult({
    required this.matched,
    this.session,
    this.credentials,
  });

  factory QueueJoinResult.fromJson(Map<String, dynamic> json) {
    final matched = json['matched'] as bool? ?? false;
    if (!matched) return const QueueJoinResult(matched: false);
    return QueueJoinResult(
      matched: true,
      session: VideoSession.fromJson(json['session'] as Map<String, dynamic>),
      credentials: AgoraCallCredentials.fromJson(json),
    );
  }
}

/// POST /api/video/session/:id/token 的回應（重新取得/續期 token）。
/// 欄位與 AgoraCallCredentials 重疊但多出 channel/expiresAt，獨立建型別
/// 避免語意混淆。
class RefreshedTokenResult {
  final String token;
  final String appId;
  final String channel;
  final int uid;
  final DateTime expiresAt;

  const RefreshedTokenResult({
    required this.token,
    required this.appId,
    required this.channel,
    required this.uid,
    required this.expiresAt,
  });

  factory RefreshedTokenResult.fromJson(Map<String, dynamic> json) {
    return RefreshedTokenResult(
      token: json['token'] as String,
      appId: json['app_id'] as String,
      channel: json['channel'] as String,
      uid: asEventInt(json['uid'])!,
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }
}
