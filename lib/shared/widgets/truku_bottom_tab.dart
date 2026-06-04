import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class TrukuBottomTab extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const TrukuBottomTab({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const _keys = ['home', 'learn', 'culture', 'comm', 'plaza', 'event'];
  static const _labels = ['首頁', '學習', '影音', '視訊', '廣場', '活動'];

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: const BoxDecoration(
            // creamLight #FAF5EA at ~92% opacity (0xEB alpha)
            color: Color(0xEBFAF5EA),
            border: Border(top: BorderSide(color: AppColors.creamDeep, width: 1)),
          ),
          padding: EdgeInsets.fromLTRB(8, 10, 8, 28 + bottomPad),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_keys.length, (i) {
              final isActive = i == currentIndex;
              final color = isActive ? AppColors.primary : AppColors.fog;
              return GestureDetector(
                onTap: () => onTap(i),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CustomPaint(
                        size: const Size(22, 22),
                        painter: _TabIconPainter(_keys[i], color),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _labels[i],
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 1.0,
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
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

      case 'learn':
        // 書：兩個矩形 M4 4h7v16H4z  M13 4h7v16h-7z
        canvas.drawPath(Path()..addRect(const Rect.fromLTWH(4, 4, 7, 16)), stroke);
        canvas.drawPath(Path()..addRect(const Rect.fromLTWH(13, 4, 7, 16)), stroke);

      case 'culture':
        // 播放圓圈 + 填充三角
        canvas.drawCircle(const Offset(12, 12), 9, stroke);
        canvas.drawPath(
          Path()
            ..moveTo(10, 8)
            ..lineTo(16, 12)
            ..lineTo(10, 16)
            ..close(),
          fill,
        );

      case 'comm':
        // 對話氣泡: M4 5h16v12H10l-6 5z
        canvas.drawPath(
          Path()
            ..moveTo(4, 5)
            ..lineTo(20, 5)
            ..lineTo(20, 17)
            ..lineTo(10, 17)
            ..lineTo(4, 22)
            ..close(),
          stroke,
        );

      case 'plaza':
        // 人群：circle cx=12 cy=9 r=4 + body arc
        canvas.drawCircle(const Offset(12, 9), 4, stroke);
        canvas.drawPath(
          Path()
            ..moveTo(4, 21)
            ..cubicTo(5, 17, 9, 15, 12, 15)
            ..cubicTo(15, 15, 19, 17, 20, 21),
          stroke,
        );

      case 'event':
        // 日曆：rect + 橫線 + 兩條豎線
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(3, 5, 18, 16),
            const Radius.circular(2),
          ),
          stroke,
        );
        canvas.drawLine(const Offset(3, 10), const Offset(21, 10), stroke);
        canvas.drawLine(const Offset(8, 3), const Offset(8, 7), stroke);
        canvas.drawLine(const Offset(16, 3), const Offset(16, 7), stroke);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_TabIconPainter old) =>
      old.name != name || old.color != color;
}
