import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// 太魯閣菱形圖樣（裝飾用）
/// 對應 design-tokens.jsx TrukuDiamond
class TrukuDiamond extends StatelessWidget {
  final double size;
  final Color color;
  final bool filled;
  final double strokeWidth;

  const TrukuDiamond({
    super.key,
    this.size = 24,
    this.color = AppColors.primary,
    this.filled = false,
    this.strokeWidth = 1.5,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _DiamondPainter(
        color: color,
        filled: filled,
        strokeWidth: strokeWidth,
      ),
    );
  }
}

class _DiamondPainter extends CustomPainter {
  final Color color;
  final bool filled;
  final double strokeWidth;

  const _DiamondPainter({
    required this.color,
    required this.filled,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 外菱形 M12 2 L22 12 L12 22 L2 12
    final outer = Path()
      ..moveTo(w * 0.5, 0)
      ..lineTo(w, h * 0.5)
      ..lineTo(w * 0.5, h)
      ..lineTo(0, h * 0.5)
      ..close();

    canvas.drawPath(
      outer,
      Paint()
        ..color = filled ? color : Colors.transparent
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      outer,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeJoin = StrokeJoin.round,
    );

    // 內菱形 M12 7 L17 12 L12 17 L7 12
    final inner = Path()
      ..moveTo(w * 0.5, h * 7 / 24)
      ..lineTo(w * 17 / 24, h * 0.5)
      ..lineTo(w * 0.5, h * 17 / 24)
      ..lineTo(w * 7 / 24, h * 0.5)
      ..close();

    canvas.drawPath(
      inner,
      Paint()
        ..color = filled
            ? Colors.white.withValues(alpha: 0.2)
            : color.withValues(alpha: 0.3)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      inner,
      Paint()
        ..color = filled ? Colors.white.withValues(alpha: 0.5) : color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_DiamondPainter old) =>
      old.color != color ||
      old.filled != filled ||
      old.strokeWidth != strokeWidth;
}

/// 菱形鏈（橫向裝飾線）
/// 對應 design-tokens.jsx TrukuChain
class TrukuChain extends StatelessWidget {
  final int count;
  final double size;
  final Color color;
  final double gap;

  const TrukuChain({
    super.key,
    this.count = 5,
    this.size = 12,
    this.color = AppColors.gold,
    this.gap = 4,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        return Padding(
          padding: EdgeInsets.only(right: i < count - 1 ? gap : 0),
          child: TrukuDiamond(
            size: size,
            color: color,
            filled: i.isEven,
            strokeWidth: 1.0,
          ),
        );
      }),
    );
  }
}
