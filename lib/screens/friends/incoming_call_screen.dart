// 好友定向來電響鈴畫面。接聽 → 進真實 Agora 通話；拒接 → 回上一頁。
// 響鈴期間輪詢來電狀態（前景推播 friend_call_cancelled 會提早觸發），撥出方
// 取消或逾時未接時自動關閉畫面。響鈴期間依系統鈴聲模式循環播放鈴聲／震動。

import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../models/friend_model.dart';
import '../../models/shop_item.dart';
import '../../services/directed_call_service.dart';
import '../../services/fcm_service.dart';
import '../../services/shop_service.dart';
import '../../shared/widgets/truku_painters.dart';
import '../../shared/widgets/user_avatar.dart';
import '../community/video_call_screen.dart';
import '../../core/constants/app_typography.dart';

class IncomingCallScreen extends StatefulWidget {
  final IncomingCall call;

  const IncomingCallScreen({super.key, required this.call});

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  bool _busy = false;
  String? _errorMessage;
  Map<String, ShopItem> _itemCatalogById = const {};
  Timer? _pollTimer;
  final _ringPlayer = AudioPlayer();
  bool _ringing = false;

  @override
  void initState() {
    super.initState();
    _loadItemCatalog();
    _startPolling();
    FcmService.onFriendCallCancelled = _onCallCancelledPush;
    _startRinging();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    if (FcmService.onFriendCallCancelled == _onCallCancelledPush) {
      FcmService.onFriendCallCancelled = null;
    }
    _stopRinging();
    _ringPlayer.dispose();
    super.dispose();
  }

  /// 系統鈴聲模式：`normal`／`vibrate`／`silent`。只有 Android 查得到；iOS 的
  /// 靜音開關無法查詢（鈴聲靠 ambient category 自動遵守），Web 與查詢失敗都視為 normal。
  static const _ringerModeChannel = MethodChannel('truku/ringer_mode');

  Future<String> _ringerMode() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return 'normal';
    try {
      return await _ringerModeChannel.invokeMethod<String>('getRingerMode') ??
          'normal';
    } catch (e) {
      debugPrint('Failed to get ringer mode: $e');
      return 'normal';
    }
  }

  Future<void> _startRinging() async {
    _ringing = true;
    final mode = await _ringerMode();
    // 查詢期間使用者可能已接聽/拒接/離開。
    if (!_ringing || mode == 'silent') return;
    if (!kIsWeb) {
      // 與 ringtone.wav 同步：震 0.7s、停 0.15s、震 0.7s、停 0.85s，整輪 2.4s 循環。
      Vibration.vibrate(pattern: [0, 700, 150, 700, 850], repeat: 0)
          .catchError((e) => debugPrint('Failed to vibrate: $e'));
    }
    if (mode == 'vibrate') return;
    try {
      if (!kIsWeb) {
        // 走鈴聲音量而非媒體音量；iOS ambient 會遵守靜音開關。
        await _ringPlayer.setAudioContext(
          AudioContext(
            android: const AudioContextAndroid(
              usageType: AndroidUsageType.notificationRingtone,
              contentType: AndroidContentType.sonification,
              audioFocus: AndroidAudioFocus.gainTransient,
            ),
            iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
          ),
        );
      }
      await _ringPlayer.setReleaseMode(ReleaseMode.loop);
      // 使用者可能在設定期間就已接聽/拒接/離開，此時不要再開始播。
      if (!_ringing) return;
      await _ringPlayer.play(AssetSource('sounds/ringtone.wav'));
    } catch (e) {
      // Web 未經使用者互動可能擋自動播放；鈴聲失敗不影響接聽流程。
      debugPrint('Failed to play ringtone: $e');
    }
  }

  void _stopRinging() {
    _ringing = false;
    if (!kIsWeb) Vibration.cancel().catchError((_) {});
    _ringPlayer.stop().catchError((_) {});
  }

  void _onCallCancelledPush(int callId) {
    if (callId == widget.call.callId) _poll();
  }

  /// 查來電狀態；已不在響鈴中（撥出方取消、逾時等）就提示並自動關閉畫面。
  /// 使用者正在接聽/拒接時不介入，交給該流程自己處理結果。
  Future<void> _poll() async {
    if (_busy || _pollTimer == null) return;
    try {
      final status = await DirectedCallService.getCall(widget.call.callId);
      if (!mounted || _busy || _pollTimer == null) return;
      final message = switch (status.status) {
        'ringing' => null,
        'cancelled' => '對方已取消通話',
        'missed' => '未接來電',
        _ => '此來電已結束',
      };
      if (message == null) return;
      _pollTimer?.cancel();
      _pollTimer = null;
      _stopRinging();
      setState(() => _errorMessage = message);
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted && ModalRoute.of(context)?.isCurrent == true) {
          Navigator.of(context).pop();
        }
      });
    } catch (_) {
      // 輪詢期間的暫時性錯誤忽略，下次輪詢再試。
    }
  }

  Future<void> _loadItemCatalog() async {
    try {
      final catalog = await ShopService.fetchItemCatalogCached();
      if (!mounted) return;
      setState(() => _itemCatalogById = catalog);
    } catch (e) {
      debugPrint('Failed to fetch item catalog: $e');
    }
  }

  Future<void> _accept() async {
    _pollTimer?.cancel();
    _pollTimer = null;
    _stopRinging();
    setState(() => _busy = true);
    try {
      final (session, credentials) = await DirectedCallService.acceptCall(
        widget.call.callId,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => VideoCallScreen(
            session: session,
            credentials: credentials,
            directedCallId: widget.call.callId,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      // 暫時性失敗時通話可能還在響鈴，恢復輪詢，對方之後取消仍能自動關閉。
      if (!(e is ApiException && e.isCallNotRinging)) _startPolling();
      setState(() {
        _busy = false;
        _errorMessage = _describeError(e);
      });
    }
  }

  Future<void> _decline() async {
    _pollTimer?.cancel();
    _pollTimer = null;
    _stopRinging();
    setState(() => _busy = true);
    try {
      await DirectedCallService.declineCall(widget.call.callId);
    } catch (_) {
      // 拒接失敗仍優先讓使用者離開畫面。
    }
    if (mounted) Navigator.of(context).pop();
  }

  String _describeError(Object e) {
    if (e is ApiException) {
      if (e.isCallNotRinging) return '此來電已結束';
      if (e.isNotFriends) return '你們已不是好友或已封鎖，無法接通';
      return e.message;
    }
    return '接聽失敗，請稍後再試';
  }

  @override
  Widget build(BuildContext context) {
    final call = widget.call;
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
              const SizedBox(height: 100),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _avatar(),
                      const SizedBox(height: 24),
                      Text(
                        call.callerNickname?.isNotEmpty == true
                            ? call.callerNickname!
                            : '未命名旅人',
                        style: AppTypography.serif(
                          fontSize: AppTypography.display24,
                          fontWeight: FontWeight.w600,
                          color: AppColors.creamLight,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage ?? '來電中…',
                        style: TextStyle(
                          fontSize: AppTypography.body,
                          color: AppColors.creamLight.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _buildActions(),
              const SizedBox(height: 60),
            ],
          ),
        ],
      ),
    );
  }

  Widget _avatar() {
    final call = widget.call;
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.38),
            blurRadius: 60,
            spreadRadius: 10,
          ),
        ],
      ),
      child: Container(
        decoration: call.callerFrameId == null
            ? BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.gold, width: 2),
              )
            : null,
        child: FramedUserAvatar(
          avatarId: call.callerAvatarId,
          avatarUrl: call.callerAvatarUrl,
          frameId: call.callerFrameId,
          itemCatalogById: _itemCatalogById,
          size: 120,
          fallbackIconColor: AppColors.gold,
          fallback: DecoratedBox(
            decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.ink),
            child: Center(
              child: Text(
                call.callerNickname?.characters.firstOrNull ?? '?',
                style: AppTypography.serif(
                  fontSize: AppTypography.display40,
                  color: AppColors.gold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActions() {
    if (_errorMessage != null) {
      return TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(
          '返回',
          style: AppTypography.serif(
            fontSize: AppTypography.body,
            color: AppColors.creamLight,
            letterSpacing: 2.5,
          ),
        ),
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _actionButton(
          label: '拒接',
          color: const Color(0xFFD8392C),
          icon: Icons.call_end,
          onTap: _busy ? null : _decline,
        ),
        _actionButton(
          label: '接聽',
          color: AppColors.moss,
          icon: Icons.call,
          onTap: _busy ? null : _accept,
        ),
      ],
    );
  }

  Widget _actionButton({
    required String label,
    required Color color,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            child: _busy
                ? const Padding(
                    padding: EdgeInsets.all(18),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: AppTypography.caption,
              color: AppColors.creamLight.withValues(alpha: 0.85),
              letterSpacing: 2.0,
            ),
          ),
        ],
      ),
    );
  }
}
