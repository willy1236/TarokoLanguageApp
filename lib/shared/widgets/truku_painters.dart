import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// 測驗畫面共用：返回箭頭
class BackArrowPainter extends CustomPainter {
  const BackArrowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final path = Path()
      ..moveTo(w * 15 / 24, h * 4 / 24)
      ..lineTo(w * 7 / 24, h * 12 / 24)
      ..lineTo(w * 15 / 24, h * 20 / 24);

    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(BackArrowPainter old) => false;
}

/// 測驗畫面共用：喇叭圖示（播放發音）
class SpeakerIconPainter extends CustomPainter {
  final Color color;

  const SpeakerIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final body = Path()
      ..moveTo(w * 11 / 20, h * 5 / 20)
      ..lineTo(w * 6 / 20, h * 8 / 20)
      ..lineTo(w * 3 / 20, h * 8 / 20)
      ..lineTo(w * 3 / 20, h * 12 / 20)
      ..lineTo(w * 6 / 20, h * 12 / 20)
      ..lineTo(w * 11 / 20, h * 15 / 20)
      ..close();
    canvas.drawPath(body, paint);

    final arc1 = Path()
      ..moveTo(w * 13 / 20, h * 8 / 20)
      ..quadraticBezierTo(w * 15 / 20, h * 10 / 20, w * 13 / 20, h * 12 / 20);
    canvas.drawPath(arc1, paint);

    final arc2 = Path()
      ..moveTo(w * 15 / 20, h * 6 / 20)
      ..quadraticBezierTo(w * 18 / 20, h * 10 / 20, w * 15 / 20, h * 14 / 20);
    canvas.drawPath(arc2, paint);
  }

  @override
  bool shouldRepaint(SpeakerIconPainter old) => old.color != color;
}

/// 測驗畫面共用：慢速播放圖示（時鐘）
class SlowIconPainter extends CustomPainter {
  const SlowIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()
      ..color = AppColors.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawCircle(
      Offset(w * 12 / 24, h * 13 / 24),
      w * 7 / 24,
      paint,
    );

    final hands = Path()
      ..moveTo(w * 12 / 24, h * 9 / 24)
      ..lineTo(w * 12 / 24, h * 13 / 24)
      ..lineTo(w * 14 / 24, h * 15 / 24);
    canvas.drawPath(hands, paint);

    canvas.drawLine(
      Offset(w * 9 / 24, h * 3 / 24),
      Offset(w * 15 / 24, h * 3 / 24),
      paint,
    );
  }

  @override
  bool shouldRepaint(SlowIconPainter old) => false;
}

/// 太魯閣菱形織紋背景 — puniri 祖靈之眼
/// 對應 design-tokens.jsx TrukuWeavePattern
class TrukuWeavePainter extends CustomPainter {
  final Color color;
  final double opacity;
  final double scale;

  const TrukuWeavePainter({
    this.color = const Color(0xFF7A1F1A),
    this.opacity = 0.12,
    this.scale = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double s = 24.0 * scale;

    final strokePaint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2 * scale;

    final innerFillPaint = Paint()
      ..color = color.withValues(alpha: opacity * 0.15)
      ..style = PaintingStyle.fill;

    final dotPaint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;

    for (double x = 0; x < size.width + s; x += s) {
      for (double y = 0; y < size.height + s; y += s) {
        // 外菱形
        final outer = Path()
          ..moveTo(x + s * 0.5, y + s * 0.1)
          ..lineTo(x + s * 0.9, y + s * 0.5)
          ..lineTo(x + s * 0.5, y + s * 0.9)
          ..lineTo(x + s * 0.1, y + s * 0.5)
          ..close();
        canvas.drawPath(outer, strokePaint);

        // 內菱形（帶半透明填充）
        final inner = Path()
          ..moveTo(x + s * 0.5, y + s * 0.3)
          ..lineTo(x + s * 0.7, y + s * 0.5)
          ..lineTo(x + s * 0.5, y + s * 0.7)
          ..lineTo(x + s * 0.3, y + s * 0.5)
          ..close();
        canvas.drawPath(inner, innerFillPaint);
        canvas.drawPath(inner, strokePaint);

        // 中心點
        canvas.drawCircle(Offset(x + s * 0.5, y + s * 0.5), 1.2 * scale, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(TrukuWeavePainter old) =>
      old.color != color || old.opacity != opacity || old.scale != scale;
}

/// 太魯閣峽谷山脈剪影 — 呼應太魯閣峽谷地景
/// 對應 design-tokens.jsx TrukuMountains
class TrukuMountainsPainter extends CustomPainter {
  final Color color;
  final double opacity;

  const TrukuMountainsPainter({
    this.color = const Color(0xFF0E0604),
    this.opacity = 0.8,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, h)
      ..lineTo(w * 0.08, h * 0.55)
      ..lineTo(w * 0.18, h * 0.70)
      ..lineTo(w * 0.28, h * 0.25)
      ..lineTo(w * 0.40, h * 0.50)
      ..lineTo(w * 0.50, h * 0.15)
      ..lineTo(w * 0.62, h * 0.55)
      ..lineTo(w * 0.72, h * 0.30)
      ..lineTo(w * 0.82, h * 0.60)
      ..lineTo(w * 0.92, h * 0.40)
      ..lineTo(w, h * 0.65)
      ..lineTo(w, h)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(TrukuMountainsPainter old) =>
      old.color != color || old.opacity != opacity;
}
