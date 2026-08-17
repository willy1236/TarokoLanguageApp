import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/constants/app_colors.dart';
import '../../models/video_call_model.dart';
import '../../services/fcm_service.dart';
import '../../services/video_call_service.dart';
import '../../shared/widgets/truku_painters.dart';

/// 通話畫面。[credentials] 可為 null（例如從 VideoWaitingScreen 輪詢配到時，
/// GET /session/current 只回 session、沒有 token）——此時 initState 會自行呼叫
/// VideoCallService.refreshToken 取得 Agora 憑證。
class VideoCallScreen extends StatefulWidget {
  final VideoSession session;
  final AgoraCallCredentials? credentials;

  const VideoCallScreen({
    super.key,
    required this.session,
    this.credentials,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen>
    with WidgetsBindingObserver {
  late VideoSession _session;
  RtcEngine? _engine;
  int? _remoteUid;
  bool _ended = false;
  bool _joining = true;
  bool _muted = false;
  bool _camOff = false;
  bool _remoteCamOff = false;
  String? _joinError;
  Timer? _countdownTimer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    WidgetsBinding.instance.addObserver(this);
    FcmService.onVideoSessionEnded = _onPeerEnded;
    _countdownTimer =
        Timer.periodic(const Duration(seconds: 1), (_) => _tickCountdown());
    _tickCountdown();
    unawaited(_setup());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || _ended) return;
    if (_session.isExpired) _endCall(auto: true);
  }

  Future<void> _setup() async {
    final camera = await Permission.camera.status;
    final mic = await Permission.microphone.status;
    if (!camera.isGranted || !mic.isGranted) {
      final results = await [Permission.camera, Permission.microphone].request();
      if (!(results[Permission.camera]?.isGranted ?? false) ||
          !(results[Permission.microphone]?.isGranted ?? false)) {
        if (!mounted) return;
        setState(() => _joinError = '需要相機與麥克風權限才能通話');
        return;
      }
    }

    AgoraCallCredentials? credentials = widget.credentials;
    try {
      credentials ??= await _fetchCredentials();
    } catch (e) {
      if (!mounted) return;
      setState(() => _joinError = '無法取得視訊憑證，請稍後再試');
      return;
    }
    if (!mounted || credentials == null) return;

    final engine = createAgoraRtcEngine();
    _engine = engine;
    await engine.initialize(RtcEngineContext(appId: credentials.appId));
    engine.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (connection, elapsed) {
        if (mounted) setState(() => _joining = false);
      },
      onUserJoined: (connection, remoteUid, elapsed) {
        if (mounted) setState(() => _remoteUid = remoteUid);
      },
      onUserOffline: (connection, remoteUid, reason) {
        // 對方畫面離開不等於通話結束；真正的結束交給 FCM
        // video_session_ended 或倒數/手動按鈕決定。
        if (mounted) setState(() => _remoteUid = null);
      },
      onUserMuteVideo: (connection, remoteUid, muted) {
        if (mounted) setState(() => _remoteCamOff = muted);
      },
      onTokenPrivilegeWillExpire: (connection, token) async {
        if (_session.isExpired) return;
        try {
          final refreshed = await VideoCallService.refreshToken(_session.id);
          await engine.renewToken(refreshed.token);
        } catch (e) {
          debugPrint('VideoCallScreen: token 續期失敗：$e');
        }
      },
    ));

    await engine.enableVideo();
    await engine.setVideoEncoderConfiguration(const VideoEncoderConfiguration(
      dimensions: VideoDimensions(width: 1280, height: 720),
    ));
    await engine.startPreview();
    await engine.joinChannel(
      token: credentials.token,
      channelId: _session.channel,
      uid: credentials.uid,
      options: const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ),
    );
  }

  Future<AgoraCallCredentials?> _fetchCredentials() async {
    final refreshed = await VideoCallService.refreshToken(_session.id);
    return AgoraCallCredentials(
      token: refreshed.token,
      appId: refreshed.appId,
      uid: refreshed.uid,
    );
  }

  void _tickCountdown() {
    final remaining = _session.expiresAt.difference(DateTime.now().toUtc());
    if (!mounted) return;
    setState(() => _remaining = remaining.isNegative ? Duration.zero : remaining);
    if (remaining <= Duration.zero && !_ended) {
      _endCall(auto: true);
    }
  }

  /// 對方結束通話：走跟手動結束一樣的本地清理，但不再呼叫 POST /end
  /// （對方已呼叫過，沒必要重複）。
  void _onPeerEnded(int? sessionId) {
    if (_ended || sessionId != _session.id) return;
    _cleanupAndLeave(notifyBackend: false);
  }

  Future<void> _toggleMute() async {
    final next = !_muted;
    await _engine?.muteLocalAudioStream(next);
    if (!mounted) return;
    setState(() => _muted = next);
  }

  Future<void> _toggleCamera() async {
    final next = !_camOff;
    await _engine?.muteLocalVideoStream(next);
    if (!mounted) return;
    setState(() => _camOff = next);
  }

  Future<void> _endCall({required bool auto}) async {
    if (_ended) return;
    await _cleanupAndLeave(notifyBackend: true);
  }

  Future<void> _cleanupAndLeave({required bool notifyBackend}) async {
    if (_ended) return;
    _ended = true;
    _countdownTimer?.cancel();
    if (notifyBackend) {
      try {
        await VideoCallService.endSession(_session.id);
      } catch (e) {
        debugPrint('VideoCallScreen: 結束通話通知後端失敗（忽略）：$e');
      }
    }
    final engine = _engine;
    if (engine != null) {
      try {
        await engine.leaveChannel();
        await engine.release();
      } catch (e) {
        debugPrint('VideoCallScreen: 釋放 Agora engine 失敗（忽略）：$e');
      }
    }
    if (!mounted) return;
    Navigator.popUntil(context, (r) => r.isFirst);
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    FcmService.onVideoSessionEnded = null;
    WidgetsBinding.instance.removeObserver(this);
    // dispose() 不適合塞 await 網路呼叫；正常結束流程一律走 _cleanupAndLeave，
    // 這裡只兜底釋放引擎，避免使用者用手勢/返回鍵繞過 PopScope 時資源洩漏。
    _engine?.leaveChannel();
    _engine?.release();
    super.dispose();
  }

  String get _timeLabel {
    final elapsed = _session.expiresAt.difference(DateTime.now().toUtc()) < Duration.zero
        ? Duration.zero
        : (const Duration(minutes: 30) - _remaining);
    final m = elapsed.inMinutes.clamp(0, 999);
    final s = elapsed.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String get _remainingLabel => '剩 ${_remaining.inMinutes} 分';

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _endCall(auto: false);
      },
      child: Scaffold(
        backgroundColor: AppColors.ink,
        body: Stack(
          fit: StackFit.expand,
          children: [
            _buildFullScreenVideo(),
            _buildTopBar(),
            _buildPersonName(),
            _buildSelfView(),
            _buildTopicChip(),
            _buildControlBar(context),
            if (_joinError != null) _buildErrorOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorOverlay() {
    return Container(
      color: AppColors.ink.withValues(alpha: 0.92),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _joinError!,
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSerifTc(
              fontSize: 16,
              color: AppColors.creamLight,
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.gold,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text('返回', style: GoogleFonts.notoSerifTc(color: AppColors.ink)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullScreenVideo() {
    final engine = _engine;
    final remoteUid = _remoteUid;
    if (engine != null && remoteUid != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          AgoraVideoView(
            controller: VideoViewController.remote(
              rtcEngine: engine,
              canvas: VideoCanvas(uid: remoteUid),
              connection: RtcConnection(channelId: _session.channel),
            ),
          ),
          if (_remoteCamOff) _buildCameraOffOverlay('對方已關閉鏡頭'),
        ],
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.mossDeep, AppColors.ink, AppColors.primaryDeep],
              stops: [0.0, 0.6, 1.0],
            ),
          ),
        ),
        Opacity(
          opacity: 0.1,
          child: CustomPaint(
            painter: TrukuWeavePainter(color: AppColors.gold, opacity: 1.0, scale: 1.0),
          ),
        ),
        Center(
          child: Text(
            _joining ? '正在加入視訊房…' : '等待對方加入視訊',
            style: GoogleFonts.notoSerifTc(
              fontSize: 16,
              color: AppColors.creamLight.withValues(alpha: 0.85),
              letterSpacing: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCameraOffOverlay(String label) {
    return Container(
      color: AppColors.ink.withValues(alpha: 0.85),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomPaint(size: const Size(28, 28), painter: _CamOffPainter()),
          const SizedBox(height: 10),
          Text(
            label,
            style: GoogleFonts.notoSerifTc(
              fontSize: 13,
              color: AppColors.creamLight.withValues(alpha: 0.85),
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 60,
      left: 20,
      right: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.ink.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.recording,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _timeLabel,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 13,
                    color: AppColors.creamLight,
                    letterSpacing: 2.0,
                  ),
                ),
                Container(
                  width: 1,
                  height: 12,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  color: AppColors.creamLight.withValues(alpha: 0.25),
                ),
                Text(
                  _remainingLabel,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.creamLight.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.ink.withValues(alpha: 0.6),
            ),
            child: const Center(child: _DotsIcon()),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonName() {
    return Positioned(
      left: 0,
      right: 0,
      top: MediaQuery.of(context).size.height * 0.62,
      child: Column(
        children: [
          Text(
            '語伴',
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSerifTc(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: AppColors.creamLight,
              letterSpacing: 1.2,
              shadows: const [Shadow(color: Colors.black54, blurRadius: 12)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelfView() {
    final engine = _engine;
    return Positioned(
      top: 110,
      right: 16,
      child: Container(
        width: 100,
        height: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.moss, AppColors.mossDeep],
          ),
          border: Border.all(
            color: AppColors.gold.withValues(alpha: 0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12.5),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (engine != null)
                AgoraVideoView(
                  controller: VideoViewController(
                    rtcEngine: engine,
                    canvas: const VideoCanvas(uid: 0),
                  ),
                ),
              if (_camOff) _buildCameraOffOverlay('已關閉鏡頭'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopicChip() {
    return const SizedBox.shrink();
  }

  Widget _buildControlBar(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Color(0xF21C0F0D), Colors.transparent],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _ControlButton(
              icon: _ControlIcon.mic,
              label: '靜音',
              active: _muted,
              onTap: _toggleMute,
            ),
            _ControlButton(
              icon: _ControlIcon.cam,
              label: '鏡頭',
              active: _camOff,
              onTap: _toggleCamera,
            ),
            _ControlButton(
              icon: _ControlIcon.end,
              label: '結束',
              danger: true,
              onTap: () => _endCall(auto: false),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Control button ────────────────────────────────────────────────────────────

enum _ControlIcon { mic, cam, end }

class _ControlButton extends StatelessWidget {
  final _ControlIcon icon;
  final String label;
  final bool danger;
  final bool active;
  final VoidCallback? onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    this.danger = false,
    this.active = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final size = danger ? 60.0 : 52.0;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: danger
                  ? const Color(0xFFD8392C)
                  : active
                      ? AppColors.dangerDark
                      : Colors.white.withValues(alpha: 0.12),
              border: danger || active
                  ? null
                  : Border.all(
                      color: AppColors.creamLight.withValues(alpha: 0.12),
                    ),
            ),
            child: Center(child: _buildIcon()),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: AppColors.creamLight.withValues(alpha: 0.85),
              letterSpacing: 2.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIcon() {
    switch (icon) {
      case _ControlIcon.mic:
        return CustomPaint(size: const Size(22, 22), painter: _MicPainter());
      case _ControlIcon.cam:
        return CustomPaint(size: const Size(24, 24), painter: _CamPainter());
      case _ControlIcon.end:
        return CustomPaint(size: const Size(26, 26), painter: _EndPainter());
    }
  }
}

// ─── Icon painters ─────────────────────────────────────────────────────────────

class _MicPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.creamLight
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final w = size.width;
    final h = size.height;
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 9 / 24, h * 3 / 24, w * 6 / 24, h * 12 / 24),
      Radius.circular(w * 3 / 24),
    );
    canvas.drawRRect(
        body, Paint()..color = AppColors.creamLight..style = PaintingStyle.fill);
    final arcPath = Path()
      ..moveTo(w * 5 / 24, h * 11 / 24)
      ..quadraticBezierTo(w * 5 / 24, h * 18 / 24, w * 12 / 24, h * 18 / 24)
      ..quadraticBezierTo(w * 19 / 24, h * 18 / 24, w * 19 / 24, h * 11 / 24);
    canvas.drawPath(arcPath, p);
    canvas.drawLine(Offset(w * 12 / 24, h * 18 / 24),
        Offset(w * 12 / 24, h * 21 / 24), p);
  }

  @override
  bool shouldRepaint(_MicPainter _) => false;
}

class _CamPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cream = AppColors.creamLight;
    final w = size.width;
    final h = size.height;
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 3 / 24, h * 6 / 24, w * 13 / 24, h * 12 / 24),
      Radius.circular(w * 2 / 24),
    );
    canvas.drawRRect(
        body,
        Paint()
          ..color = cream
          ..style = PaintingStyle.fill);
    final tri = Path()
      ..moveTo(w * 16 / 24, h * 10 / 24)
      ..lineTo(w * 21 / 24, h * 7 / 24)
      ..lineTo(w * 21 / 24, h * 17 / 24)
      ..close();
    canvas.drawPath(tri, Paint()..color = cream..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(_CamPainter _) => false;
}

class _CamOffPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cream = AppColors.creamLight.withValues(alpha: 0.85);
    final w = size.width;
    final h = size.height;
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 3 / 24, h * 6 / 24, w * 13 / 24, h * 12 / 24),
      Radius.circular(w * 2 / 24),
    );
    canvas.drawRRect(body, Paint()..color = cream..style = PaintingStyle.fill);
    final tri = Path()
      ..moveTo(w * 16 / 24, h * 10 / 24)
      ..lineTo(w * 21 / 24, h * 7 / 24)
      ..lineTo(w * 21 / 24, h * 17 / 24)
      ..close();
    canvas.drawPath(tri, Paint()..color = cream..style = PaintingStyle.fill);
    final slash = Paint()
      ..color = AppColors.danger
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 2 / 24, h * 2 / 24),
        Offset(w * 22 / 24, h * 22 / 24), slash);
  }

  @override
  bool shouldRepaint(_CamOffPainter _) => false;
}

class _EndPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.save();
    canvas.translate(w / 2, h / 2);
    canvas.rotate(2.356);
    canvas.translate(-w / 2, -h / 2);
    final path = Path()
      ..moveTo(w * 22 / 24, h * 16.92 / 24)
      ..lineTo(w * 22 / 24, h * 19 / 24)
      ..cubicTo(w * 22 / 24, h * 20.1 / 24, w * 21.1 / 24, h * 21 / 24,
          w * 19.82 / 24, h * 21 / 24)
      ..cubicTo(w * 17.33 / 24, h * 20.79 / 24, w * 15.19 / 24,
          h * 19.92 / 24, w * 11.19 / 24, h * 17.93 / 24)
      ..cubicTo(w * 8.4 / 24, h * 16.43 / 24, w * 7.57 / 24, h * 15.6 / 24,
          w * 5.07 / 24, h * 11.93 / 24)
      ..cubicTo(w * 2.79 / 24, h * 8.13 / 24, w * 2 / 24, h * 5.9 / 24,
          w * 2 / 24, h * 3.11 / 24)
      ..cubicTo(w * 2 / 24, h * 2.1 / 24, w * 2.9 / 24, h * 2 / 24,
          w * 4 / 24, h * 2 / 24)
      ..lineTo(w * 7 / 24, h * 2 / 24)
      ..cubicTo(w * 8.1 / 24, h * 2 / 24, w * 9 / 24, h * 2.72 / 24,
          w * 9 / 24, h * 3.72 / 24)
      ..cubicTo(w * 9.13 / 24, h * 4.68 / 24, w * 9.37 / 24, h * 5.63 / 24,
          w * 9.71 / 24, h * 6.53 / 24)
      ..cubicTo(w * 10.04 / 24, h * 7.11 / 24, w * 9.71 / 24, h * 8.11 / 24,
          w * 9.26 / 24, h * 8.64 / 24)
      ..lineTo(w * 8.09 / 24, h * 9.91 / 24)
      ..cubicTo(w * 10 / 24, h * 12.9 / 24, w * 13.1 / 24, h * 14.9 / 24,
          w * 14.09 / 24, h * 15.91 / 24)
      ..lineTo(w * 15.36 / 24, h * 14.64 / 24)
      ..cubicTo(w * 15.89 / 24, h * 14.19 / 24, w * 16.89 / 24,
          h * 13.96 / 24, w * 18 / 24, h * 14.29 / 24)
      ..cubicTo(w * 18.9 / 24, h * 14.63 / 24, w * 19.85 / 24,
          h * 14.87 / 24, w * 20.81 / 24, h * 15 / 24)
      ..cubicTo(w * 21.92 / 24, h * 15.08 / 24, w * 22 / 24, h * 15.8 / 24,
          w * 22 / 24, h * 16.92 / 24)
      ..close();
    canvas.drawPath(
        path, Paint()..color = AppColors.creamLight..style = PaintingStyle.fill);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_EndPainter _) => false;
}

// ─── More-options dots icon ────────────────────────────────────────────────────

class _DotsIcon extends StatelessWidget {
  const _DotsIcon();

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: const Size(18, 18), painter: _DotsPainter());
}

class _DotsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.creamLight
      ..style = PaintingStyle.fill;
    final r = size.width * 1.5 / 24;
    final cx = size.width / 2;
    for (final cy in [size.height * 6 / 24, size.height * 12 / 24, size.height * 18 / 24]) {
      canvas.drawCircle(Offset(cx, cy), r, paint);
    }
  }

  @override
  bool shouldRepaint(_DotsPainter _) => false;
}
