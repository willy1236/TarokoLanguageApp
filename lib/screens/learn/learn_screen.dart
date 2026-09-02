import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../models/level_info.dart';
import '../../services/learn_service.dart';
import '../../services/user_service.dart';
import '../../shared/widgets/truku_painters.dart';
import '../../shared/widgets/truku_widgets.dart';
import '../history/history_screen.dart';
import 'listening_mode_screen.dart';
import 'listening_placement_screen.dart';
import 'quiz_placement_screen.dart';
import 'vocab_level_screen.dart';

// ── LearnScreen ───────────────────────────────────────────────────────────────

class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key});

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  late Future<List<LevelInfo>> _levelsFuture;
  String? _quizSuggestedLevel;
  String? _listeningSuggestedLevel;
  bool _suggestedLevelLoaded = false;

  bool get _hasAnyPlacement =>
      _quizSuggestedLevel != null || _listeningSuggestedLevel != null;

  @override
  void initState() {
    super.initState();
    _levelsFuture = LearnService.fetchLevels();
    _loadSuggestedLevel();
  }

  Future<void> _reload() async {
    setState(() {
      _levelsFuture = LearnService.fetchLevels();
    });
    await _levelsFuture;
    await _loadSuggestedLevel();
  }

  Future<void> _loadSuggestedLevel() async {
    try {
      final user = await UserService.fetchMe();
      if (!mounted) return;
      setState(() {
        _quizSuggestedLevel = user.quizSuggestedLevel;
        _listeningSuggestedLevel = user.listeningSuggestedLevel;
        _suggestedLevelLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _suggestedLevelLoaded = true);
    }
  }

  Future<void> _goToVocabPlacement(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const QuizPlacementScreen()),
    );
    _loadSuggestedLevel();
  }

  Future<void> _goToListeningPlacement(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ListeningPlacementScreen()),
    );
    _loadSuggestedLevel();
  }

  void _showPlacementPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.creamLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '選擇分級測驗',
                  style: GoogleFonts.notoSerifTc(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 16),
                _PlacementOptionTile(
                  icon: Icons.menu_book,
                  title: '單字分級測驗',
                  subtitle: '測驗詞彙量，找出合適起始等級',
                  done: _quizSuggestedLevel != null,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _goToVocabPlacement(context);
                  },
                ),
                const SizedBox(height: 12),
                _PlacementOptionTile(
                  icon: Icons.headphones,
                  title: '聽力分級測驗',
                  subtitle: '測驗聽力理解，找出合適起始等級',
                  done: _listeningSuggestedLevel != null,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _goToListeningPlacement(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
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
                      if (_suggestedLevelLoaded && _hasAnyPlacement)
                        _PlacementSummaryCard(
                          quizLevel: _quizSuggestedLevel,
                          listeningLevel: _listeningSuggestedLevel,
                          onTap: () => _showPlacementPicker(context),
                        )
                      else
                        _PlacementQuizCard(
                          onTap: () => _showPlacementPicker(context),
                        ),
                      const SizedBox(height: 16),
                      _VocabQuizCard(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const VocabLevelScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _ListeningQuizCard(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ListeningModeScreen(),
                          ),
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
                          MaterialPageRoute(
                            builder: (_) => const HistoryScreen(),
                          ),
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
                      text: TextSpan(
                        children: [
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
                              color: AppColors.creamLight.withValues(
                                alpha: 0.85,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    RichText(
                      text: TextSpan(
                        children: [
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
                              color: AppColors.creamLight.withValues(
                                alpha: 0.85,
                              ),
                            ),
                          ),
                        ],
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
}

class _PlacementOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool done;
  final VoidCallback onTap;

  const _PlacementOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.done = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.creamDeep, width: 1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.notoSerifTc(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    done ? '已完成' : subtitle,
                    style: GoogleFonts.notoSansTc(
                      fontSize: 11,
                      color: AppColors.fog,
                    ),
                  ),
                ],
              ),
            ),
            const TrukuChevron(color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

// ── VocabQuizCard ─────────────────────────────────────────────────────────────

class _VocabQuizCard extends StatelessWidget {
  final VoidCallback onTap;

  const _VocabQuizCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Opacity(
                opacity: 0.15,
                child: CustomPaint(
                  painter: TrukuWeavePainter(
                    color: AppColors.gold,
                    opacity: 1.0,
                    scale: 0.7,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: TrukuDiamond(size: 40, color: AppColors.gold.withValues(alpha: 0.4)),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SLHAYAN · 單字測驗',
                  style: GoogleFonts.crimsonPro(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: AppColors.gold,
                    letterSpacing: 2.4,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '單字測驗',
                  style: GoogleFonts.notoSerifTc(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: AppColors.creamLight,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '選級別，測驗詞彙\n單字卡跟讀．答題挑戰',
                  style: GoogleFonts.notoSansTc(
                    fontSize: 13,
                    height: 1.5,
                    color: AppColors.mist,
                  ),
                ),
                const SizedBox(height: 18),
                _PillButton(
                  icon: Icons.menu_book,
                  label: '開始單字測驗',
                  background: AppColors.gold,
                  foreground: AppColors.ink,
                  onTap: onTap,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── ListeningQuizCard ─────────────────────────────────────────────────────────

class _ListeningQuizCard extends StatelessWidget {
  final VoidCallback onTap;

  const _ListeningQuizCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.mossDeep,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Opacity(
                opacity: 0.15,
                child: CustomPaint(
                  painter: TrukuWeavePainter(
                    color: AppColors.gold,
                    opacity: 1.0,
                    scale: 0.7,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: TrukuDiamond(size: 40, color: AppColors.gold.withValues(alpha: 0.4)),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ENDAAN · 聽力測驗',
                  style: GoogleFonts.crimsonPro(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: AppColors.gold,
                    letterSpacing: 2.4,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '聽力測驗',
                  style: GoogleFonts.notoSerifTc(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: AppColors.creamLight,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '聽發音，選出正確答案\n練耳朵．練反應',
                  style: GoogleFonts.notoSansTc(
                    fontSize: 13,
                    height: 1.5,
                    color: AppColors.mist,
                  ),
                ),
                const SizedBox(height: 18),
                _PillButton(
                  icon: Icons.headphones,
                  label: '開始聽力測驗',
                  background: AppColors.gold,
                  foreground: AppColors.ink,
                  onTap: onTap,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── PlacementSummaryCard ──────────────────────────────────────────────────────

class _PlacementSummaryCard extends StatelessWidget {
  final String? quizLevel;
  final String? listeningLevel;
  final VoidCallback onTap;

  const _PlacementSummaryCard({
    required this.quizLevel,
    required this.listeningLevel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.creamDeep, width: 1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            const TrukuDiamond(size: 28, color: AppColors.primary, filled: true),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '你的推薦起始等級',
                    style: GoogleFonts.notoSerifTc(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '單字 ${quizLevel ?? "尚未測驗"}．聽力 ${listeningLevel ?? "尚未測驗"}',
                    style: GoogleFonts.notoSansTc(
                      fontSize: 12,
                      color: AppColors.fog,
                    ),
                  ),
                ],
              ),
            ),
            const TrukuChevron(color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

// ── PlacementQuizCard ─────────────────────────────────────────────────────────

class _PlacementQuizCard extends StatelessWidget {
  final VoidCallback onTap;

  const _PlacementQuizCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.creamDeep, width: 1),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 16,
            right: 16,
            child: TrukuDiamond(size: 40, color: AppColors.primary.withValues(alpha: 0.15)),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SMRMUN · 分級測驗',
                  style: GoogleFonts.crimsonPro(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: AppColors.primary,
                    letterSpacing: 2.4,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '分級測驗',
                  style: GoogleFonts.notoSerifTc(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '先做一次測驗，找到最適合你的起始等級',
                  style: GoogleFonts.notoSansTc(
                    fontSize: 13,
                    height: 1.5,
                    color: AppColors.fog,
                  ),
                ),
                const SizedBox(height: 18),
                _PillButton(
                  icon: Icons.edit_note,
                  label: '開始測驗',
                  background: AppColors.primary,
                  foreground: AppColors.creamLight,
                  onTap: onTap,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  const _PillButton({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: foreground, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.notoSerifTc(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: foreground,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
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

  bool get _isUnauthorized => isAuthError(error);

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
                error is ApiException
                    ? (error as ApiException).message
                    : '$error',
                textAlign: TextAlign.center,
                style: GoogleFonts.notoSansTc(
                  fontSize: 13,
                  color: AppColors.fog,
                ),
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
    final subtitleColor = isDark
        ? AppColors.mist
        : AppColors.creamLight.withValues(alpha: 0.75);
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
