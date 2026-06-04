import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import 'truku_painters.dart';

class ModeData {
  final String key;
  final String zh;
  final String truku;
  final String sub;
  final Color bg;
  final Color fg;
  final Color accent;
  final String icon;

  const ModeData({
    required this.key,
    required this.zh,
    required this.truku,
    required this.sub,
    required this.bg,
    required this.fg,
    required this.accent,
    required this.icon,
  });
}

class ModeCard extends StatelessWidget {
  final ModeData mode;
  final bool large;

  const ModeCard({super.key, required this.mode, this.large = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.hardEdge,
      constraints: BoxConstraints(minHeight: large ? 150 : 170),
      decoration: BoxDecoration(
        color: mode.bg,
        borderRadius: BorderRadius.circular(20),
        border: mode.bg == AppColors.creamLight
            ? Border.all(color: AppColors.creamDeep, width: 1.5)
            : null,
      ),
      child: Stack(
        children: [
          // 背景織紋
          Positioned.fill(
            child: Opacity(
              opacity: 0.12,
              child: CustomPaint(
                painter: TrukuWeavePainter(
                  color: mode.accent,
                  opacity: 1.0,
                  scale: 0.6,
                ),
              ),
            ),
          ),

          // 內容
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 頂部：icon 左，Truku 名右
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ModeIcon(name: mode.icon, color: mode.accent),
                    Text(
                      mode.truku.toUpperCase(),
                      style: GoogleFonts.crimsonPro(
                        fontStyle: FontStyle.italic,
                        fontSize: 11,
                        color: mode.accent,
                        letterSpacing: 2.6,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: large ? 44 : 58),

                // 底部：中文名 + 副標
                Text(
                  mode.zh,
                  style: GoogleFonts.notoSerifTc(
                    fontSize: large ? 26 : 22,
                    fontWeight: FontWeight.w600,
                    color: mode.fg,
                    letterSpacing: 1.0,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Opacity(
                  opacity: 0.7,
                  child: Text(
                    mode.sub,
                    style: TextStyle(
                      fontSize: 12,
                      color: mode.fg,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ModeIcon extends StatelessWidget {
  final String name;
  final Color color;

  const ModeIcon({super.key, required this.name, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(28, 28),
      painter: _ModeIconPainter(name: name, color: color),
    );
  }
}

class _ModeIconPainter extends CustomPainter {
  final String name;
  final Color color;

  const _ModeIconPainter({required this.name, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 28;
    canvas.scale(scale, scale);

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    switch (name) {
      case 'lesson':
        _drawLesson(canvas, stroke, fill);
      case 'film':
        _drawFilm(canvas, stroke, fill);
      case 'comm':
        _drawComm(canvas, stroke, fill);
      case 'plaza':
        _drawPlaza(canvas, stroke);
      case 'event':
        _drawEvent(canvas, stroke);
    }
  }

  void _drawLesson(Canvas canvas, Paint stroke, Paint fill) {
    canvas.drawRect(Rect.fromLTWH(4, 6, 20, 16), stroke);
    canvas.drawLine(const Offset(14, 6), const Offset(14, 22), stroke);
    canvas.drawLine(const Offset(8, 11), const Offset(12, 11), stroke);
    canvas.drawLine(const Offset(8, 15), const Offset(12, 15), stroke);
    canvas.drawLine(const Offset(16, 11), const Offset(20, 11), stroke);
    canvas.drawLine(const Offset(16, 15), const Offset(20, 15), stroke);
    canvas.drawCircle(const Offset(14, 6), 1.2, fill);
  }

  void _drawFilm(Canvas canvas, Paint stroke, Paint fill) {
    canvas.drawRRect(
      RRect.fromRectXY(Rect.fromLTWH(3, 6, 22, 16), 2, 2),
      stroke,
    );
    final tri = Path()
      ..moveTo(11, 11)
      ..lineTo(17, 14)
      ..lineTo(11, 17)
      ..close();
    canvas.drawPath(tri, fill);
    final thin = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawLine(const Offset(3, 10), const Offset(25, 10), thin);
    canvas.drawLine(const Offset(3, 18), const Offset(25, 18), thin);
  }

  void _drawComm(Canvas canvas, Paint stroke, Paint fill) {
    canvas.drawRRect(
      RRect.fromRectXY(Rect.fromLTWH(3, 8, 16, 12), 2, 2),
      stroke,
    );
    final tri = Path()
      ..moveTo(19, 12)
      ..lineTo(25, 9)
      ..lineTo(25, 19)
      ..lineTo(19, 16)
      ..close();
    canvas.drawPath(
      tri,
      Paint()
        ..color = color.withValues(alpha: 0.15)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(tri, stroke);
  }

  void _drawPlaza(Canvas canvas, Paint stroke) {
    canvas.drawCircle(const Offset(9, 10), 3, stroke);
    canvas.drawCircle(const Offset(19, 10), 3, stroke);
    final p1 = Path()
      ..moveTo(3, 22)
      ..cubicTo(3, 19, 6, 17, 9, 17)
      ..cubicTo(12, 17, 15, 19, 15, 22);
    canvas.drawPath(p1, stroke);
    final p2 = Path()
      ..moveTo(13, 22)
      ..cubicTo(13, 19, 16, 17, 19, 17)
      ..cubicTo(22, 17, 25, 19, 25, 22);
    canvas.drawPath(p2, stroke);
  }

  void _drawEvent(Canvas canvas, Paint stroke) {
    canvas.drawRRect(
      RRect.fromRectXY(Rect.fromLTWH(4, 6, 20, 18), 2, 2),
      stroke,
    );
    canvas.drawLine(const Offset(4, 11), const Offset(24, 11), stroke);
    canvas.drawLine(const Offset(9, 3), const Offset(9, 9), stroke);
    canvas.drawLine(const Offset(19, 3), const Offset(19, 9), stroke);
    final check = Path()
      ..moveTo(10, 16)
      ..lineTo(13, 19)
      ..lineTo(18, 14);
    canvas.drawPath(check, stroke);
  }

  @override
  bool shouldRepaint(covariant _ModeIconPainter old) =>
      old.name != name || old.color != color;
}
