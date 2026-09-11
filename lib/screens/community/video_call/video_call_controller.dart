// 視訊通話狀態機：權限 → 憑證 → 媒體初始化／入房（含逾時看門狗）→ 倒數 →
// 掛斷。原本全寫在 VideoCallScreen 的 State 裡、直接呼叫 Agora 與 static
// service，無法在不啟動 SDK 的情況下測試；抽出後媒體層（[VideoRtc]）、權限、
// 後端呼叫與時鐘都由建構子注入。
//
// 畫面仍負責：畫面組裝、導頁、檢舉對話框、SnackBar、FCM 回呼註冊。

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../models/video_call_model.dart';
import 'call_permissions.dart';
import 'video_rtc.dart';

class VideoCallController extends ChangeNotifier {
  final VideoSession session;
  final AgoraCallCredentials? _credentials;
  final VideoRtc _rtc;
  final Future<CallPermissionResult> Function() _requestPermissions;
  final Future<RefreshedTokenResult> Function(int sessionId) _refreshToken;

  /// 通知後端結束通話（隨機配對或定向通話由呼叫端決定打哪支 API）。
  final Future<void> Function() _notifyEnded;
  final DateTime Function() _now;
  final Duration joinTimeout;
  final Duration backendNotifyTimeout;

  /// token 續期兩次都失敗（通話可能即將中斷）。
  VoidCallback? onTokenRenewFailed;

  /// 掛斷流程（媒體已釋放、後端已通知）完成，畫面接手導頁。
  Future<void> Function()? onLeft;

  VideoCallController({
    required this.session,
    AgoraCallCredentials? credentials,
    required VideoRtc rtc,
    required Future<CallPermissionResult> Function() requestPermissions,
    required Future<RefreshedTokenResult> Function(int sessionId) refreshToken,
    required Future<void> Function() notifyEnded,
    DateTime Function()? now,
    this.joinTimeout = const Duration(seconds: 15),
    this.backendNotifyTimeout = const Duration(seconds: 5),
  }) : _credentials = credentials,
       _rtc = rtc,
       _requestPermissions = requestPermissions,
       _refreshToken = refreshToken,
       _notifyEnded = notifyEnded,
       _now = now ?? DateTime.now;

  bool _joining = true;
  String? _joinError;
  bool _permissionPermanentlyDenied = false;
  int? _remoteUid;
  bool _muted = false;
  bool _camOff = false;
  bool _remoteCamOff = false;
  bool _leaving = false;
  bool _ended = false;
  bool _mediaActive = false;
  Duration _remaining = Duration.zero;
  Timer? _countdownTimer;
  Timer? _joinWatchdog;
  bool _disposed = false;

  bool get joining => _joining;
  String? get joinError => _joinError;
  bool get permissionPermanentlyDenied => _permissionPermanentlyDenied;
  int? get remoteUid => _remoteUid;
  bool get muted => _muted;
  bool get camOff => _camOff;
  bool get remoteCamOff => _remoteCamOff;
  bool get leaving => _leaving;
  bool get ended => _ended;
  Duration get remaining => _remaining;

  /// 媒體引擎可用（可以渲染本機／遠端畫面）。
  bool get mediaActive => _mediaActive;
  VideoRtc get rtc => _rtc;

  /// 開始倒數並初始化通話。
  void start() {
    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _tickCountdown(),
    );
    _tickCountdown();
    unawaited(_setup());
  }

  Duration get _timeLeft => session.expiresAt.difference(_now().toUtc());

  /// App 回前景：計時器可能被系統暫停過，補一次到期判斷。
  void onResumed() {
    if (!_ended && _timeLeft <= Duration.zero) unawaited(hangUp());
  }

  void _tickCountdown() {
    final left = _timeLeft;
    _set(() => _remaining = left.isNegative ? Duration.zero : left);
    if (left <= Duration.zero && !_ended) unawaited(hangUp());
  }

  Future<void> _setup() async {
    final permission = await _requestPermissions();
    if (_ended) return;
    if (permission != CallPermissionResult.granted) {
      final permanent = permission == CallPermissionResult.permanentlyDenied;
      _set(() => _permissionPermanentlyDenied = permanent);
      _failJoin(permanent ? '相機或麥克風權限已被永久拒絕，請到系統設定開啟後再回來' : '需要相機與麥克風權限才能通話');
      return;
    }

    AgoraCallCredentials credentials;
    try {
      credentials = _credentials ?? await _fetchCredentials();
    } catch (e) {
      _failJoin('無法取得視訊憑證，請稍後再試');
      return;
    }
    if (_ended) return;

    // 初始化到 join 全程包 try/catch：任一步失敗（無效 token、網路中斷、SDK
    // 初始化失敗）都要有錯誤畫面與逃生路徑，不能卡在 loading。
    try {
      await _rtc.start(appId: credentials.appId, callbacks: _callbacks());
      if (_ended) return;
      _set(() => _mediaActive = true);
      // join 不保證回呼，開看門狗兜底。
      _joinWatchdog = Timer(joinTimeout, () {
        if (_joining) _failJoin('加入視訊房逾時，請檢查網路後再試一次');
      });
      await _rtc.join(
        token: credentials.token,
        channel: session.channel,
        uid: credentials.uid,
      );
    } catch (e) {
      debugPrint('VideoCallController: 媒體初始化失敗：$e');
      _failJoin('視訊初始化失敗，請稍後再試');
    }
  }

  Future<AgoraCallCredentials> _fetchCredentials() async {
    final refreshed = await _refreshToken(session.id);
    return AgoraCallCredentials(
      token: refreshed.token,
      appId: refreshed.appId,
      uid: refreshed.uid,
    );
  }

  RtcCallbacks _callbacks() => RtcCallbacks(
    onJoinSuccess: () {
      _joinWatchdog?.cancel();
      _set(() => _joining = false);
    },
    onRemoteJoined: (uid) => _set(() => _remoteUid = uid),
    // 對方畫面離開不等於通話結束；結束交給 FCM 或倒數／手動掛斷。
    onRemoteLeft: (_) => _set(() => _remoteUid = null),
    onRemoteVideoMuted: (muted) => _set(() => _remoteCamOff = muted),
    onError: (description) {
      debugPrint('VideoCallController: RTC onError $description');
      // 入房階段的錯誤轉成錯誤畫面；已接通後的暫時性錯誤交給 SDK 自行重連。
      if (_joining) _failJoin('視訊連線失敗（$description），請稍後再試');
    },
    onTokenWillExpire: () => unawaited(_renewToken()),
  );

  void _failJoin(String message) {
    _joinWatchdog?.cancel();
    if (_ended) return;
    _set(() {
      _joining = false;
      _joinError = message;
    });
  }

  /// token 續期：失敗會被踢出頻道而使用者毫無所覺，所以重試一次，
  /// 仍失敗就通知畫面告知即將斷線。
  Future<void> _renewToken() async {
    if (_ended || _timeLeft <= Duration.zero) return;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final refreshed = await _refreshToken(session.id);
        if (_ended) return;
        await _rtc.renewToken(refreshed.token);
        return;
      } catch (e) {
        debugPrint('VideoCallController: token 續期失敗（第 ${attempt + 1} 次）：$e');
      }
    }
    if (!_ended && !_disposed) onTokenRenewFailed?.call();
  }

  Future<void> toggleMute() async {
    if (!_mediaActive || _ended) return;
    final next = !_muted;
    try {
      await _rtc.muteAudio(next);
    } catch (e) {
      debugPrint('VideoCallController: 切換麥克風失敗：$e');
      return;
    }
    _set(() => _muted = next);
  }

  Future<void> toggleCamera() async {
    if (!_mediaActive || _ended) return;
    final next = !_camOff;
    try {
      await _rtc.muteVideo(next);
    } catch (e) {
      debugPrint('VideoCallController: 切換鏡頭失敗：$e');
      return;
    }
    _set(() => _camOff = next);
  }

  /// 對方結束通話（FCM）：本地清理，但不再通知後端（對方已通知過）。
  void onPeerEnded(int? sessionId) {
    if (_ended || sessionId != session.id) return;
    unawaited(_leave(notifyBackend: false));
  }

  /// 使用者掛斷、倒數到期、或錯誤畫面返回。
  Future<void> hangUp() => _leave(notifyBackend: true);

  Future<void> _leave({required bool notifyBackend}) async {
    if (_ended) return;
    _ended = true;
    _countdownTimer?.cancel();
    _joinWatchdog?.cancel();
    _set(() => _leaving = true);

    // 先停本機影音再通知後端：後端若卡住，鏡頭與麥克風不能還在送流。
    await _releaseMedia();

    if (notifyBackend) {
      try {
        await _notifyEnded().timeout(backendNotifyTimeout);
      } catch (e) {
        debugPrint('VideoCallController: 結束通話通知後端失敗（忽略）：$e');
      }
    }
    if (_disposed) return;
    await onLeft?.call();
  }

  Future<void> _releaseMedia() async {
    _set(() => _mediaActive = false);
    try {
      await _rtc.release();
    } catch (e) {
      debugPrint('VideoCallController: 釋放媒體失敗（忽略）：$e');
    }
  }

  void _set(VoidCallback change) {
    if (_disposed) return;
    change();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _countdownTimer?.cancel();
    _joinWatchdog?.cancel();
    // 正常流程都走 _leave；這裡只兜底（手勢／系統返回繞過 PopScope），
    // 避免媒體資源洩漏。release() 可重複呼叫。
    if (!_ended) {
      _ended = true;
      unawaited(
        _rtc.release().catchError((Object e) {
          debugPrint('VideoCallController: dispose 釋放媒體失敗（忽略）：$e');
        }),
      );
    }
    super.dispose();
  }
}
