import 'package:flutter/material.dart';

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
