// 通話控制列按鈕、圖示 painter 與通話結束後的檢舉輸入框。

import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

// ─── Control button ────────────────────────────────────────────────────────────

enum CallControlIcon { mic, cam, end }

class CallControlButton extends StatelessWidget {
  final CallControlIcon icon;
  final String label;
  final bool danger;
  final bool active;
  final VoidCallback? onTap;

  const CallControlButton({
    super.key,
    required this.icon,
    required this.label,
    this.danger = false,
    this.active = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final size = danger ? 60.0 : 52.0;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: danger
                  ? const Color(0xFFD8392C)
                  : active
                  ? AppColors.dangerDark
                  : Colors.white.withValues(alpha: 0.12),
              border: danger || active
                  ? null
                  : Border.all(
                      color: AppColors.creamLight.withValues(alpha: 0.12),
                    ),
            ),
            child: Center(child: _buildIcon()),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: AppColors.creamLight.withValues(alpha: 0.85),
              letterSpacing: 2.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIcon() {
    switch (icon) {
      case CallControlIcon.mic:
        return CustomPaint(size: const Size(22, 22), painter: _MicPainter());
      case CallControlIcon.cam:
        return CustomPaint(
          size: const Size(24, 24),
          painter: const CallCamPainter(),
        );
      case CallControlIcon.end:
        return CustomPaint(size: const Size(26, 26), painter: _EndPainter());
    }
  }
}

// ─── Icon painters ─────────────────────────────────────────────────────────────

class _MicPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.creamLight
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final w = size.width;
    final h = size.height;
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 9 / 24, h * 3 / 24, w * 6 / 24, h * 12 / 24),
      Radius.circular(w * 3 / 24),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..color = AppColors.creamLight
        ..style = PaintingStyle.fill,
    );
    final arcPath = Path()
      ..moveTo(w * 5 / 24, h * 11 / 24)
      ..quadraticBezierTo(w * 5 / 24, h * 18 / 24, w * 12 / 24, h * 18 / 24)
      ..quadraticBezierTo(w * 19 / 24, h * 18 / 24, w * 19 / 24, h * 11 / 24);
    canvas.drawPath(arcPath, p);
    canvas.drawLine(
      Offset(w * 12 / 24, h * 18 / 24),
      Offset(w * 12 / 24, h * 21 / 24),
      p,
    );
  }

  @override
  bool shouldRepaint(_MicPainter _) => false;
}

/// 攝影機圖示；[slashed] 為 true 時畫成關閉狀態（淡化 + 紅色斜線）。
class CallCamPainter extends CustomPainter {
  const CallCamPainter({this.slashed = false});

  final bool slashed;

  @override
  void paint(Canvas canvas, Size size) {
    final cream = slashed
        ? AppColors.creamLight.withValues(alpha: 0.85)
        : AppColors.creamLight;
    final fill = Paint()
      ..color = cream
      ..style = PaintingStyle.fill;
    final w = size.width;
    final h = size.height;
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 3 / 24, h * 6 / 24, w * 13 / 24, h * 12 / 24),
      Radius.circular(w * 2 / 24),
    );
    canvas.drawRRect(body, fill);
    final tri = Path()
      ..moveTo(w * 16 / 24, h * 10 / 24)
      ..lineTo(w * 21 / 24, h * 7 / 24)
      ..lineTo(w * 21 / 24, h * 17 / 24)
      ..close();
    canvas.drawPath(tri, fill);
    if (!slashed) return;
    final slash = Paint()
      ..color = AppColors.danger
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(w * 2 / 24, h * 2 / 24),
      Offset(w * 22 / 24, h * 22 / 24),
      slash,
    );
  }

  @override
  bool shouldRepaint(CallCamPainter old) => old.slashed != slashed;
}

class _EndPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.save();
    canvas.translate(w / 2, h / 2);
    canvas.rotate(2.356);
    canvas.translate(-w / 2, -h / 2);
    final path = Path()
      ..moveTo(w * 22 / 24, h * 16.92 / 24)
      ..lineTo(w * 22 / 24, h * 19 / 24)
      ..cubicTo(
        w * 22 / 24,
        h * 20.1 / 24,
        w * 21.1 / 24,
        h * 21 / 24,
        w * 19.82 / 24,
        h * 21 / 24,
      )
      ..cubicTo(
        w * 17.33 / 24,
        h * 20.79 / 24,
        w * 15.19 / 24,
        h * 19.92 / 24,
        w * 11.19 / 24,
        h * 17.93 / 24,
      )
      ..cubicTo(
        w * 8.4 / 24,
        h * 16.43 / 24,
        w * 7.57 / 24,
        h * 15.6 / 24,
        w * 5.07 / 24,
        h * 11.93 / 24,
      )
      ..cubicTo(
        w * 2.79 / 24,
        h * 8.13 / 24,
        w * 2 / 24,
        h * 5.9 / 24,
        w * 2 / 24,
        h * 3.11 / 24,
      )
      ..cubicTo(
        w * 2 / 24,
        h * 2.1 / 24,
        w * 2.9 / 24,
        h * 2 / 24,
        w * 4 / 24,
        h * 2 / 24,
      )
      ..lineTo(w * 7 / 24, h * 2 / 24)
      ..cubicTo(
        w * 8.1 / 24,
        h * 2 / 24,
        w * 9 / 24,
        h * 2.72 / 24,
        w * 9 / 24,
        h * 3.72 / 24,
      )
      ..cubicTo(
        w * 9.13 / 24,
        h * 4.68 / 24,
        w * 9.37 / 24,
        h * 5.63 / 24,
        w * 9.71 / 24,
        h * 6.53 / 24,
      )
      ..cubicTo(
        w * 10.04 / 24,
        h * 7.11 / 24,
        w * 9.71 / 24,
        h * 8.11 / 24,
        w * 9.26 / 24,
        h * 8.64 / 24,
      )
      ..lineTo(w * 8.09 / 24, h * 9.91 / 24)
      ..cubicTo(
        w * 10 / 24,
        h * 12.9 / 24,
        w * 13.1 / 24,
        h * 14.9 / 24,
        w * 14.09 / 24,
        h * 15.91 / 24,
      )
      ..lineTo(w * 15.36 / 24, h * 14.64 / 24)
      ..cubicTo(
        w * 15.89 / 24,
        h * 14.19 / 24,
        w * 16.89 / 24,
        h * 13.96 / 24,
        w * 18 / 24,
        h * 14.29 / 24,
      )
      ..cubicTo(
        w * 18.9 / 24,
        h * 14.63 / 24,
        w * 19.85 / 24,
        h * 14.87 / 24,
        w * 20.81 / 24,
        h * 15 / 24,
      )
      ..cubicTo(
        w * 21.92 / 24,
        h * 15.08 / 24,
        w * 22 / 24,
        h * 15.8 / 24,
        w * 22 / 24,
        h * 16.92 / 24,
      )
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.creamLight
        ..style = PaintingStyle.fill,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_EndPainter _) => false;
}

// ─── More-options dots icon ────────────────────────────────────────────────────

class CallDotsIcon extends StatelessWidget {
  const CallDotsIcon({super.key});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: const Size(18, 18), painter: _DotsPainter());
}

class _DotsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.creamLight
      ..style = PaintingStyle.fill;
    final r = size.width * 1.5 / 24;
    final cx = size.width / 2;
    for (final cy in [
      size.height * 6 / 24,
      size.height * 12 / 24,
      size.height * 18 / 24,
    ]) {
      canvas.drawCircle(Offset(cx, cy), r, paint);
    }
  }

  @override
  bool shouldRepaint(_DotsPainter _) => false;
}

// ─── Call report dialog ─────────────────────────────────────────────────────

class CallReportDialog extends StatefulWidget {
  const CallReportDialog({super.key});

  @override
  State<CallReportDialog> createState() => _CallReportDialogState();
}

class _CallReportDialogState extends State<CallReportDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('檢舉此通話'),
    content: TextField(
      controller: _controller,
      maxLines: 3,
      maxLength: 500,
      decoration: const InputDecoration(hintText: '請說明檢舉原因'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('取消'),
      ),
      TextButton(
        onPressed: () => Navigator.of(context).pop(_controller.text),
        child: const Text('送出'),
      ),
    ],
  );
}
