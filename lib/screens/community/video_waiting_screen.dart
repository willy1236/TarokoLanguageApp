import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../shared/widgets/truku_painters.dart';
import '../../shared/widgets/truku_widgets.dart';
import 'video_call_screen.dart';

class VideoWaitingScreen extends StatefulWidget {
  const VideoWaitingScreen({super.key});

  @override
  State<VideoWaitingScreen> createState() => _VideoWaitingScreenState();
}

class _VideoWaitingScreenState extends State<VideoWaitingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Weave background
          Opacity(
            opacity: 0.08,
            child: CustomPaint(
              painter: TrukuWeavePainter(
                color: AppColors.gold,
                opacity: 1.0,
                scale: 1.2,
              ),
            ),
          ),
          // Radial gradient overlay
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.2),
                radius: 0.7,
                colors: [
                  Color(0x304A0F0C), // primary 30%
                  Colors.transparent,
                ],
              ),
            ),
          ),
          // Content
          Column(
            children: [
              _buildTopBar(context),
              Expanded(child: _buildCenter()),
              _buildCancelButton(context),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
              ),
              child: const Center(child: _XIcon()),
            ),
          ),
          const Expanded(
            child: Center(
              child: _SmtrungLabel(),
            ),
          ),
          const SizedBox(width: 36),
        ],
      ),
    );
  }

  Widget _buildCenter() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 220,
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Animated pulsing rings
              AnimatedBuilder(
                animation: _controller,
                builder: (_, child) => Stack(
                  alignment: Alignment.center,
                  children: List.generate(3, (i) {
                    final delay = i / 3.0;
                    final t = (_controller.value + delay) % 1.0;
                    final scale = 1.0 + t * 0.4 + i * 0.18;
                    final opacity = (0.5 - i * 0.12) * (1.0 - t);
                    return Transform.scale(
                      scale: scale,
                      child: Opacity(
                        opacity: opacity.clamp(0.0, 1.0),
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.gold,
                              width: 1.0,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              // Center circle with TrukuDiamond
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [AppColors.primary, AppColors.primaryDeep],
                  ),
                  border: Border.all(color: AppColors.gold, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.38),
                      blurRadius: 60,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: const Center(
                  child: TrukuDiamond(size: 70, color: AppColors.gold, strokeWidth: 1.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        GestureDetector(
          onTap: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const VideoCallScreen()),
          ),
          child: Text(
            '正在尋找',
            style: GoogleFonts.notoSerifTc(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: AppColors.creamLight,
              letterSpacing: 2.0,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCancelButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 50),
      child: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: AppColors.creamLight.withValues(alpha: 0.25),
            ),
          ),
          child: Text(
            '取消配對',
            style: GoogleFonts.notoSerifTc(
              fontSize: 14,
              color: AppColors.creamLight,
              letterSpacing: 2.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _XIcon extends StatelessWidget {
  const _XIcon();
  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: const Size(18, 18), painter: _XPainter());
  }
}

class _XPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.creamLight
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(size.width * 0.25, size.height * 0.25),
        Offset(size.width * 0.75, size.height * 0.75), paint);
    canvas.drawLine(Offset(size.width * 0.75, size.height * 0.25),
        Offset(size.width * 0.25, size.height * 0.75), paint);
  }

  @override
  bool shouldRepaint(_XPainter old) => false;
}

class _SmtrungLabel extends StatelessWidget {
  const _SmtrungLabel();
  @override
  Widget build(BuildContext context) {
    return Text(
      'SMTRUNG · 配對中',
      style: GoogleFonts.crimsonPro(
        fontStyle: FontStyle.italic,
        fontSize: 10,
        color: AppColors.gold,
        letterSpacing: 6.0,
      ),
    );
  }
}
