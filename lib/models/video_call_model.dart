/// 用戶間互動視訊配對的通話 session（見 Truku_backend backend/routes/video.ts）。
/// 與影音內容模組的 VideoDetail（video_models.dart）無關，命名區分避免混淆。
class VideoCallSession {
  final int id;
  final String channel;
  final int peerUid;
  final String? peerNickname;
  final DateTime expiresAt;

  const VideoCallSession({
    required this.id,
    required this.channel,
    required this.peerUid,
    required this.peerNickname,
    required this.expiresAt,
  });

  factory VideoCallSession.fromJson(Map<String, dynamic> json) {
    return VideoCallSession(
      id: json['id'] as int,
      channel: json['channel'] as String,
      peerUid: json['peer_uid'] as int,
      peerNickname: json['peer_nickname'] as String?,
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }
}

/// Agora 通話所需的 token 與加入頻道資訊。
class VideoCallToken {
  final String token;
  final String appId;
  final String channel;
  final int uid;
  final String? peerNickname;
  final DateTime expiresAt;

  const VideoCallToken({
    required this.token,
    required this.appId,
    required this.channel,
    required this.uid,
    required this.peerNickname,
    required this.expiresAt,
  });

  factory VideoCallToken.fromJson(Map<String, dynamic> json) {
    return VideoCallToken(
      token: json['token'] as String,
      appId: json['app_id'] as String,
      channel: json['channel'] as String,
      uid: json['uid'] as int,
      peerNickname: json['peer_nickname'] as String?,
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }
}

/// POST /api/video/queue 的回應：立刻配到，或先入列等待。
class VideoQueueResult {
  final bool matched;
  final VideoCallSession? session;
  final VideoCallToken? token;

  const VideoQueueResult({required this.matched, this.session, this.token});

  factory VideoQueueResult.fromJson(Map<String, dynamic> json) {
    if (json['matched'] != true) {
      return const VideoQueueResult(matched: false);
    }
    final sessionJson = json['session'] as Map<String, dynamic>;
    return VideoQueueResult(
      matched: true,
      session: VideoCallSession.fromJson(sessionJson),
      token: VideoCallToken.fromJson({
        'token': json['token'],
        'app_id': json['app_id'],
        'channel': sessionJson['channel'],
        'uid': json['uid'],
        'peer_nickname': sessionJson['peer_nickname'],
        'expires_at': sessionJson['expires_at'],
      }),
    );
  }
}
