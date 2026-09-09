import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// 封裝 Agora RtcEngine 的初始化/加入/離開/靜音/鏡頭切換。
/// 每通通話建立一個新實例，通話結束即 dispose，不是跨畫面單例。
class AgoraCallService extends ChangeNotifier {
  RtcEngine? _engine;
  int? remoteUid;
  bool joined = false;
  bool muted = false;
  bool cameraOff = false;

  Future<void> initAndJoin({
    required String appId,
    required String token,
    required String channel,
    required int uid,
  }) async {
    final statuses = await [Permission.camera, Permission.microphone].request();
    if (statuses.values.any((s) => !s.isGranted)) {
      throw AgoraPermissionDeniedException();
    }

    final engine = createAgoraRtcEngine();
    _engine = engine;
    await engine.initialize(RtcEngineContext(appId: appId));
    await engine.enableVideo();
    engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          joined = true;
          notifyListeners();
        },
        onUserJoined: (connection, remoteUid, elapsed) {
          this.remoteUid = remoteUid;
          notifyListeners();
        },
        onUserOffline: (connection, remoteUid, reason) {
          if (this.remoteUid == remoteUid) this.remoteUid = null;
          notifyListeners();
        },
      ),
    );
    await engine.startPreview();
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

  Future<void> toggleMute() async {
    muted = !muted;
    await _engine?.muteLocalAudioStream(muted);
    notifyListeners();
  }

  Future<void> toggleCamera() async {
    cameraOff = !cameraOff;
    await _engine?.enableLocalVideo(!cameraOff);
    notifyListeners();
  }

  Widget? localView() {
    final engine = _engine;
    if (engine == null) return null;
    return AgoraVideoView(
      controller: VideoViewController(
        rtcEngine: engine,
        canvas: const VideoCanvas(uid: 0),
      ),
    );
  }

  Widget? remoteView(String channel) {
    final engine = _engine;
    final uid = remoteUid;
    if (engine == null || uid == null) return null;
    return AgoraVideoView(
      controller: VideoViewController.remote(
        rtcEngine: engine,
        canvas: VideoCanvas(uid: uid),
        connection: RtcConnection(channelId: channel),
      ),
    );
  }

  Future<void> leave() async {
    await _engine?.leaveChannel();
    await _engine?.release();
    _engine = null;
  }

  @override
  void dispose() {
    leave();
    super.dispose();
  }
}

class AgoraPermissionDeniedException implements Exception {
  @override
  String toString() => '相機或麥克風權限被拒絕';
}
