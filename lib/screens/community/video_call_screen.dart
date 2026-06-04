import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../shared/widgets/truku_painters.dart';

class VideoCallScreen extends StatefulWidget {
  const VideoCallScreen({super.key});

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  int _seconds = 222; // 03:42
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String get _timeLabel {
    final m = _seconds ~/ 60;
    final s = _seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  int get _remaining => (600 - _seconds).clamp(0, 600);
  String get _remainingLabel => '剩 ${_remaining ~/ 60} 分';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildFullScreenVideo(),
          _buildTopBar(),
          _buildPersonName(),
          _buildSelfView(),
          _buildTopicChip(),
          _buildControlBar(context),
        ],
      ),
    );
  }

  Widget _buildFullScreenVideo() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.mossDeep, AppColors.ink, AppColors.primaryDeep],
              stops: [0.0, 0.6, 1.0],
            ),
          ),
        ),
        Opacity(
          opacity: 0.1,
          child: CustomPaint(
            painter: TrukuWeavePainter(
              color: AppColors.gold,
              opacity: 1.0,
              scale: 1.0,
            ),
          ),
        ),
        // Simulated person silhouette
        Positioned(
          left: 0,
          right: 0,
          top: MediaQuery.of(context).size.height * 0.42 - 90,
          child: Center(
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: const Alignment(0, -0.3),
                  colors: [
                    AppColors.primaryLight.withValues(alpha: 0.5),
                    AppColors.primaryDeep,
                  ],
                ),
                border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.25),
                  width: 2,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                'B',
                style: GoogleFonts.notoSerifTc(
                  fontSize: 56,
                  fontWeight: FontWeight.w600,
                  color: AppColors.gold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 60,
      left: 20,
      right: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Timer chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.ink.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.recording,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _timeLabel,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 13,
                    color: AppColors.creamLight,
                    letterSpacing: 2.0,
                  ),
                ),
                Container(
                  width: 1,
                  height: 12,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  color: AppColors.creamLight.withValues(alpha: 0.25),
                ),
                Text(
                  _remainingLabel,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.creamLight.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          // More options
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.ink.withValues(alpha: 0.6),
            ),
            child: const Center(child: _DotsIcon()),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonName() {
    return Positioned(
      left: 0,
      right: 0,
      top: MediaQuery.of(context).size.height * 0.62,
      child: Column(
        children: [
          Text(
            'Bakan rudan',
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSerifTc(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: AppColors.creamLight,
              letterSpacing: 1.2,
              shadows: const [Shadow(color: Colors.black54, blurRadius: 12)],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '銅門部落 · 78 歲',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.creamLight.withValues(alpha: 0.85),
              letterSpacing: 2.5,
              shadows: const [Shadow(color: Colors.black54, blurRadius: 8)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelfView() {
    return Positioned(
      top: 110,
      right: 16,
      child: Container(
        width: 100,
        height: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.moss, AppColors.mossDeep],
          ),
          border: Border.all(
            color: AppColors.gold.withValues(alpha: 0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            Center(
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                  border: Border.all(color: AppColors.gold, width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text(
                  'S',
                  style: GoogleFonts.notoSerifTc(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.gold,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 6,
              left: 6,
              child: Text(
                '你',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.creamLight,
                  letterSpacing: 1.2,
                  shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopicChip() {
    return Positioned(
      left: 16,
      bottom: 150,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.gold.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.31)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'kari',
              style: GoogleFonts.crimsonPro(
                fontStyle: FontStyle.italic,
                fontSize: 11,
                color: AppColors.gold,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '主題：日常問候',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.gold,
                letterSpacing: 2.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlBar(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Color(0xF21C0F0D), Colors.transparent],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _ControlButton(icon: _ControlIcon.mic, label: '靜音'),
            _ControlButton(icon: _ControlIcon.cam, label: '鏡頭'),
            _ControlButton(icon: _ControlIcon.note, label: '筆記'),
            _ControlButton(
              icon: _ControlIcon.end,
              label: '結束',
              danger: true,
              onTap: () => Navigator.popUntil(context, (r) => r.isFirst),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Control button ────────────────────────────────────────────────────────────

enum _ControlIcon { mic, cam, note, end }

class _ControlButton extends StatelessWidget {
  final _ControlIcon icon;
  final String label;
  final bool danger;
  final VoidCallback? onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    this.danger = false,
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
                  : Colors.white.withValues(alpha: 0.12),
              border: danger
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
      case _ControlIcon.mic:
        return CustomPaint(size: const Size(22, 22), painter: _MicPainter());
      case _ControlIcon.cam:
        return CustomPaint(size: const Size(24, 24), painter: _CamPainter());
      case _ControlIcon.note:
        return CustomPaint(size: const Size(22, 22), painter: _NotePainter());
      case _ControlIcon.end:
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
    // Microphone body (filled rect with rx)
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 9 / 24, h * 3 / 24, w * 6 / 24, h * 12 / 24),
      Radius.circular(w * 3 / 24),
    );
    canvas.drawRRect(
        body, Paint()..color = AppColors.creamLight..style = PaintingStyle.fill);
    // Arc below
    final arcPath = Path()
      ..moveTo(w * 5 / 24, h * 11 / 24)
      ..quadraticBezierTo(w * 5 / 24, h * 18 / 24, w * 12 / 24, h * 18 / 24)
      ..quadraticBezierTo(w * 19 / 24, h * 18 / 24, w * 19 / 24, h * 11 / 24);
    canvas.drawPath(arcPath, p);
    // Stem
    canvas.drawLine(Offset(w * 12 / 24, h * 18 / 24),
        Offset(w * 12 / 24, h * 21 / 24), p);
  }

  @override
  bool shouldRepaint(_MicPainter _) => false;
}

class _CamPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cream = AppColors.creamLight;
    final w = size.width;
    final h = size.height;
    // Camera body rect
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 3 / 24, h * 6 / 24, w * 13 / 24, h * 12 / 24),
      Radius.circular(w * 2 / 24),
    );
    canvas.drawRRect(
        body,
        Paint()
          ..color = cream
          ..style = PaintingStyle.fill);
    // Lens triangle
    final tri = Path()
      ..moveTo(w * 16 / 24, h * 10 / 24)
      ..lineTo(w * 21 / 24, h * 7 / 24)
      ..lineTo(w * 21 / 24, h * 17 / 24)
      ..close();
    canvas.drawPath(tri, Paint()..color = cream..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(_CamPainter _) => false;
}

class _NotePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.creamLight
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final w = size.width;
    final h = size.height;
    // Document outline
    final doc = Path()
      ..moveTo(w * 5 / 24, h * 4 / 24)
      ..lineTo(w * 16 / 24, h * 4 / 24)
      ..lineTo(w * 19 / 24, h * 7 / 24)
      ..lineTo(w * 19 / 24, h * 20 / 24)
      ..lineTo(w * 5 / 24, h * 20 / 24)
      ..close();
    canvas.drawPath(doc, p);
    // Lines
    canvas.drawLine(Offset(w * 9 / 24, h * 11 / 24),
        Offset(w * 15 / 24, h * 11 / 24), p);
    canvas.drawLine(Offset(w * 9 / 24, h * 15 / 24),
        Offset(w * 13 / 24, h * 15 / 24), p);
  }

  @override
  bool shouldRepaint(_NotePainter _) => false;
}

class _EndPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // Phone handset rotated 135° — simplified as a filled phone path
    canvas.save();
    canvas.translate(w / 2, h / 2);
    canvas.rotate(2.356); // ~135 degrees
    canvas.translate(-w / 2, -h / 2);
    final path = Path()
      ..moveTo(w * 22 / 24, h * 16.92 / 24)
      ..lineTo(w * 22 / 24, h * 19 / 24)
      ..cubicTo(w * 22 / 24, h * 20.1 / 24, w * 21.1 / 24, h * 21 / 24,
          w * 19.82 / 24, h * 21 / 24)
      ..cubicTo(w * 17.33 / 24, h * 20.79 / 24, w * 15.19 / 24,
          h * 19.92 / 24, w * 11.19 / 24, h * 17.93 / 24)
      ..cubicTo(w * 8.4 / 24, h * 16.43 / 24, w * 7.57 / 24, h * 15.6 / 24,
          w * 5.07 / 24, h * 11.93 / 24)
      ..cubicTo(w * 2.79 / 24, h * 8.13 / 24, w * 2 / 24, h * 5.9 / 24,
          w * 2 / 24, h * 3.11 / 24)
      ..cubicTo(w * 2 / 24, h * 2.1 / 24, w * 2.9 / 24, h * 2 / 24,
          w * 4 / 24, h * 2 / 24)
      ..lineTo(w * 7 / 24, h * 2 / 24)
      ..cubicTo(w * 8.1 / 24, h * 2 / 24, w * 9 / 24, h * 2.72 / 24,
          w * 9 / 24, h * 3.72 / 24)
      ..cubicTo(w * 9.13 / 24, h * 4.68 / 24, w * 9.37 / 24, h * 5.63 / 24,
          w * 9.71 / 24, h * 6.53 / 24)
      ..cubicTo(w * 10.04 / 24, h * 7.11 / 24, w * 9.71 / 24, h * 8.11 / 24,
          w * 9.26 / 24, h * 8.64 / 24)
      ..lineTo(w * 8.09 / 24, h * 9.91 / 24)
      ..cubicTo(w * 10 / 24, h * 12.9 / 24, w * 13.1 / 24, h * 14.9 / 24,
          w * 14.09 / 24, h * 15.91 / 24)
      ..lineTo(w * 15.36 / 24, h * 14.64 / 24)
      ..cubicTo(w * 15.89 / 24, h * 14.19 / 24, w * 16.89 / 24,
          h * 13.96 / 24, w * 18 / 24, h * 14.29 / 24)
      ..cubicTo(w * 18.9 / 24, h * 14.63 / 24, w * 19.85 / 24,
          h * 14.87 / 24, w * 20.81 / 24, h * 15 / 24)
      ..cubicTo(w * 21.92 / 24, h * 15.08 / 24, w * 22 / 24, h * 15.8 / 24,
          w * 22 / 24, h * 16.92 / 24)
      ..close();
    canvas.drawPath(
        path, Paint()..color = AppColors.creamLight..style = PaintingStyle.fill);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_EndPainter _) => false;
}

// ─── More-options dots icon ────────────────────────────────────────────────────

class _DotsIcon extends StatelessWidget {
  const _DotsIcon();

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
    for (final cy in [size.height * 6 / 24, size.height * 12 / 24, size.height * 18 / 24]) {
      canvas.drawCircle(Offset(cx, cy), r, paint);
    }
  }

  @override
  bool shouldRepaint(_DotsPainter _) => false;
}
