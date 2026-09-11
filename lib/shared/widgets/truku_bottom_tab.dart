import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';

class TrukuBottomTab extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool seniorMode;

  const TrukuBottomTab({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.seniorMode = false,
  });

  static const _keys = ['home', 'learn_culture', 'plaza_event', 'friends', 'me'];
  static const _labels = ['首頁', '學習影音', '廣場活動', '好友', '我的'];
  static const _seniorHiddenKeys = <String>{};

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final visibleIndices = [
      for (var i = 0; i < _keys.length; i++)
        if (!seniorMode || !_seniorHiddenKeys.contains(_keys[i])) i,
    ];
    final iconSize = seniorMode ? 30.0 : 22.0;
    // 精簡模式 caption token（11）比原本的 13 還小，改用 body token 維持放大幅度。
    final labelStyle = seniorMode
        ? AppTypography.bodyStyle(seniorMode: true)
        : AppTypography.captionStyle();
    final horizontalPadding = seniorMode ? 8.0 : 4.0;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: const BoxDecoration(
            // creamLight #FAF5EA at ~92% opacity (0xEB alpha)
            color: Color(0xEBFAF5EA),
            border: Border(
              top: BorderSide(color: AppColors.creamDeep, width: 1),
            ),
          ),
          padding: EdgeInsets.fromLTRB(8, 10, 8, 28 + bottomPad),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (final i in visibleIndices)
                Builder(
                  builder: (context) {
                    final isActive = i == currentIndex;
                    final color = isActive
                        ? AppColors.primary
                        : AppColors.fog;
                    return GestureDetector(
                      onTap: () => onTap(i),
                      behavior: HitTestBehavior.opaque,
                      child: ConstrainedBox(
                        constraints: seniorMode
                            ? const BoxConstraints(
                                minWidth: 56,
                                minHeight: 56,
                              )
                            : const BoxConstraints(),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPadding,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CustomPaint(
                                size: Size(iconSize, iconSize),
                                painter: _TabIconPainter(_keys[i], color),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _labels[i],
                                style: labelStyle.copyWith(
                                  letterSpacing: 1.0,
                                  fontWeight: isActive
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: color,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabIconPainter extends CustomPainter {
  final String name;
  final Color color;

  const _TabIconPainter(this.name, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    // 將 24×24 SVG viewBox 縮放至實際畫布
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    switch (name) {
      case 'home':
        // 房屋輪廓: M3 11 L12 3 L21 11 V21 H3 Z
        canvas.drawPath(
          Path()
            ..moveTo(3, 11)
            ..lineTo(12, 3)
            ..lineTo(21, 11)
            ..lineTo(21, 21)
            ..lineTo(3, 21)
            ..close(),
          stroke,
        );
        // 門: M9 21v-7h6v7
        canvas.drawPath(
          Path()
            ..moveTo(9, 21)
            ..lineTo(9, 14)
            ..lineTo(15, 14)
            ..lineTo(15, 21),
          stroke,
        );

      case 'learn_culture':
        // 書（學習）+ 播放三角（影音）合併圖示：一本書配一個播放鍵
        canvas.drawPath(
          Path()..addRect(const Rect.fromLTWH(3, 4, 8, 16)),
          stroke,
        );
        canvas.drawCircle(const Offset(17, 12), 6, stroke);
        canvas.drawPath(
          Path()
            ..moveTo(15.3, 9)
            ..lineTo(19.5, 12)
            ..lineTo(15.3, 15)
            ..close(),
          fill,
        );

      case 'plaza_event':
        // 人群（廣場）+ 日曆（活動）合併圖示
        canvas.drawCircle(const Offset(8, 7), 3, stroke);
        canvas.drawPath(
          Path()
            ..moveTo(2, 16)
            ..cubicTo(2.5, 13, 5.5, 11.5, 8, 11.5)
            ..cubicTo(10.5, 11.5, 13.5, 13, 14, 16),
          stroke,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(13, 6, 9, 9),
            const Radius.circular(1.5),
          ),
          stroke,
        );
        canvas.drawLine(const Offset(13, 9.5), const Offset(22, 9.5), stroke);

      case 'friends':
        // 兩個人：前方完整頭像，後方露出半身
        canvas.drawCircle(const Offset(9, 8), 3.5, stroke);
        canvas.drawPath(
          Path()
            ..moveTo(2, 20)
            ..cubicTo(2.8, 15.5, 5.8, 13.5, 9, 13.5)
            ..cubicTo(12.2, 13.5, 15.2, 15.5, 16, 20),
          stroke,
        );
        canvas.drawPath(
          Path()
            ..moveTo(15.5, 4.8)
            ..arcToPoint(
              const Offset(15.5, 11.2),
              radius: const Radius.circular(3.2),
            ),
          stroke,
        );
        canvas.drawPath(
          Path()
            ..moveTo(17.5, 13.8)
            ..cubicTo(20, 14.6, 21.6, 16.8, 22, 20),
          stroke,
        );

      case 'me':
        // 個人（頭像）＋視訊（右下角小攝影機），代表個人資料與視訊配對合併分頁
        canvas.drawCircle(const Offset(10, 7.5), 4, stroke);
        canvas.drawPath(
          Path()
            ..moveTo(2.5, 20.5)
            ..cubicTo(3.3, 16, 6.5, 13.5, 10, 13.5)
            ..cubicTo(11.2, 13.5, 12.3, 13.8, 13.3, 14.3),
          stroke,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(14, 15, 6, 5.5),
            const Radius.circular(1),
          ),
          fill,
        );
        canvas.drawPath(
          Path()
            ..moveTo(20.5, 17.8)
            ..lineTo(23, 16)
            ..lineTo(23, 19.5)
            ..close(),
          fill,
        );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_TabIconPainter old) =>
      old.name != name || old.color != color;
}
