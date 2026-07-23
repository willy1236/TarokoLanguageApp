import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../models/level_info.dart';
import '../../services/learn_service.dart';
import '../../shared/widgets/truku_painters.dart';
import '../../shared/widgets/truku_widgets.dart';
import '../history/history_screen.dart';
import 'lesson_card_screen.dart';

// ── LearnScreen ───────────────────────────────────────────────────────────────

class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key});

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  late Future<List<LevelInfo>> _levelsFuture;

  @override
  void initState() {
    super.initState();
    _levelsFuture = LearnService.fetchLevels();
  }

  Future<void> _reload() async {
    setState(() {
      _levelsFuture = LearnService.fetchLevels();
    });
    await _levelsFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamLight,
      body: FutureBuilder<List<LevelInfo>>(
        future: _levelsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _LearnLoading();
          }
          if (snapshot.hasError) {
            return _LearnError(error: snapshot.error, onRetry: _reload);
          }
          final levels = snapshot.data ?? const [];
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildHero(levels),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const TrukuDiamond(
                                    size: 14, color: AppColors.primary, filled: true),
                                const SizedBox(width: 8),
                                Text(
                                  '課程級別',
                                  style: GoogleFonts.notoSerifTc(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.ink,
                                    letterSpacing: 1.44,
                                  ),
                                ),
                              ],
                            ),
                            GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const HistoryScreen()),
                              ),
                              child: Text(
                                '測驗紀錄 →',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.primary,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (levels.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            '目前沒有可學習的級別',
                            style: GoogleFonts.notoSansTc(
                                fontSize: 14, color: AppColors.fog),
                          ),
                        )
                      else
                        for (int i = 0; i < levels.length; i++) ...[
                          if (i > 0) const SizedBox(height: 12),
                          _LevelRow(level: levels[i]),
                        ],
                    ],
                  ),
                ),
                const SizedBox(height: 120),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHero(List<LevelInfo> levels) {
    final totalWords = levels.fold<int>(0, (sum, l) => sum + l.wordCount);
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
                          text: '$totalWords',
                          style: GoogleFonts.notoSerifTc(
                            fontSize: 18,
                            color: AppColors.gold,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextSpan(
                          text: '　可學單字',
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
                          text: '${levels.length}',
                          style: GoogleFonts.notoSerifTc(
                            fontSize: 18,
                            color: AppColors.gold,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextSpan(
                          text: '　個級別',
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

class _LearnLoading extends StatelessWidget {
  const _LearnLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.primary),
    );
  }
}

class _LearnError extends StatelessWidget {
  final Object? error;
  final VoidCallback onRetry;

  const _LearnError({required this.error, required this.onRetry});

  bool get _isUnauthorized => error is ApiException && (error as ApiException).isUnauthorized;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _isUnauthorized ? '請先登入' : '載入失敗，請稍後再試',
              style: GoogleFonts.notoSerifTc(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
            if (!_isUnauthorized && error != null) ...[
              const SizedBox(height: 8),
              Text(
                error is ApiException ? (error as ApiException).message : '$error',
                textAlign: TextAlign.center,
                style: GoogleFonts.notoSansTc(fontSize: 13, color: AppColors.fog),
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.creamLight,
              ),
              child: const Text('重試'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── LevelRow ──────────────────────────────────────────────────────────────────

class _LevelRow extends StatelessWidget {
  final LevelInfo level;

  const _LevelRow({required this.level});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => LessonCardScreen(level: level.level)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.creamDeep, width: 1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            _buildDiamond(),
            const SizedBox(width: 14),
            Expanded(child: _buildTextArea()),
            CustomPaint(
              size: const Size(20, 20),
              painter: _ChevronPainter(color: AppColors.primary),
            ),
          ],
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
            painter: const _LevelDiamondPainter(),
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
          level.level,
          style: GoogleFonts.notoSerifTc(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
            letterSpacing: 0.85,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${level.wordCount} 個單字',
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.fog,
            letterSpacing: 0.55,
          ),
        ),
      ],
    );
  }
}

// ── Painters ──────────────────────────────────────────────────────────────────

class _LevelDiamondPainter extends CustomPainter {
  const _LevelDiamondPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final path = Path()
      ..moveTo(w * 26 / 52, h * 4 / 52)
      ..lineTo(w * 48 / 52, h * 26 / 52)
      ..lineTo(w * 26 / 52, h * 48 / 52)
      ..lineTo(w * 4 / 52, h * 26 / 52)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_LevelDiamondPainter old) => false;
}

class _ChevronPainter extends CustomPainter {
  final Color color;

  const _ChevronPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

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
