import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/screens/community/video_call/agora_video_rtc.dart';
import 'package:flutter_application_1/screens/community/video_call/video_rtc.dart';

/// 記錄呼叫順序的假引擎；用不到的方法交給 noSuchMethod。
class _FakeEngine implements RtcEngine {
  final List<String> log = [];
  final Completer<void> initGate = Completer<void>();
  Object? leaveError;

  @override
  Future<void> initialize(RtcEngineContext context) async {
    log.add('initialize');
    await initGate.future;
  }

  @override
  Future<void> leaveChannel({LeaveChannelOptions? options}) async {
    log.add('leaveChannel');
    if (leaveError != null) throw leaveError!;
  }

  @override
  Future<void> release({bool sync = false}) async => log.add('release');

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

RtcCallbacks _callbacks() => RtcCallbacks(
  onJoinSuccess: () {},
  onRemoteJoined: (_) {},
  onRemoteLeft: (_, _) {},
  onRemoteVideoMuted: (_) {},
  onError: (_) {},
  onTokenWillExpire: () {},
);

void main() {
  test('initialize 還沒完成就掛斷、leaveChannel 丟例外時仍會 release 引擎', () async {
    final engine = _FakeEngine()
      ..leaveError = AgoraRtcException(code: -7);
    final rtc = AgoraVideoRtc(createEngine: () => engine);

    final started = rtc.start(appId: 'app', callbacks: _callbacks());
    await rtc.release();
    engine.initGate.complete();
    await started;

    expect(engine.log, ['initialize', 'leaveChannel', 'release']);
  });

  test('正常通話中掛斷：先 leaveChannel 再 release', () async {
    final engine = _FakeEngine()..initGate.complete();
    final rtc = AgoraVideoRtc(createEngine: () => engine);

    await rtc.start(appId: 'app', callbacks: _callbacks());
    await rtc.join(token: 't', channel: 'c', uid: 1);
    engine.log.clear();
    await rtc.release();

    expect(engine.log, ['leaveChannel', 'release']);
  });
}
