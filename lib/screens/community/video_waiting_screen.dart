import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../main.dart' show scaffoldMessengerKey;
import '../../models/video_call_model.dart';
import '../../services/fcm_service.dart';
import '../../services/video_call_service.dart';
import '../../shared/widgets/truku_painters.dart';
import '../../shared/widgets/truku_widgets.dart';
import 'video_call_screen.dart';
import '../../core/constants/app_typography.dart';
import '../../shared/widgets/confirm_dialog.dart';

class VideoWaitingScreen extends StatefulWidget {
  const VideoWaitingScreen({super.key});

  @override
  State<VideoWaitingScreen> createState() => _VideoWaitingScreenState();
}

class _VideoWaitingScreenState extends State<VideoWaitingScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;
  Timer? _pollTimer;
  bool _isPolling = false;
  bool _matched = false;

  /// 取消處理中：擋住重複點擊與返回鍵重入。
  bool _cancelling = false;

  /// 重新排隊被 403 擋下：不再輪詢或重試。
  bool _stopped = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    WidgetsBinding.instance.addObserver(this);
    FcmService.onVideoMatchedForeground = (_, _) => _poll();
    // 輪詢兼作佇列心跳：間隔必須小於 30 秒，否則後端會視為已離開佇列。
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _poll());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _poll();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    FcmService.onVideoMatchedForeground = null;
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  /// 查詢目前 active session；配到就取消輪詢並導向通話畫面。已被移出佇列
  /// （切背景超過 30 秒）就重新排隊，被 403 擋下（禁言、未設暱稱等）才停止並離開。
  /// 其他單次失敗只記 log，不中斷輪詢迴圈。
  Future<void> _poll() async {
    if (_isPolling || _matched || _stopped) return;
    _isPolling = true;
    try {
      final current = await VideoCallService.fetchCurrentSession();
      if (!mounted || _matched) return;
      final session = current.session;
      if (session != null) {
        // 輪詢查到的 session 沒有憑證，由 VideoCallScreen 自行 refreshToken 取得。
        _enterCall(session, null);
      } else if (!current.inQueue && !_cancelling) {
        await _rejoinQueue();
      }
    } catch (e) {
      debugPrint('VideoWaitingScreen: 輪詢失敗，忽略並等下一輪：$e');
    } finally {
      _isPolling = false;
    }
  }

  /// 被後端移出佇列時重新排隊。送出後使用者才按取消或已離開畫面：配到就結束
  /// 那一房、沒配到就再離開佇列一次，不留下沒人接的通話或幽靈排隊者。
  Future<void> _rejoinQueue() async {
    final QueueJoinResult result;
    try {
      result = await VideoCallService.joinQueue();
    } on ApiException catch (e) {
      // 條款、帳號刪除中的 403 已由 ApiClient 導頁，這裡不再介入。
      if (e.statusCode == 403 &&
          !e.isConsentRequired &&
          !e.isAccountPendingDeletion) {
        _stopForbidden(e);
      } else {
        debugPrint('VideoWaitingScreen: 重新排隊失敗，等下一輪：$e');
      }
      return;
    }
    final session = result.session;
    if (!mounted || _cancelling) {
      unawaited(
        (session != null
                ? VideoCallService.endSession(session.id)
                : VideoCallService.leaveQueue())
            .catchError((Object e) {
              debugPrint('VideoWaitingScreen: 取消後清理重新排隊失敗：$e');
            }),
      );
      return;
    }
    if (session != null) _enterCall(session, result.credentials);
  }

  void _enterCall(VideoSession session, AgoraCallCredentials? credentials) {
    _matched = true;
    _pollTimer?.cancel();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            VideoCallScreen(session: session, credentials: credentials),
      ),
    );
  }

  /// 重新排隊被擋下（禁言、未設暱稱等）：不再重試，顯示原因並離開等待畫面。
  void _stopForbidden(ApiException e) {
    _stopped = true;
    _pollTimer?.cancel();
    if (!mounted) return;
    scaffoldMessengerKey.currentState
      ?..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            e.isVideoNicknameRequired ? '視訊配對前需要先在個人資料設定公開暱稱' : e.message,
          ),
        ),
      );
    // 取消處理中就交給 _cancel 離開，兩邊都 pop 會連下面的頁面一起關掉。
    if (!_cancelling) Navigator.pop(context);
  }

  /// 取消配對：必須確認後端已離開佇列才返回。fire-and-forget 會留下幽靈
  /// 排隊者——使用者已離開畫面，卻仍可能被配到一通沒人接的通話。
  /// 返回鍵、手勢與取消按鈕三條路徑統一走這裡。
  Future<void> _cancel() async {
    if (_cancelling || _matched) return;
    setState(() => _cancelling = true);
    try {
      await VideoCallService.leaveQueue().timeout(const Duration(seconds: 5));
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      debugPrint('VideoWaitingScreen: 離開佇列失敗：$e');
      if (!mounted) return;
      setState(() => _cancelling = false);
      // 重新排隊已被 403 擋下（_stopped）時本來就不在佇列、也不再輪詢，留在此頁
      // 沒有意義，直接離開。確認框開著時才被擋下，_stopForbidden 會關掉確認框，
      // 回到這裡一樣離開。
      if (!_stopped) {
        final leaveAnyway = await showConfirmDialog(
          context,
          title: '無法取消配對',
          message: '目前無法連上伺服器。仍要離開嗎？若離開，稍後可能仍會收到配對通知。',
          cancelText: '留在此頁',
          confirmText: '仍要離開',
        );
        if (leaveAnyway != true && !_stopped) return;
      }
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 配對成功後不再攔截返回（導頁交給 _poll 的 pushReplacement）。
    return PopScope(
      canPop: _matched,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        unawaited(_cancel());
      },
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Weave background
          Opacity(
            opacity: 0.08,
            child: CustomPaint(
              painter: TrukuWeavePainter(
                color: AppColors.gold,
                opacity: 1.0,
                scale: 1.2,
              ),
            ),
          ),
          // Radial gradient overlay
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.2),
                radius: 0.7,
                colors: [
                  Color(0x304A0F0C), // primary 30%
                  Colors.transparent,
                ],
              ),
            ),
          ),
          // Content
          Column(
            children: [
              _buildTopBar(context),
              Expanded(child: _buildCenter()),
              _buildCancelButton(context),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 60, 20, 0),
      child: Center(child: _SmtrungLabel()),
    );
  }

  Widget _buildCenter() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 220,
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Animated pulsing rings
              AnimatedBuilder(
                animation: _controller,
                builder: (_, child) => Stack(
                  alignment: Alignment.center,
                  children: List.generate(3, (i) {
                    final delay = i / 3.0;
                    final t = (_controller.value + delay) % 1.0;
                    final scale = 1.0 + t * 0.4 + i * 0.18;
                    final opacity = (0.5 - i * 0.12) * (1.0 - t);
                    return Transform.scale(
                      scale: scale,
                      child: Opacity(
                        opacity: opacity.clamp(0.0, 1.0),
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.gold,
                              width: 1.0,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              // Center circle with TrukuDiamond
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [AppColors.primary, AppColors.primaryDeep],
                  ),
                  border: Border.all(color: AppColors.gold, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.38),
                      blurRadius: 60,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: const Center(
                  child: TrukuDiamond(
                    size: 70,
                    color: AppColors.gold,
                    strokeWidth: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Text(
          '正在尋找',
          style: AppTypography.serif(
            fontSize: AppTypography.display24,
            fontWeight: FontWeight.w600,
            color: AppColors.creamLight,
            letterSpacing: 2.0,
          ),
        ),
      ],
    );
  }

  Widget _buildCancelButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 50),
      child: GestureDetector(
        onTap: _cancelling ? null : _cancel,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: AppColors.creamLight.withValues(alpha: 0.25),
            ),
          ),
          child: Text(
            '取消配對',
            style: AppTypography.serif(
              fontSize: AppTypography.body,
              color: AppColors.creamLight,
              letterSpacing: 2.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _SmtrungLabel extends StatelessWidget {
  const _SmtrungLabel();
  @override
  Widget build(BuildContext context) {
    return Text(
      'SMTRUNG · 配對中',
      style: AppTypography.latin(
        fontStyle: FontStyle.italic,
        fontSize: AppTypography.micro,
        color: AppColors.gold,
        letterSpacing: 6.0,
      ),
    );
  }
}
