// 通話媒體層的抽象：VideoCallController 只依賴這個介面，正式執行用
// AgoraVideoRtc（agora_video_rtc.dart），測試換成假實作，不必啟動真正的 SDK。

import 'package:flutter/widgets.dart';

/// SDK 事件。全部在 [VideoRtc.start] 時註冊。
class RtcCallbacks {
  final VoidCallback onJoinSuccess;
  final ValueChanged<int> onRemoteJoined;
  final ValueChanged<int> onRemoteLeft;
  final ValueChanged<bool> onRemoteVideoMuted;

  /// SDK 回報錯誤（參數為給除錯用的錯誤碼描述）。
  final ValueChanged<String> onError;
  final VoidCallback onTokenWillExpire;

  const RtcCallbacks({
    required this.onJoinSuccess,
    required this.onRemoteJoined,
    required this.onRemoteLeft,
    required this.onRemoteVideoMuted,
    required this.onError,
    required this.onTokenWillExpire,
  });
}

abstract class VideoRtc {
  /// 建立引擎、註冊事件、開啟視訊並開始本機預覽。
  Future<void> start({required String appId, required RtcCallbacks callbacks});

  Future<void> join({
    required String token,
    required String channel,
    required int uid,
  });

  Future<void> muteAudio(bool muted);
  Future<void> muteVideo(bool muted);
  Future<void> renewToken(String token);

  /// 離開頻道並釋放引擎。可重複呼叫；[start] 進行中呼叫也要能安全中止。
  Future<void> release();

  Widget localView();
  Widget remoteView({required int uid, required String channel});
}
