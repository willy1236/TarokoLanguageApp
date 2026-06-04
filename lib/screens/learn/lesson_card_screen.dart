import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../shared/widgets/truku_painters.dart';
import '../../shared/widgets/truku_widgets.dart';

class LessonCardScreen extends StatelessWidget {
  const LessonCardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamLight,
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProgressBar(context),
            _buildUnitLabel(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Column(
                children: [
                  _buildMainCard(),
                  const SizedBox(height: 14),
                  _buildExampleCard(),
                  const SizedBox(height: 16),
                  _buildBottomButtons(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: CustomPaint(
              size: const Size(24, 24),
              painter: _BackArrowPainter(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Container(
                height: 6,
                color: AppColors.creamDeep,
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: 0.6,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primary, AppColors.gold],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '9 / 15',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12,
              color: AppColors.fog,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnitLabel() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'UNIT 02 · LUTUT',
            style: GoogleFonts.crimsonPro(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: AppColors.fog,
              letterSpacing: 2.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '家人稱謂',
            style: GoogleFonts.notoSerifTc(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: AppColors.inkSoft,
              letterSpacing: 0.9,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.1,
              child: CustomPaint(
                painter: TrukuWeavePainter(
                  color: AppColors.gold,
                  opacity: 1.0,
                  scale: 0.8,
                ),
              ),
            ),
          ),
          Positioned(
            top: 18,
            right: 18,
            child: Opacity(
              opacity: 0.6,
              child: TrukuDiamond(
                size: 26,
                color: AppColors.gold,
                strokeWidth: 1.2,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '聆聽 · 跟讀',
                  style: GoogleFonts.notoSansTc(
                    fontSize: 11,
                    color: AppColors.gold,
                    letterSpacing: 2.2,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 24),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 200),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Tama',
                        style: GoogleFonts.crimsonPro(
                          fontSize: 56,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w500,
                          color: AppColors.creamLight,
                          letterSpacing: 1.12,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '爸爸',
                        style: GoogleFonts.notoSerifTc(
                          fontSize: 22,
                          fontWeight: FontWeight.w500,
                          color: AppColors.gold,
                          letterSpacing: 3.3,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        '[ˈta.ma] · n. 父親；對男性長輩的稱呼',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          color: AppColors.creamLight.withValues(alpha: 0.5),
                          letterSpacing: 0.55,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.gold,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CustomPaint(
                              size: const Size(20, 20),
                              painter: _SpeakerIconPainter(color: AppColors.ink),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '播放發音',
                              style: GoogleFonts.notoSerifTc(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.ink,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.gold, width: 1),
                      ),
                      child: Center(
                        child: CustomPaint(
                          size: const Size(24, 24),
                          painter: _SlowIconPainter(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExampleCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(14),
        border: const Border(
          left: BorderSide(color: AppColors.primary, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'EXAMPLE · 例句',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.fog,
              letterSpacing: 1.65,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Mhuway su, tama.',
            style: GoogleFonts.crimsonPro(
              fontSize: 17,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w500,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '爸爸，謝謝你。',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.inkSoft,
              letterSpacing: 0.7,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.creamLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.creamDeep, width: 1.5),
            ),
            child: Center(
              child: Text(
                '再聽一次',
                style: GoogleFonts.notoSerifTc(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.inkSoft,
                  letterSpacing: 1.4,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  '我會了 →',
                  style: GoogleFonts.notoSerifTc(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.creamLight,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Painters ──────────────────────────────────────────────────────────────────

class _BackArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // M15 4 L7 12 L15 20 in 24×24
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
  bool shouldRepaint(_BackArrowPainter old) => false;
}

class _SpeakerIconPainter extends CustomPainter {
  final Color color;

  const _SpeakerIconPainter({required this.color});

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

    // Speaker cone body
    final body = Path()
      ..moveTo(w * 11 / 20, h * 5 / 20)
      ..lineTo(w * 6 / 20, h * 8 / 20)
      ..lineTo(w * 3 / 20, h * 8 / 20)
      ..lineTo(w * 3 / 20, h * 12 / 20)
      ..lineTo(w * 6 / 20, h * 12 / 20)
      ..lineTo(w * 11 / 20, h * 15 / 20)
      ..close();
    canvas.drawPath(body, paint);

    // Wave arcs
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
  bool shouldRepaint(_SpeakerIconPainter old) => old.color != color;
}

class _SlowIconPainter extends CustomPainter {
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

    // circle cx=12 cy=13 r=7 in 24×24
    canvas.drawCircle(
      Offset(w * 12 / 24, h * 13 / 24),
      w * 7 / 24,
      paint,
    );

    // clock hands M12 9v4l2 2
    final hands = Path()
      ..moveTo(w * 12 / 24, h * 9 / 24)
      ..lineTo(w * 12 / 24, h * 13 / 24)
      ..lineTo(w * 14 / 24, h * 15 / 24);
    canvas.drawPath(hands, paint);

    // top bar M9 3h6
    canvas.drawLine(
      Offset(w * 9 / 24, h * 3 / 24),
      Offset(w * 15 / 24, h * 3 / 24),
      paint,
    );
  }

  @override
  bool shouldRepaint(_SlowIconPainter old) => false;
}
