import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/widgets.dart';

import 'video_rtc.dart';

/// Agora 實作。[release] 可能在 [start] 的 await 之間被呼叫（使用者入房途中
/// 按返回），所以每一步之後都檢查 [_released]，避免對已釋放的引擎呼叫方法。
class AgoraVideoRtc implements VideoRtc {
  RtcEngine? _engine;
  bool _released = false;

  @override
  Future<void> start({
    required String appId,
    required RtcCallbacks callbacks,
  }) async {
    final engine = createAgoraRtcEngine();
    _engine = engine;
    await engine.initialize(RtcEngineContext(appId: appId));
    if (_released) return;
    engine.registerEventHandler(
      RtcEngineEventHandler(
        onError: (err, msg) => callbacks.onError('$err $msg'),
        onJoinChannelSuccess: (_, _) => callbacks.onJoinSuccess(),
        onUserJoined: (_, remoteUid, _) => callbacks.onRemoteJoined(remoteUid),
        onUserOffline: (_, remoteUid, _) => callbacks.onRemoteLeft(remoteUid),
        onUserMuteVideo: (_, _, muted) => callbacks.onRemoteVideoMuted(muted),
        onTokenPrivilegeWillExpire: (_, _) => callbacks.onTokenWillExpire(),
      ),
    );
    await engine.enableVideo();
    if (_released) return;
    await engine.setVideoEncoderConfiguration(
      const VideoEncoderConfiguration(
        dimensions: VideoDimensions(width: 1280, height: 720),
      ),
    );
    if (_released) return;
    await engine.startPreview();
  }

  @override
  Future<void> join({
    required String token,
    required String channel,
    required int uid,
  }) async {
    final engine = _engine;
    if (engine == null || _released) return;
    await engine.joinChannel(
      token: token,
      channelId: channel,
      uid: uid,
      options: const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ),
    );
  }

  @override
  Future<void> muteAudio(bool muted) async =>
      _engine?.muteLocalAudioStream(muted);

  @override
  Future<void> muteVideo(bool muted) async =>
      _engine?.muteLocalVideoStream(muted);

  @override
  Future<void> renewToken(String token) async => _engine?.renewToken(token);

  @override
  Future<void> release() async {
    _released = true;
    final engine = _engine;
    _engine = null;
    if (engine == null) return;
    await engine.leaveChannel();
    await engine.release();
  }

  @override
  Widget localView() {
    final engine = _engine;
    if (engine == null) return const SizedBox.shrink();
    return AgoraVideoView(
      controller: VideoViewController(
        rtcEngine: engine,
        canvas: const VideoCanvas(uid: 0),
      ),
    );
  }

  @override
  Widget remoteView({required int uid, required String channel}) {
    final engine = _engine;
    if (engine == null) return const SizedBox.shrink();
    return AgoraVideoView(
      controller: VideoViewController.remote(
        rtcEngine: engine,
        canvas: VideoCanvas(uid: uid),
        connection: RtcConnection(channelId: channel),
      ),
    );
  }
}
