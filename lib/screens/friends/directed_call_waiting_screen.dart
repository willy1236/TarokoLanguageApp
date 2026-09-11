// 撥打好友定向通話的「撥出中」畫面。撥號後輪詢來電狀態，接通時用既有
// VideoCallService.refreshToken 取得自己的 Agora 憑證再進通話畫面（見 friendCalls.ts 註解）。

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../models/video_call_model.dart';
import '../../services/directed_call_service.dart';
import '../../services/video_call_service.dart';
import '../../shared/widgets/truku_painters.dart';
import '../../shared/widgets/truku_widgets.dart';
import '../community/video_call_screen.dart';

class DirectedCallWaitingScreen extends StatefulWidget {
  final int calleeUid;
  final String? calleeNickname;

  const DirectedCallWaitingScreen({
    super.key,
    required this.calleeUid,
    this.calleeNickname,
  });

  @override
  State<DirectedCallWaitingScreen> createState() =>
      _DirectedCallWaitingScreenState();
}

class _DirectedCallWaitingScreenState extends State<DirectedCallWaitingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _pollTimer;
  int? _callId;
  bool _navigated = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    _startCall();
  }

  @override
  void dispose() {
    _controller.dispose();
    _pollTimer?.cancel();
    final id = _callId;
    if (id != null && !_navigated) {
      DirectedCallService.cancelCall(id).catchError((_) {});
    }
    super.dispose();
  }

  Future<void> _startCall() async {
    try {
      final callId = await DirectedCallService.callFriend(widget.calleeUid);
      if (!mounted) return;
      setState(() => _callId = callId);
      _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = _describeError(e));
    }
  }

  Future<void> _poll() async {
    final id = _callId;
    if (id == null) return;
    try {
      final status = await DirectedCallService.getCall(id);
      if (!mounted) return;
      switch (status.status) {
        case 'accepted':
          await _navigateToCall(
            status.sessionId!,
            status.peerUid,
            status.peerNickname,
          );
          break;
        case 'declined':
          _pollTimer?.cancel();
          setState(() => _errorMessage = '對方目前無法接聽');
          break;
        case 'cancelled':
        case 'missed':
          _pollTimer?.cancel();
          setState(() => _errorMessage = '對方未接聽');
          break;
      }
    } catch (_) {
      // 輪詢期間的暫時性錯誤忽略，下次輪詢再試。
    }
  }

  Future<void> _navigateToCall(
    int sessionId,
    int peerUid,
    String? peerNickname,
  ) async {
    _pollTimer?.cancel();
    try {
      final refreshed = await VideoCallService.refreshToken(sessionId);
      if (!mounted) return;
      _navigated = true;
      final session = VideoSession(
        id: sessionId,
        channel: refreshed.channel,
        peerUid: peerUid,
        peerNickname: peerNickname,
        expiresAt: refreshed.expiresAt,
      );
      final credentials = AgoraCallCredentials(
        token: refreshed.token,
        appId: refreshed.appId,
        uid: refreshed.uid,
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => VideoCallScreen(
            session: session,
            credentials: credentials,
            directedCallId: _callId,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = _describeError(e));
    }
  }

  String _describeError(Object e) {
    if (e is ApiException) {
      if (e.isVideoNicknameRequired) return '請先在個人資料設定公開暱稱';
      if (e.isNotFriends) return '你們已不是好友';
      if (e.isBlocked) return '因封鎖關係，無法撥號';
      if (e.isMuted) return '你目前被禁言，暫時無法發起通話';
      if (e.isCalleeBusy) return '對方忙線中';
      if (e.isAlreadyInCall) return '你正在通話中';
      return e.message;
    }
    return '撥號失敗，請稍後再試';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: Stack(
        fit: StackFit.expand,
        children: [
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
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.2),
                radius: 0.7,
                colors: [Color(0x304A0F0C), Colors.transparent],
              ),
            ),
          ),
          Column(
            children: [
              _buildTopBar(),
              Expanded(child: _buildCenter()),
              _buildCancelButton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
              ),
              child: const Icon(Icons.close, size: 18, color: AppColors.creamLight),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenter() {
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: AppColors.creamLight.withValues(alpha: 0.9),
            ),
          ),
        ),
      );
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 220,
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
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
                            border: Border.all(color: AppColors.gold, width: 1.0),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
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
                  child: TrukuDiamond(size: 70, color: AppColors.gold, strokeWidth: 1.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Text(
          widget.calleeNickname?.isNotEmpty == true
              ? '正在呼叫 ${widget.calleeNickname}'
              : '撥號中',
          style: GoogleFonts.notoSerifTc(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: AppColors.creamLight,
            letterSpacing: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildCancelButton() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 50),
      child: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppColors.creamLight.withValues(alpha: 0.25)),
          ),
          child: Text(
            _errorMessage != null ? '返回' : '取消',
            style: GoogleFonts.notoSerifTc(
              fontSize: 14,
              color: AppColors.creamLight,
              letterSpacing: 2.5,
            ),
          ),
        ),
      ),
    );
  }
}
