import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../models/history_models.dart';
import '../../models/level_info.dart';
import '../../services/history_service.dart';
import '../../services/learn_service.dart';
import '../../services/user_service.dart';
import '../../shared/widgets/truku_widgets.dart';
import '../history/quiz_history_detail_screen.dart';
import 'lesson_card_screen.dart';
import 'quiz_placement_screen.dart';

class VocabLevelScreen extends StatefulWidget {
  const VocabLevelScreen({super.key});

  @override
  State<VocabLevelScreen> createState() => _VocabLevelScreenState();
}

class _VocabLevelScreenState extends State<VocabLevelScreen> {
  late Future<List<LevelInfo>> _levelsFuture;
  late Future<HistoryListResult> _recentQuizzesFuture;
  String? _quizSuggestedLevel;
  bool _suggestedLevelLoaded = false;

  @override
  void initState() {
    super.initState();
    _levelsFuture = LearnService.fetchLevels();
    _recentQuizzesFuture =
        HistoryService.fetchHistory(type: 'quiz', page: 1, pageSize: 5);
    _loadSuggestedLevel();
  }

  Future<void> _loadSuggestedLevel() async {
    try {
      final user = await UserService.fetchMe();
      if (!mounted) return;
      setState(() {
        _quizSuggestedLevel = user.quizSuggestedLevel;
        _suggestedLevelLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _suggestedLevelLoaded = true);
    }
  }

  Future<void> _goToPlacement() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const QuizPlacementScreen()),
    );
    _loadSuggestedLevel();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamLight,
      body: SafeArea(
        child: FutureBuilder<List<LevelInfo>>(
          future: _levelsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }
            if (snapshot.hasError) {
              return _buildError(snapshot.error);
            }
            final levels = snapshot.data ?? const [];
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                _buildHeader(),
                const SizedBox(height: 20),
                if (_suggestedLevelLoaded && _quizSuggestedLevel == null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: _PlacementBanner(onTap: _goToPlacement),
                  ),
                if (_suggestedLevelLoaded && _quizSuggestedLevel != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: _PlacementResultBanner(
                      level: _quizSuggestedLevel!,
                    ),
                  ),
                _buildSectionLabel('選擇級別'),
                const SizedBox(height: 10),
                if (levels.isEmpty)
                  Text(
                    '目前沒有可學習的級別',
                    style: GoogleFonts.notoSansTc(fontSize: 14, color: AppColors.fog),
                  )
                else
                  for (int i = 0; i < levels.length; i++) ...[
                    if (i > 0) const SizedBox(height: 12),
                    _LevelRow(
                      level: levels[i],
                      isRecommended: _suggestedLevelLoaded &&
                          _quizSuggestedLevel != null &&
                          levels[i].level == _quizSuggestedLevel,
                    ),
                  ],
                const SizedBox(height: 28),
                _buildSectionLabel('最近練習'),
                const SizedBox(height: 10),
                _buildRecentPractice(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildRecentPractice() {
    return FutureBuilder<HistoryListResult>(
      future: _recentQuizzesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
            ),
          );
        }
        final records = snapshot.data?.records ?? const [];
        if (records.isEmpty) {
          return Text(
            '尚無練習紀錄',
            style: GoogleFonts.notoSansTc(fontSize: 14, color: AppColors.fog),
          );
        }
        return Column(
          children: [
            for (int i = 0; i < records.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _RecentPracticeRow(
                record: records[i],
                onTap: () => _openQuizDetail(records[i]),
              ),
            ],
          ],
        );
      },
    );
  }

  void _openQuizDetail(HistoryRecord record) {
    if (!record.isCompleted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuizHistoryDetailScreen(
          sessionId: record.sessionId,
          level: record.level,
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back, color: AppColors.ink),
        ),
        const SizedBox(width: 12),
        Text(
          '單字測驗',
          style: GoogleFonts.notoSerifTc(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String label) {
    return Row(
      children: [
        const TrukuDiamond(size: 12, color: AppColors.primary, filled: true),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.notoSerifTc(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildError(Object? error) {
    final isUnauthorized = error is ApiException && error.isUnauthorized;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          isUnauthorized ? '請先登入' : '載入失敗，請稍後再試',
          style: GoogleFonts.notoSerifTc(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
      ),
    );
  }
}

Color _levelColor(String level) {
  if (level.contains('高')) {
    return level.contains('中') ? AppColors.primary : AppColors.fog;
  }
  if (level.contains('中')) return AppColors.gold;
  return AppColors.moss;
}

class _LevelRow extends StatelessWidget {
  final LevelInfo level;
  final bool isRecommended;

  const _LevelRow({required this.level, this.isRecommended = false});

  @override
  Widget build(BuildContext context) {
    final color = _levelColor(level.level);
    final textColor = isRecommended ? AppColors.creamLight : AppColors.ink;
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => LessonCardScreen(level: level.level)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isRecommended ? AppColors.ink : AppColors.cream,
          borderRadius: BorderRadius.circular(16),
          border: isRecommended
              ? null
              : Border.all(color: AppColors.creamDeep, width: 1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            _buildDiamond(color),
            const SizedBox(width: 14),
            Expanded(child: _buildTextArea(textColor)),
            TrukuChevron(
              color: isRecommended ? AppColors.creamLight : AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiamond(Color color) {
    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(52, 52),
            painter: _LevelDiamondPainter(color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildTextArea(Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          level.level,
          style: GoogleFonts.notoSerifTc(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: textColor,
            letterSpacing: 0.85,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${level.wordCount} 個單字',
          style: TextStyle(
            fontSize: 11,
            color: isRecommended ? AppColors.creamLight.withValues(alpha: 0.7) : AppColors.fog,
            letterSpacing: 0.55,
          ),
        ),
      ],
    );
  }
}

class _LevelDiamondPainter extends CustomPainter {
  final Color color;

  const _LevelDiamondPainter({required this.color});

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
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_LevelDiamondPainter old) => old.color != color;
}

class _RecentPracticeRow extends StatelessWidget {
  final HistoryRecord record;
  final VoidCallback onTap;

  const _RecentPracticeRow({required this.record, required this.onTap});

  String _scoreLabel() {
    if (record.isCompleted) {
      return '${record.score ?? 0} / ${record.totalQuestions}';
    }
    return '已答 ${record.answeredCount}/${record.totalQuestions}';
  }

  String _timeLabel() {
    final raw = record.completedAt ?? record.lastActiveAt;
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    final local = dt.toLocal();
    return '${local.year}/${local.month.toString().padLeft(2, '0')}/${local.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isCompleted = record.isCompleted;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.creamDeep),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _badge(record.statusLabel, AppColors.primary),
                  const SizedBox(height: 6),
                  Text(
                    record.level,
                    style: GoogleFonts.notoSerifTc(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _timeLabel(),
                    style: const TextStyle(fontSize: 11, color: AppColors.fog),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _scoreLabel(),
                  style: GoogleFonts.notoSerifTc(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isCompleted ? AppColors.primary : AppColors.fog,
                  ),
                ),
                const SizedBox(height: 4),
                const Icon(Icons.chevron_right, color: AppColors.fog, size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

class _PlacementResultBanner extends StatelessWidget {
  final String level;

  const _PlacementResultBanner({required this.level});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '你的推薦起始等級：$level',
        style: GoogleFonts.notoSerifTc(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.creamLight,
        ),
      ),
    );
  }
}

class _PlacementBanner extends StatelessWidget {
  final VoidCallback onTap;

  const _PlacementBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '還沒做過分級測驗',
                    style: GoogleFonts.notoSerifTc(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.creamLight,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '先做一次測驗，幫你找出適合的起始等級',
                    style: GoogleFonts.notoSansTc(
                      fontSize: 12,
                      color: AppColors.creamLight.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const TrukuChevron(color: AppColors.creamLight),
          ],
        ),
      ),
    );
  }
}
