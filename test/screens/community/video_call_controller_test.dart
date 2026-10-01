import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/video_call_model.dart';
import 'package:flutter_application_1/screens/community/video_call/call_permissions.dart';
import 'package:flutter_application_1/screens/community/video_call/video_call_controller.dart';
import 'package:flutter_application_1/screens/community/video_call/video_rtc.dart';

/// 記錄呼叫順序的假媒體層。
class FakeRtc implements VideoRtc {
  final List<String> log;
  RtcCallbacks? callbacks;
  Object? startError;
  Completer<void>? startGate;

  FakeRtc(this.log);

  @override
  Future<void> start({
    required String appId,
    required RtcCallbacks callbacks,
  }) async {
    log.add('rtc.start');
    this.callbacks = callbacks;
    if (startGate != null) await startGate!.future;
    if (startError != null) throw startError!;
  }

  @override
  Future<void> join({
    required String token,
    required String channel,
    required int uid,
  }) async => log.add('rtc.join:$token');

  @override
  Future<void> muteAudio(bool muted) async => log.add('rtc.muteAudio:$muted');

  @override
  Future<void> muteVideo(bool muted) async => log.add('rtc.muteVideo:$muted');

  @override
  Future<void> renewToken(String token) async => log.add('rtc.renew:$token');

  @override
  Future<void> release() async => log.add('rtc.release');

  @override
  Widget localView() => const SizedBox();

  @override
  Widget remoteView({required int uid, required String channel}) =>
      const SizedBox();
}

final _t0 = DateTime.utc(2026, 9, 11, 12);

class _Harness {
  final log = <String>[];
  late final FakeRtc rtc = FakeRtc(log);
  CallPermissionResult permission = CallPermissionResult.granted;
  Object? refreshError;
  Completer<void>? endGate;

  /// 後端回報的通話狀態；[serverGate] 不為 null 時查詢會卡住直到完成。
  bool serverEnded = false;
  Object? serverError;
  Completer<void>? serverGate;
  DateTime now = _t0;
  int leftCount = 0;
  int renewFailedCount = 0;
  late final VideoCallController call;

  _Harness({
    AgoraCallCredentials? credentials = const AgoraCallCredentials(
      token: 'tok',
      appId: 'app',
      uid: 7,
    ),
    Duration callLength = const Duration(minutes: 30),
  }) {
    call =
        VideoCallController(
            session: VideoSession(
              id: 1,
              channel: 'ch',
              peerFriendCode: 'BBBB2345',
              expiresAt: _t0.add(callLength),
            ),
            credentials: credentials,
            rtc: rtc,
            requestPermissions: () async => permission,
            refreshToken: (id) async {
              log.add('backend.refresh');
              if (refreshError != null) throw refreshError!;
              return RefreshedTokenResult(
                expiresAt: _t0.add(const Duration(minutes: 30)),
                token: 'new',
                appId: 'app',
                channel: 'ch',
                uid: 7,
              );
            },
            notifyEnded: () async {
              log.add('backend.end');
              if (endGate != null) await endGate!.future;
            },
            isEndedOnServer: () async {
              log.add('backend.status');
              if (serverGate != null) await serverGate!.future;
              if (serverError != null) throw serverError!;
              return serverEnded;
            },
            now: () => now,
          )
          ..onLeft = () async {
            leftCount++;
          }
          ..onTokenRenewFailed = () => renewFailedCount++;
  }
}

void main() {
  test('正常入房：啟動媒體、加入頻道，收到成功回呼後不再 joining', () {
    fakeAsync((async) {
      final h = _Harness();
      h.call.start();
      async.flushMicrotasks();
      expect(h.log, ['rtc.start', 'rtc.join:tok']);
      expect(h.call.mediaActive, isTrue);
      expect(h.call.joining, isTrue);
      h.rtc.callbacks!.onJoinSuccess();
      h.rtc.callbacks!.onRemoteJoined(9);
      expect(h.call.joining, isFalse);
      expect(h.call.remoteUid, 9);
      // 看門狗已取消，逾時後也不會出錯誤
      async.elapse(const Duration(seconds: 20));
      expect(h.call.joinError, isNull);
      h.call.dispose();
    });
  });

  test('沒帶憑證時先向後端取 token', () {
    fakeAsync((async) {
      final h = _Harness(credentials: null);
      h.call.start();
      async.flushMicrotasks();
      expect(h.log, ['backend.refresh', 'rtc.start', 'rtc.join:new']);
      h.call.dispose();
    });
  });

  test('權限被拒／永久拒絕：顯示錯誤、不啟動媒體', () {
    fakeAsync((async) {
      final h = _Harness()..permission = CallPermissionResult.denied;
      h.call.start();
      async.flushMicrotasks();
      expect(h.call.joinError, '需要相機與麥克風權限才能通話');
      expect(h.call.permissionPermanentlyDenied, isFalse);
      expect(h.log, isEmpty);
      h.call.dispose();

      final p = _Harness()..permission = CallPermissionResult.permanentlyDenied;
      p.call.start();
      async.flushMicrotasks();
      expect(p.call.permissionPermanentlyDenied, isTrue);
      p.call.dispose();
    });
  });

  test('媒體初始化失敗：顯示錯誤，掛斷時仍會釋放', () {
    fakeAsync((async) {
      final h = _Harness();
      h.rtc.startError = StateError('sdk');
      h.call.start();
      async.flushMicrotasks();
      expect(h.call.joinError, '視訊初始化失敗，請稍後再試');
      expect(h.call.joining, isFalse);
      h.call.hangUp();
      async.flushMicrotasks();
      expect(h.log, ['rtc.start', 'rtc.release', 'backend.end']);
      expect(h.leftCount, 1);
      h.call.dispose();
    });
  });

  test('入房逾時：看門狗觸發錯誤', () {
    fakeAsync((async) {
      final h = _Harness();
      h.call.start();
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 15));
      expect(h.call.joinError, '加入視訊房逾時，請檢查網路後再試一次');
      h.call.dispose();
    });
  });

  test('入房途中掛斷：不再呼叫 join', () {
    fakeAsync((async) {
      final h = _Harness();
      h.rtc.startGate = Completer<void>();
      h.call.start();
      async.flushMicrotasks();
      h.call.hangUp();
      async.flushMicrotasks();
      h.rtc.startGate!.complete();
      async.flushMicrotasks();
      expect(h.log, ['rtc.start', 'rtc.release', 'backend.end']);
      expect(h.call.mediaActive, isFalse);
      h.call.dispose();
    });
  });

  test('掛斷：先釋放媒體再通知後端；後端卡住時逾時仍離開', () {
    fakeAsync((async) {
      final h = _Harness()..endGate = Completer<void>();
      h.call.start();
      async.flushMicrotasks();
      h.call.hangUp();
      async.flushMicrotasks();
      expect(h.log.sublist(2), ['rtc.release', 'backend.end']);
      expect(h.call.leaving, isTrue);
      expect(h.leftCount, 0);
      async.elapse(const Duration(seconds: 5));
      expect(h.leftCount, 1);
      // 重複掛斷不重跑流程
      h.call.hangUp();
      async.flushMicrotasks();
      expect(h.log.where((e) => e == 'backend.end'), hasLength(1));
      h.call.dispose();
    });
  });

  test('對方掛斷：清理但不通知後端；其他 session 的通知忽略', () {
    fakeAsync((async) {
      final h = _Harness();
      h.call.start();
      async.flushMicrotasks();
      h.call.onPeerEnded(99);
      async.flushMicrotasks();
      expect(h.call.ended, isFalse);
      h.call.onPeerEnded(1);
      async.flushMicrotasks();
      expect(h.log, ['rtc.start', 'rtc.join:tok', 'rtc.release']);
      expect(h.leftCount, 1);
      h.call.dispose();
    });
  });

  test('後端已結束（自己封鎖對方）：釋放媒體、不通知後端', () {
    fakeAsync((async) {
      final h = _Harness();
      h.call.start();
      async.flushMicrotasks();
      h.call.leaveEndedByServer();
      async.flushMicrotasks();
      expect(h.log, ['rtc.start', 'rtc.join:tok', 'rtc.release']);
      expect(h.leftCount, 1);
      h.call.dispose();
    });
  });

  group('對方離開頻道', () {
    /// 入房並看到對方，回傳 harness；log 只留之後的紀錄。
    _Harness joined(FakeAsync async) {
      final h = _Harness();
      h.call.start();
      async.flushMicrotasks();
      h.rtc.callbacks!.onJoinSuccess();
      h.rtc.callbacks!.onRemoteJoined(9);
      h.log.clear();
      return h;
    }

    test('主動離開且後端已結束：本地離開、不通知後端', () {
      fakeAsync((async) {
        final h = joined(async)..serverEnded = true;
        h.rtc.callbacks!.onRemoteLeft(9, RemoteLeftReason.quit);
        async.flushMicrotasks();
        expect(h.log, ['backend.status', 'rtc.release']);
        expect(h.leftCount, 1);
        h.call.dispose();
      });
    });

    test('主動離開但後端還沒結束：隔一段時間再查一次', () {
      fakeAsync((async) {
        final h = joined(async);
        h.rtc.callbacks!.onRemoteLeft(9, RemoteLeftReason.quit);
        async.flushMicrotasks();
        expect(h.log, ['backend.status']);
        expect(h.call.ended, isFalse);
        h.serverEnded = true;
        async.elapse(const Duration(seconds: 5));
        expect(h.log, ['backend.status', 'backend.status', 'rtc.release']);
        expect(h.leftCount, 1);
        h.call.dispose();
      });
    });

    test('斷線後 15 秒內回來：不查狀態、通話繼續', () {
      fakeAsync((async) {
        final h = joined(async)..serverEnded = true;
        h.rtc.callbacks!.onRemoteLeft(9, RemoteLeftReason.dropped);
        async.elapse(const Duration(seconds: 10));
        h.rtc.callbacks!.onRemoteJoined(9);
        async.elapse(const Duration(seconds: 30));
        expect(h.log, isEmpty);
        expect(h.call.remoteUid, 9);
        h.call.dispose();
      });
    });

    test('斷線超過 15 秒：查一次，後端仍通話中就留著', () {
      fakeAsync((async) {
        final h = joined(async);
        h.rtc.callbacks!.onRemoteLeft(9, RemoteLeftReason.dropped);
        async.elapse(const Duration(seconds: 14));
        expect(h.log, isEmpty);
        async.elapse(const Duration(seconds: 1));
        expect(h.log, ['backend.status']);
        async.elapse(const Duration(minutes: 1));
        expect(h.log, ['backend.status']);
        expect(h.call.ended, isFalse);
        h.call.dispose();
      });
    });

    test('查狀態失敗：不退出', () {
      fakeAsync((async) {
        final h = joined(async)..serverError = StateError('offline');
        h.rtc.callbacks!.onRemoteLeft(9, RemoteLeftReason.dropped);
        async.elapse(const Duration(seconds: 15));
        expect(h.log, ['backend.status']);
        expect(h.call.ended, isFalse);
        expect(h.leftCount, 0);
        h.call.dispose();
      });
    });

    test('查詢途中推播已結束通話：只離開一次', () {
      fakeAsync((async) {
        final h = joined(async)
          ..serverEnded = true
          ..serverGate = Completer<void>();
        h.rtc.callbacks!.onRemoteLeft(9, RemoteLeftReason.quit);
        async.flushMicrotasks();
        h.call.onPeerEnded(1);
        async.flushMicrotasks();
        h.serverGate!.complete();
        async.flushMicrotasks();
        expect(h.log.where((e) => e == 'rtc.release'), hasLength(1));
        expect(h.leftCount, 1);
        h.call.dispose();
      });
    });

    test('查詢途中對方又進出頻道：舊查詢作廢，照新的斷線寬限再查', () {
      fakeAsync((async) {
        final h = joined(async)..serverGate = Completer<void>();
        h.rtc.callbacks!.onRemoteLeft(9, RemoteLeftReason.quit);
        async.flushMicrotasks();
        h.rtc.callbacks!.onRemoteJoined(9);
        h.rtc.callbacks!.onRemoteLeft(9, RemoteLeftReason.dropped);
        h.serverGate!.complete();
        h.serverGate = null;
        async.flushMicrotasks();
        expect(h.log, ['backend.status']);
        // 舊查詢不排 5 秒後的重查，等到斷線滿 15 秒才查。
        async.elapse(const Duration(seconds: 14));
        expect(h.log, ['backend.status']);
        async.elapse(const Duration(seconds: 1));
        expect(h.log, ['backend.status', 'backend.status']);
        h.call.dispose();
      });
    });

    test('查詢途中對方回到頻道：後端未結束就不再重查', () {
      fakeAsync((async) {
        final h = joined(async)..serverGate = Completer<void>();
        h.rtc.callbacks!.onRemoteLeft(9, RemoteLeftReason.quit);
        async.flushMicrotasks();
        h.rtc.callbacks!.onRemoteJoined(9);
        h.serverGate!.complete();
        async.flushMicrotasks();
        async.elapse(const Duration(minutes: 1));
        expect(h.log, ['backend.status']);
        expect(h.call.ended, isFalse);
        h.call.dispose();
      });
    });

    test('查詢途中對方又進出頻道，後端已結束：照樣離開', () {
      fakeAsync((async) {
        final h = joined(async)
          ..serverEnded = true
          ..serverGate = Completer<void>();
        h.rtc.callbacks!.onRemoteLeft(9, RemoteLeftReason.quit);
        async.flushMicrotasks();
        h.rtc.callbacks!.onRemoteJoined(9);
        h.rtc.callbacks!.onRemoteLeft(9, RemoteLeftReason.dropped);
        h.serverGate!.complete();
        async.flushMicrotasks();
        expect(h.leftCount, 1);
        // 離開時取消斷線計時器，不會再查。
        async.elapse(const Duration(seconds: 30));
        expect(h.log, ['backend.status', 'rtc.release']);
        h.call.dispose();
      });
    });

    test('其他原因（例如轉為觀眾）只清掉對方畫面', () {
      fakeAsync((async) {
        final h = joined(async)..serverEnded = true;
        h.rtc.callbacks!.onRemoteLeft(9, RemoteLeftReason.other);
        async.elapse(const Duration(seconds: 30));
        expect(h.log, isEmpty);
        expect(h.call.remoteUid, isNull);
        h.call.dispose();
      });
    });
  });

  test('倒數到期自動掛斷', () {
    fakeAsync((async) {
      final h = _Harness(callLength: const Duration(seconds: 3));
      h.call.start();
      async.flushMicrotasks();
      expect(h.call.remaining, const Duration(seconds: 3));
      h.now = _t0.add(const Duration(seconds: 3));
      async.elapse(const Duration(seconds: 1));
      expect(h.call.ended, isTrue);
      expect(h.log, contains('backend.end'));
      h.call.dispose();
    });
  });

  test('回前景時已過期則掛斷', () {
    fakeAsync((async) {
      final h = _Harness();
      h.call.start();
      async.flushMicrotasks();
      h.call.onResumed();
      expect(h.call.ended, isFalse);
      h.now = _t0.add(const Duration(minutes: 31));
      h.call.onResumed();
      async.flushMicrotasks();
      expect(h.call.ended, isTrue);
      h.call.dispose();
    });
  });

  test('token 續期：成功更新；兩次失敗觸發回呼', () {
    fakeAsync((async) {
      final h = _Harness();
      h.call.start();
      async.flushMicrotasks();
      h.rtc.callbacks!.onTokenWillExpire();
      async.flushMicrotasks();
      expect(h.log, contains('rtc.renew:new'));
      expect(h.renewFailedCount, 0);

      h.refreshError = StateError('offline');
      h.rtc.callbacks!.onTokenWillExpire();
      async.flushMicrotasks();
      expect(h.log.where((e) => e == 'backend.refresh'), hasLength(3));
      expect(h.renewFailedCount, 1);
      h.call.dispose();
    });
  });

  test('靜音／關鏡頭切換', () {
    fakeAsync((async) {
      final h = _Harness();
      h.call.toggleMute(); // 媒體尚未啟動時忽略
      async.flushMicrotasks();
      expect(h.call.muted, isFalse);
      h.call.start();
      async.flushMicrotasks();
      h.call.toggleMute();
      h.call.toggleCamera();
      async.flushMicrotasks();
      expect(h.call.muted, isTrue);
      expect(h.call.camOff, isTrue);
      h.call.dispose();
    });
  });

  test('未掛斷就 dispose 時兜底釋放媒體', () {
    fakeAsync((async) {
      final h = _Harness();
      h.call.start();
      async.flushMicrotasks();
      h.call.dispose();
      async.flushMicrotasks();
      expect(h.log.last, 'rtc.release');
      expect(h.log, isNot(contains('backend.end')));
    });
  });
}
