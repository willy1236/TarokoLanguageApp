import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import 'truku_painters.dart';
import 'truku_widgets.dart';

/// 小米獎勵彈窗 — 對應 screens-reward.jsx MilletRewardPopup
///
/// 使用：
///   showDialog(context: context, builder: (_) => RewardOverlay(amount: 10, reason: '每日登入'));
class RewardOverlay extends StatefulWidget {
  final int amount;
  final String reason;
  final VoidCallback? onShop;
  final VoidCallback? onContinue;

  const RewardOverlay({
    super.key,
    this.amount = 10,
    this.reason = '每日登入',
    this.onShop,
    this.onContinue,
  });

  @override
  State<RewardOverlay> createState() => _RewardOverlayState();
}

class _RewardOverlayState extends State<RewardOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _numAnim;
  late final Animation<double> _rotateAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _scaleAnim = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _numAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.3, 1.0, curve: Curves.easeOut)),
    );
    _rotateAnim = Tween<double>(begin: 0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.5, curve: Curves.easeOut)),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Stack(
        children: [
          // 背景遮罩點擊關閉
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.transparent),
            ),
          ),
          Center(
            child: ScaleTransition(
              scale: _scaleAnim,
              child: _buildCard(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.cream, AppColors.creamLight],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.gold, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 40, offset: Offset(0, 16))],
      ),
      child: Stack(
        children: [
          // 背景織紋
          Positioned.fill(
            child: Opacity(
              opacity: 0.10,
              child: CustomPaint(
                painter: TrukuWeavePainter(color: AppColors.primary, opacity: 1.0, scale: 0.6),
              ),
            ),
          ),
          // 四角菱形裝飾
          const Positioned(top: -8, left: -8, child: TrukuDiamond(size: 12, color: AppColors.primary, filled: true)),
          const Positioned(top: -8, right: -8, child: TrukuDiamond(size: 12, color: AppColors.primary, filled: true)),
          const Positioned(bottom: -8, left: -8, child: TrukuDiamond(size: 12, color: AppColors.primary, filled: true)),
          const Positioned(bottom: -8, right: -8, child: TrukuDiamond(size: 12, color: AppColors.primary, filled: true)),
          // 主體內容
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'MHUWAY SU',
                style: GoogleFonts.crimsonPro(
                  fontStyle: FontStyle.italic,
                  fontSize: 11,
                  color: AppColors.primary,
                  letterSpacing: 5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '恭喜獲得小米',
                style: GoogleFonts.notoSerifTc(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 18),
              _buildMilletIcon(),
              const SizedBox(height: 12),
              // +數字
              AnimatedBuilder(
                animation: _numAnim,
                builder: (_, _) {
                  final displayed = (widget.amount * _numAnim.value).round();
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('+', style: GoogleFonts.notoSerifTc(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary, letterSpacing: 1)),
                      const SizedBox(width: 4),
                      Text(
                        '$displayed',
                        style: GoogleFonts.notoSerifTc(fontSize: 56, fontWeight: FontWeight.w700, color: AppColors.primary, height: 1),
                      ),
                      const SizedBox(width: 6),
                      Text('顆小米', style: GoogleFonts.notoSerifTc(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.inkSoft, letterSpacing: 1)),
                    ],
                  );
                },
              ),
              const SizedBox(height: 6),
              // 原因標籤
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: AppColors.primary.withValues(alpha: 0.08),
                ),
                child: Text(
                  widget.reason,
                  style: TextStyle(fontSize: 11, color: AppColors.primary, letterSpacing: 2),
                ),
              ),
              const SizedBox(height: 20),
              // 餘額列
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('目前小米', style: TextStyle(fontSize: 11, color: AppColors.gold.withValues(alpha: 0.85), letterSpacing: 1)),
                    Row(
                      children: [
                        const Icon(Icons.grain, size: 22, color: AppColors.gold),
                        const SizedBox(width: 6),
                        Text(
                          '320',
                          style: GoogleFonts.notoSerifTc(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.creamLight),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              // 按鈕列
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.of(context).pop();
                        widget.onShop?.call();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.creamDeep, width: 1.5),
                          color: AppColors.creamLight,
                        ),
                        child: Text(
                          '逛商店',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.notoSerifTc(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.inkSoft,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.of(context).pop();
                        widget.onContinue?.call();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: AppColors.primary,
                        ),
                        child: Text(
                          '繼續',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.notoSerifTc(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.creamLight,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMilletIcon() {
    return SizedBox(
      width: 140,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 放射光暈
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [AppColors.gold.withValues(alpha: 0.38), Colors.transparent],
              ),
            ),
          ),
          // 旋轉光芒線
          AnimatedBuilder(
            animation: _rotateAnim,
            builder: (_, _) => Transform.rotate(
              angle: _rotateAnim.value,
              child: CustomPaint(
                size: const Size(140, 140),
                painter: _RaysPainter(),
              ),
            ),
          ),
          // 小米圖示（菱形 + 圓形疊合）
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.gold.withValues(alpha: 0.25),
              border: Border.all(color: AppColors.gold, width: 2),
            ),
            child: const Icon(Icons.grain, size: 52, color: AppColors.gold),
          ),
        ],
      ),
    );
  }
}

class _RaysPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.6)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    final cx = size.width / 2;
    final cy = size.height / 2;
    for (int i = 0; i < 12; i++) {
      final a = i * math.pi / 6;
      canvas.drawLine(
        Offset(cx + math.cos(a) * 50, cy + math.sin(a) * 50),
        Offset(cx + math.cos(a) * 65, cy + math.sin(a) * 65),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}
