import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../models/level_info.dart';
import '../../services/learn_service.dart';
import '../../shared/widgets/truku_painters.dart';
import '../../shared/widgets/truku_widgets.dart';
import '../history/history_screen.dart';
import 'listening_mode_screen.dart';
import 'vocab_level_screen.dart';

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
                    children: [
                      _QuizEntryCard(
                        icon: Icons.menu_book,
                        title: '單字測驗',
                        subtitle: '選級別，測驗詞彙',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const VocabLevelScreen()),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _QuizEntryCard(
                        icon: Icons.headphones,
                        title: '聽力測驗',
                        subtitle: '聽發音，選出正確答案',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ListeningModeScreen()),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _QuizEntryCard(
                        icon: Icons.history,
                        title: '測驗紀錄',
                        subtitle: '查看歷史測驗結果',
                        tone: _CardTone.primary,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const HistoryScreen()),
                        ),
                      ),
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

// ── QuizEntryCard ─────────────────────────────────────────────────────────────

enum _CardTone { dark, primary }

class _QuizEntryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final _CardTone tone;

  const _QuizEntryCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.tone = _CardTone.dark,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = tone == _CardTone.dark;
    final iconColor = isDark ? AppColors.gold : AppColors.creamLight;
    final titleColor = AppColors.creamLight;
    final subtitleColor = isDark ? AppColors.mist : AppColors.creamLight.withValues(alpha: 0.75);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: isDark ? AppColors.ink : AppColors.primary,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.notoSerifTc(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: titleColor,
                      letterSpacing: 0.85,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: subtitleColor,
                      letterSpacing: 0.55,
                    ),
                  ),
                ],
              ),
            ),
            TrukuChevron(color: iconColor),
          ],
        ),
      ),
    );
  }
}
