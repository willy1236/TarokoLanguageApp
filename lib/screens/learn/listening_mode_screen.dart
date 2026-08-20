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
import '../history/listening_history_detail_screen.dart';
import 'listening_placement_screen.dart';
import 'listening_quiz_screen.dart';

Color _levelColor(String level) {
  if (level.contains('高')) {
    return level.contains('中') ? AppColors.primary : AppColors.fog;
  }
  if (level.contains('中')) return AppColors.gold;
  return AppColors.moss;
}

class _ModeOption {
  final String value;
  final String title;
  final String subtitle;

  const _ModeOption({
    required this.value,
    required this.title,
    required this.subtitle,
  });
}

const List<_ModeOption> _modeOptions = [
  _ModeOption(
    value: 'word_to_zh',
    title: '詞彙聽力．聽音辨義',
    subtitle: '聽 Truku 發音，選中文意思',
  ),
  _ModeOption(
    value: 'word_to_truku',
    title: '詞彙聽力．聽音辨詞',
    subtitle: '聽 Truku 發音，選正確 Truku 拼寫',
  ),
  _ModeOption(
    value: 'sentence_to_zh',
    title: '句子聽力．聽音辨義',
    subtitle: '聽 Truku 句子，選中文意思',
  ),
];

class ListeningModeScreen extends StatefulWidget {
  const ListeningModeScreen({super.key});

  @override
  State<ListeningModeScreen> createState() => _ListeningModeScreenState();
}

class _ListeningModeScreenState extends State<ListeningModeScreen> {
  late Future<List<LevelInfo>> _levelsFuture;
  late Future<HistoryListResult> _recentListeningFuture;
  String? _selectedMode;
  String? _selectedLevel;
  String? _listeningSuggestedLevel;
  bool _suggestedLevelLoaded = false;

  @override
  void initState() {
    super.initState();
    _levelsFuture = LearnService.fetchLevels();
    _recentListeningFuture =
        HistoryService.fetchHistory(type: 'listening', page: 1, pageSize: 5);
    _loadSuggestedLevel();
  }

  Future<void> _loadSuggestedLevel() async {
    try {
      final user = await UserService.fetchMe();
      if (!mounted) return;
      setState(() {
        _listeningSuggestedLevel = user.listeningSuggestedLevel;
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
      MaterialPageRoute(builder: (_) => const ListeningPlacementScreen()),
    );
    _loadSuggestedLevel();
  }

  void _start() {
    final mode = _selectedMode;
    final level = _selectedLevel;
    if (mode == null || level == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ListeningQuizScreen(mode: mode, level: level),
      ),
    );
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
                if (_suggestedLevelLoaded && _listeningSuggestedLevel == null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: _PlacementBanner(onTap: _goToPlacement),
                  ),
                if (_suggestedLevelLoaded && _listeningSuggestedLevel != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: _PlacementResultBanner(
                      level: _listeningSuggestedLevel!,
                    ),
                  ),
                _buildSectionLabel('選擇模式'),
                const SizedBox(height: 10),
                for (final option in _modeOptions) ...[
                  _ModeCard(
                    option: option,
                    selected: _selectedMode == option.value,
                    onTap: () => setState(() => _selectedMode = option.value),
                  ),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 12),
                _buildSectionLabel('選擇級別'),
                const SizedBox(height: 10),
                if (levels.isEmpty)
                  Text(
                    '目前沒有可用的級別',
                    style: GoogleFonts.notoSansTc(
                      fontSize: 14,
                      color: AppColors.fog,
                    ),
                  )
                else
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final level in levels)
                        _LevelChip(
                          level: level,
                          selected: _selectedLevel == level.level,
                          isRecommended: _suggestedLevelLoaded &&
                              _listeningSuggestedLevel != null &&
                              level.level == _listeningSuggestedLevel,
                          onTap: () =>
                              setState(() => _selectedLevel = level.level),
                        ),
                    ],
                  ),
                const SizedBox(height: 28),
                _buildStartButton(),
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
      future: _recentListeningFuture,
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
                onTap: () => _openListeningDetail(records[i]),
              ),
            ],
          ],
        );
      },
    );
  }

  void _openListeningDetail(HistoryRecord record) {
    if (!record.isCompleted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ListeningHistoryDetailScreen(
          sessionId: record.sessionId,
          level: record.level,
          modeLabel: record.modeLabel,
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
          '聽力測驗',
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

  Widget _buildStartButton() {
    final enabled = _selectedMode != null && _selectedLevel != null;
    return GestureDetector(
      onTap: enabled ? _start : null,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: enabled ? AppColors.primary : AppColors.creamDeep,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Text(
            '開始測驗',
            style: GoogleFonts.notoSerifTc(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: enabled ? AppColors.creamLight : AppColors.fog,
              letterSpacing: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError(Object? error) {
    final isUnauthorized = isAuthError(error);
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

class _ModeCard extends StatelessWidget {
  final _ModeOption option;
  final bool selected;
  final VoidCallback onTap;

  const _ModeCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.cream : AppColors.creamLight,
          borderRadius: BorderRadius.circular(14),
          border: Border(
            left: BorderSide(
              color: selected ? AppColors.primary : AppColors.creamDeep,
              width: 3,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              option.title,
              style: GoogleFonts.notoSerifTc(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.primary : AppColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              option.subtitle,
              style: GoogleFonts.notoSansTc(fontSize: 12, color: AppColors.fog),
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelChip extends StatelessWidget {
  final LevelInfo level;
  final bool selected;
  final bool isRecommended;
  final VoidCallback onTap;

  const _LevelChip({
    required this.level,
    required this.selected,
    required this.onTap,
    this.isRecommended = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = _levelColor(level.level);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color : AppColors.creamLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : AppColors.creamDeep,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: selected ? AppColors.creamLight : color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              level.level,
              style: GoogleFonts.notoSerifTc(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.creamLight : AppColors.inkSoft,
              ),
            ),
            if (isRecommended) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.star,
                size: 12,
                color: selected ? AppColors.creamLight : AppColors.gold,
              ),
            ],
          ],
        ),
      ),
    );
  }
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
                  Row(
                    children: [
                      _badge(record.statusLabel, AppColors.primary),
                      if (record.modeLabel != null) ...[
                        const SizedBox(width: 6),
                        _badge(record.modeLabel!, AppColors.moss),
                      ],
                    ],
                  ),
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
