// 文化頁用到的小圖示與 hero 背景條紋 painter。

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class CultureStripePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.mossDeep.withValues(alpha: 0.6)
      ..strokeWidth = 0;

    const stripeWidth = 24.0;
    const gapWidth = 4.0;
    const period = stripeWidth + gapWidth;

    final path = Path();
    for (double x = -size.height; x < size.width + size.height; x += period) {
      path.addPolygon([
        Offset(x, 0),
        Offset(x + stripeWidth, 0),
        Offset(x + stripeWidth - size.height, size.height),
        Offset(x - size.height, size.height),
      ], true);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CulturePlayIcon extends StatelessWidget {
  final double size;
  final Color color;
  const CulturePlayIcon({super.key, required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _PlayIconPainter(color: color),
    );
  }
}

class _PlayIconPainter extends CustomPainter {
  final Color color;
  const _PlayIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CultureSearchIcon extends StatelessWidget {
  const CultureSearchIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: const Size(16, 16), painter: _SearchIconPainter());
  }
}

class _SearchIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    // circle
    canvas.drawCircle(
      Offset(size.width * 0.46, size.height * 0.46),
      size.width * 0.29,
      paint,
    );
    // line
    final r = size.width * 0.29;
    final cx = size.width * 0.46;
    final cy = size.height * 0.46;
    final angle = math.pi * 0.75;
    final x1 = cx + r * math.cos(angle);
    final y1 = cy + r * math.sin(angle);
    canvas.drawLine(
      Offset(x1, y1),
      Offset(size.width * 0.88, size.height * 0.88),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CultureArrowIcon extends StatelessWidget {
  final double size;
  const CultureArrowIcon({super.key, this.size = 16});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size(size, size), painter: _ArrowIconPainter());
  }
}

class _ArrowIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.fog
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(size.width * 0.2, size.height * 0.5)
      ..lineTo(size.width * 0.8, size.height * 0.5)
      ..moveTo(size.width * 0.53, size.height * 0.25)
      ..lineTo(size.width * 0.8, size.height * 0.5)
      ..lineTo(size.width * 0.53, size.height * 0.75);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
