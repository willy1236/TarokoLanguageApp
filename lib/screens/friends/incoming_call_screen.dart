// 好友定向來電響鈴畫面。接聽 → 進真實 Agora 通話；拒接 → 回上一頁。

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../models/friend_model.dart';
import '../../models/shop_item.dart';
import '../../services/directed_call_service.dart';
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

  @override
  void initState() {
    super.initState();
    _loadItemCatalog();
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
      setState(() {
        _busy = false;
        _errorMessage = _describeError(e);
      });
    }
  }

  Future<void> _decline() async {
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
