import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../shared/widgets/truku_painters.dart';
import '../../shared/widgets/truku_widgets.dart';
import 'lesson_card_screen.dart';

// ── 單元資料 ──────────────────────────────────────────────────────────────────

class _UnitData {
  final String num;
  final String zh;
  final String truku;
  final int words;
  final int done;
  final bool locked;
  final bool current;

  const _UnitData({
    required this.num,
    required this.zh,
    required this.truku,
    required this.words,
    required this.done,
    this.locked = false,
    this.current = false,
  });
}

// ── LearnScreen ───────────────────────────────────────────────────────────────

class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  static const _units = [
    _UnitData(num: '01', zh: '日常問候', truku: 'Smbarux', words: 12, done: 12),
    _UnitData(num: '02', zh: '家人稱謂', truku: 'Lutut', words: 18, done: 14, current: true),
    _UnitData(num: '03', zh: '部落地景', truku: 'Dgiyaq Alang', words: 16, done: 0),
    _UnitData(num: '04', zh: '狩獵與山林', truku: 'Mhuma Bgihur', words: 24, done: 0, locked: true),
    _UnitData(num: '05', zh: '織布與染色', truku: 'Tminun', words: 20, done: 0, locked: true),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamLight,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildHero(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 16),
                  child: Row(
                    children: [
                      const TrukuDiamond(size: 14, color: AppColors.primary, filled: true),
                      const SizedBox(width: 8),
                      Text(
                        '初階課程',
                        style: GoogleFonts.notoSerifTc(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                          letterSpacing: 1.44,
                        ),
                      ),
                    ],
                  ),
                ),
                for (int i = 0; i < _units.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  _UnitRow(unit: _units[i]),
                ],
              ],
            ),
          ),
          const SizedBox(height: 120),
        ],
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      color: AppColors.primary,
      child: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.2,
              child: CustomPaint(
                painter: TrukuWeavePainter(
                  color: AppColors.gold,
                  opacity: 1.0,
                  scale: 0.7,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 64, 24, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'KARI TRUKU · 族語學習',
                  style: GoogleFonts.crimsonPro(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: AppColors.gold,
                    letterSpacing: 3.0,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '一句一句，把話說回來',
                  style: GoogleFonts.notoSerifTc(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: AppColors.creamLight,
                    letterSpacing: 1.12,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    RichText(
                      text: TextSpan(children: [
                        TextSpan(
                          text: '26',
                          style: GoogleFonts.notoSerifTc(
                            fontSize: 18,
                            color: AppColors.gold,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextSpan(
                          text: '　已學單字',
                          style: GoogleFonts.notoSerifTc(
                            fontSize: 13,
                            color: AppColors.creamLight.withValues(alpha: 0.85),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(width: 16),
                    RichText(
                      text: TextSpan(children: [
                        TextSpan(
                          text: '2/5',
                          style: GoogleFonts.notoSerifTc(
                            fontSize: 18,
                            color: AppColors.gold,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextSpan(
                          text: '　完成單元',
                          style: GoogleFonts.notoSerifTc(
                            fontSize: 13,
                            color: AppColors.creamLight.withValues(alpha: 0.85),
                          ),
                        ),
                      ]),
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
}

// ── UnitRow ───────────────────────────────────────────────────────────────────

class _UnitRow extends StatelessWidget {
  final _UnitData unit;

  const _UnitRow({required this.unit});

  double get _pct => unit.words > 0 ? unit.done / unit.words : 0.0;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: unit.locked ? 0.5 : 1.0,
      child: GestureDetector(
        onTap: unit.locked
            ? null
            : () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LessonCardScreen()),
                ),
        child: Container(
          decoration: BoxDecoration(
            color: unit.current ? AppColors.ink : AppColors.cream,
            borderRadius: BorderRadius.circular(16),
            border: unit.current
                ? null
                : Border.all(color: AppColors.creamDeep, width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              _buildDiamond(),
              const SizedBox(width: 14),
              Expanded(child: _buildTextArea()),
              _buildIcon(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDiamond() {
    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(52, 52),
            painter: _UnitDiamondPainter(isCurrent: unit.current, pct: _pct),
          ),
          Text(
            unit.num,
            style: GoogleFonts.notoSerifTc(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: unit.current ? AppColors.creamLight : AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextArea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          unit.truku.toUpperCase(),
          style: GoogleFonts.crimsonPro(
            fontSize: 11,
            fontStyle: FontStyle.italic,
            color: unit.current ? AppColors.gold : AppColors.fog,
            letterSpacing: 1.65,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          unit.zh,
          style: GoogleFonts.notoSerifTc(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: unit.current ? AppColors.creamLight : AppColors.ink,
            letterSpacing: 0.85,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _progressLabel(),
          style: TextStyle(
            fontSize: 11,
            color: unit.current
                ? AppColors.creamLight.withValues(alpha: 0.7)
                : AppColors.fog,
            letterSpacing: 0.55,
          ),
        ),
      ],
    );
  }

  String _progressLabel() {
    if (unit.locked) return '完成上一單元解鎖';
    if (unit.done == unit.words) return '✓ 全部完成 · ${unit.words} 句';
    return '${unit.done} / ${unit.words} 句';
  }

  Widget _buildIcon() {
    if (unit.locked) {
      return CustomPaint(
        size: const Size(20, 20),
        painter: _LockIconPainter(),
      );
    }
    return CustomPaint(
      size: const Size(20, 20),
      painter: _ChevronPainter(
        color: unit.current ? AppColors.gold : AppColors.primary,
      ),
    );
  }
}

// ── Painters ──────────────────────────────────────────────────────────────────

class _UnitDiamondPainter extends CustomPainter {
  final bool isCurrent;
  final double pct;

  const _UnitDiamondPainter({required this.isCurrent, required this.pct});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // M26 4 L48 26 L26 48 L4 26 Z scaled from 52×52
    final path = Path()
      ..moveTo(w * 26 / 52, h * 4 / 52)
      ..lineTo(w * 48 / 52, h * 26 / 52)
      ..lineTo(w * 26 / 52, h * 48 / 52)
      ..lineTo(w * 4 / 52, h * 26 / 52)
      ..close();

    if (isCurrent) {
      canvas.drawPath(
        path,
        Paint()
          ..color = AppColors.primary
          ..style = PaintingStyle.fill,
      );
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = isCurrent ? AppColors.gold : AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeJoin = StrokeJoin.round,
    );

    if (pct > 0 && pct < 1) {
      final metrics = path.computeMetrics().toList();
      if (metrics.isNotEmpty) {
        final progressPath =
            metrics.first.extractPath(0, metrics.first.length * pct);
        canvas.drawPath(
          progressPath,
          Paint()
            ..color = AppColors.gold
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0
            ..strokeJoin = StrokeJoin.round
            ..strokeCap = StrokeCap.round,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_UnitDiamondPainter old) =>
      old.isCurrent != isCurrent || old.pct != pct;
}

class _LockIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()
      ..color = AppColors.fog
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // rect x=4 y=9 w=12 h=9 rx=1.5
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 4 / 20, h * 9 / 20, w * 12 / 20, h * 9 / 20),
        Radius.circular(w * 1.5 / 20),
      ),
      paint,
    );

    // M7 9 V6 arc(r=3) to (13,6) V9
    final shackle = Path()
      ..moveTo(w * 7 / 20, h * 9 / 20)
      ..lineTo(w * 7 / 20, h * 6 / 20)
      ..arcToPoint(
        Offset(w * 13 / 20, h * 6 / 20),
        radius: Radius.circular(w * 3 / 20),
        largeArc: false,
        clockwise: false,
      )
      ..lineTo(w * 13 / 20, h * 9 / 20);
    canvas.drawPath(shackle, paint);
  }

  @override
  bool shouldRepaint(_LockIconPainter old) => false;
}

class _ChevronPainter extends CustomPainter {
  final Color color;

  const _ChevronPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // M7 4 L13 10 L7 16
    final path = Path()
      ..moveTo(w * 7 / 20, h * 4 / 20)
      ..lineTo(w * 13 / 20, h * 10 / 20)
      ..lineTo(w * 7 / 20, h * 16 / 20);

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_ChevronPainter old) => old.color != color;
}
