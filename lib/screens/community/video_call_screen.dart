import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart'
    show openAppSettings;
import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../models/video_call_model.dart';
import '../../services/directed_call_service.dart';
import '../../services/fcm_service.dart';
import '../../services/video_call_service.dart';
import '../../shared/widgets/truku_painters.dart';
import 'video_call/agora_video_rtc.dart';
import 'video_call/call_permissions.dart';
import 'video_call/video_call_controller.dart';
import 'video_call/widgets/call_controls.dart';

/// 通話畫面。狀態機在 [VideoCallController]；這裡只負責畫面、導頁、檢舉
/// 對話框與 FCM 回呼註冊。
///
/// [credentials] 可為 null（例如從 VideoWaitingScreen 輪詢配到時，
/// GET /session/current 只回 session、沒有 token）——此時 controller 會自行
/// 呼叫 VideoCallService.refreshToken 取得 Agora 憑證。
class VideoCallScreen extends StatefulWidget {
  final VideoSession session;
  final AgoraCallCredentials? credentials;

  /// 若這通通話是從好友定向撥號接通的，帶入該通話 id：掛斷時改呼叫
  /// DirectedCallService.endCall（會一併結束底層 session 並判定羈絆 +5），
  /// 不重複呼叫 VideoCallService.endSession。null 代表隨機配對通話。
  final int? directedCallId;

  const VideoCallScreen({
    super.key,
    required this.session,
    this.credentials,
    this.directedCallId,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen>
    with WidgetsBindingObserver {
  late final VideoCallController _call;
  late final void Function(int?) _peerEndedHandler;

  /// 通話固定長度，用來從剩餘時間換算已通話時間。
  static const _callLength = Duration(minutes: 30);

  @override
  void initState() {
    super.initState();
    final directedCallId = widget.directedCallId;
    _call =
        VideoCallController(
            session: widget.session,
            credentials: widget.credentials,
            rtc: AgoraVideoRtc(),
            requestPermissions: requestCallPermissions,
            refreshToken: VideoCallService.refreshToken,
            notifyEnded: () => directedCallId != null
                ? DirectedCallService.endCall(directedCallId)
                : VideoCallService.endSession(widget.session.id),
          )
          ..onTokenRenewFailed = _onTokenRenewFailed
          ..onLeft = _onLeft;
    _peerEndedHandler = _call.onPeerEnded;
    FcmService.onVideoSessionEnded = _peerEndedHandler;
    WidgetsBinding.instance.addObserver(this);
    _call.start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _call.onResumed();
  }

  @override
  void dispose() {
    // 只清掉自己註冊的回呼，避免蓋掉下一個通話畫面已經註冊的。
    if (FcmService.onVideoSessionEnded == _peerEndedHandler) {
      FcmService.onVideoSessionEnded = null;
    }
    WidgetsBinding.instance.removeObserver(this);
    _call.dispose();
    super.dispose();
  }

  void _onTokenRenewFailed() {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('連線憑證更新失敗，通話可能即將中斷')));
  }

  Future<void> _onLeft() async {
    if (!mounted) return;
    final directedCallId = widget.directedCallId;
    // 沒接通就結束（例如權限被拒）不需要問檢舉。
    if (directedCallId != null && _call.joinError == null) {
      await _offerReport(directedCallId);
    }
    if (!mounted) return;
    Navigator.popUntil(context, (r) => r.isFirst);
  }

  Future<void> _offerReport(int callId) async {
    final shouldReport = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('通話已結束'),
        content: const Text('若這通通話有不當內容，可以在此檢舉。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('返回'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('檢舉此通話'),
          ),
        ],
      ),
    );
    if (shouldReport != true || !mounted) return;
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => const CallReportDialog(),
    );
    if (reason == null || reason.trim().isEmpty || !mounted) return;
    String message;
    try {
      await DirectedCallService.reportCall(callId, reason.trim());
      message = '已送出檢舉';
    } catch (e) {
      message = apiErrorMessage(e, fallback: '檢舉失敗，請稍後再試');
    }
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String get _timeLabel {
    final remaining = _call.remaining;
    final elapsed = remaining == Duration.zero
        ? Duration.zero
        : _callLength - remaining;
    final m = elapsed.inMinutes.clamp(0, 999);
    final s = elapsed.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || _call.leaving) return;
        _call.hangUp();
      },
      child: Scaffold(
        backgroundColor: AppColors.ink,
        body: ListenableBuilder(
          listenable: _call,
          builder: (context, _) => Stack(
            fit: StackFit.expand,
            children: [
              _buildFullScreenVideo(),
              _buildTopBar(),
              _buildPersonName(),
              _buildSelfView(),
              _buildControlBar(),
              if (_call.joinError != null) _buildErrorOverlay(),
              if (_call.leaving) _buildLeavingOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  /// 掛斷處理中的遮罩：影音已停但還在通知後端/等檢舉對話框，
  /// 沒有它使用者會覺得「按了結束沒反應」而重複點擊。
  Widget _buildLeavingOverlay() {
    return Container(
      color: AppColors.ink.withValues(alpha: 0.72),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.gold),
          const SizedBox(height: 16),
          Text(
            '正在結束通話…',
            style: GoogleFonts.notoSerifTc(
              fontSize: 15,
              color: AppColors.creamLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorOverlay() {
    final permanent = _call.permissionPermanentlyDenied;
    return Container(
      color: AppColors.ink.withValues(alpha: 0.92),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _call.joinError!,
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSerifTc(
              fontSize: 16,
              color: AppColors.creamLight,
            ),
          ),
          const SizedBox(height: 20),
          if (permanent) ...[
            _pillButton(label: '開啟系統設定', filled: true, onTap: openAppSettings),
            const SizedBox(height: 12),
          ],
          // 走完整掛斷流程，後端才會結束 session（對方不必等到逾時）。
          _pillButton(label: '返回', filled: !permanent, onTap: _call.hangUp),
        ],
      ),
    );
  }

  Widget _pillButton({
    required String label,
    required bool filled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: filled ? AppColors.gold : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: filled ? null : Border.all(color: AppColors.gold),
        ),
        child: Text(
          label,
          style: GoogleFonts.notoSerifTc(
            color: filled ? AppColors.ink : AppColors.gold,
          ),
        ),
      ),
    );
  }

  Widget _buildFullScreenVideo() {
    final remoteUid = _call.remoteUid;
    if (_call.mediaActive && remoteUid != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          _call.rtc.remoteView(uid: remoteUid, channel: widget.session.channel),
          if (_call.remoteCamOff) _buildCameraOffOverlay('對方已關閉鏡頭'),
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
              colors: [
                AppColors.mossDeep,
                AppColors.ink,
                AppColors.primaryDeep,
              ],
              stops: [0.0, 0.6, 1.0],
            ),
          ),
        ),
        Opacity(
          opacity: 0.1,
          child: CustomPaint(
            painter: TrukuWeavePainter(
              color: AppColors.gold,
              opacity: 1.0,
              scale: 1.0,
            ),
          ),
        ),
        Center(
          child: Text(
            _call.joining ? '正在加入視訊房…' : '等待對方加入視訊',
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
          const CustomPaint(
            size: Size(28, 28),
            painter: CallCamPainter(slashed: true),
          ),
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
                  '剩 ${_call.remaining.inMinutes} 分',
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
            child: const Center(child: CallDotsIcon()),
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
      child: Text(
        widget.session.peerNickname ?? '語伴',
        textAlign: TextAlign.center,
        style: GoogleFonts.notoSerifTc(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: AppColors.creamLight,
          letterSpacing: 1.2,
          shadows: const [Shadow(color: Colors.black54, blurRadius: 12)],
        ),
      ),
    );
  }

  Widget _buildSelfView() {
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
              if (_call.mediaActive) _call.rtc.localView(),
              if (_call.camOff) _buildCameraOffOverlay('已關閉鏡頭'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlBar() {
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
            CallControlButton(
              icon: CallControlIcon.mic,
              label: '靜音',
              active: _call.muted,
              onTap: _call.toggleMute,
            ),
            CallControlButton(
              icon: CallControlIcon.cam,
              label: '鏡頭',
              active: _call.camOff,
              onTap: _call.toggleCamera,
            ),
            CallControlButton(
              icon: CallControlIcon.end,
              label: '結束',
              danger: true,
              onTap: _call.hangUp,
            ),
          ],
        ),
      ),
    );
  }
}
