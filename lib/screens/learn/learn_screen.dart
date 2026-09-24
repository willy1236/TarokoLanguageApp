import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/level_info.dart';
import '../../services/learn_refresh_notifier.dart';
import '../../services/learn_service.dart';
import '../../services/user_service.dart';
import '../../shared/widgets/truku_painters.dart';
import '../history/history_screen.dart';
import 'listening_mode_screen.dart';
import 'listening_placement_screen.dart';
import 'quiz_placement_screen.dart';
import 'vocab_level_screen.dart';
import 'widgets/learn_cards.dart';
import '../../shared/widgets/async_state_view.dart';
import '../../core/constants/app_typography.dart';

// ── LearnScreen ───────────────────────────────────────────────────────────────

class LearnScreen extends StatefulWidget {
  /// 使用者再次點擊底部「學習影音」時觸發：捲回頂部並重新整理。
  final Listenable? reselectSignal;

  const LearnScreen({super.key, this.reselectSignal});

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  late Future<List<LevelInfo>> _levelsFuture;
  String? _quizSuggestedLevel;
  String? _listeningSuggestedLevel;
  bool _suggestedLevelLoaded = false;
  final _scrollController = ScrollController();

  bool get _hasAnyPlacement =>
      _quizSuggestedLevel != null || _listeningSuggestedLevel != null;

  @override
  void initState() {
    super.initState();
    _levelsFuture = LearnService.fetchLevels();
    _loadSuggestedLevel();
    // 本頁活在 IndexedStack 內只 initState 一次；測驗交卷後靠這條訂閱更新建議等級。
    LearnRefreshNotifier.revision.addListener(_reload);
    widget.reselectSignal?.addListener(_onReselect);
  }

  @override
  void didUpdateWidget(LearnScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reselectSignal != widget.reselectSignal) {
      oldWidget.reselectSignal?.removeListener(_onReselect);
      widget.reselectSignal?.addListener(_onReselect);
    }
  }

  @override
  void dispose() {
    LearnRefreshNotifier.revision.removeListener(_reload);
    widget.reselectSignal?.removeListener(_onReselect);
    _scrollController.dispose();
    super.dispose();
  }

  void _onReselect() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    }
    _reload();
  }

  Future<void> _reload() async {
    if (!mounted) return;
    setState(() {
      _levelsFuture = LearnService.fetchLevels();
    });
    await _levelsFuture;
    await _loadSuggestedLevel();
  }

  Future<void> _loadSuggestedLevel() async {
    try {
      // 分級測驗會在後端改寫建議等級，快取的 user 是舊的，必須強制重抓。
      final user = await UserService.fetchMe(forceRefresh: true);
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
                  style: AppTypography.serif(
                    fontSize: AppTypography.subtitle,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 16),
                LearnPlacementOptionTile(
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
                LearnPlacementOptionTile(
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
    return ColoredBox(
      color: AppColors.creamLight,
      child: FutureBuilder<List<LevelInfo>>(
        future: _levelsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const TrukuLoadingView();
          }
          if (snapshot.hasError) {
            return TrukuErrorView(error: snapshot.error, onRetry: _reload);
          }
          final levels = snapshot.data ?? const [];
          // 頭卡片跟著內容一起捲，膠囊切換已移到外層固定在頂部。
          return ListView(
            controller: _scrollController,
            padding: EdgeInsets.zero,
            children: [
              _buildHero(levels),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _suggestedLevelLoaded && _hasAnyPlacement
                        ? LearnPlacementSummaryCard(
                            quizLevel: _quizSuggestedLevel,
                            listeningLevel: _listeningSuggestedLevel,
                            onTap: () => _showPlacementPicker(context),
                          )
                        : LearnPlacementQuizCard(
                            onTap: () => _showPlacementPicker(context),
                          ),
                    const SizedBox(height: 16),
                    LearnVocabQuizCard(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const VocabLevelScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    LearnListeningQuizCard(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ListeningModeScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    LearnQuizEntryCard(
                      icon: Icons.history,
                      title: '測驗紀錄',
                      subtitle: '查看歷史測驗結果',
                      tone: LearnCardTone.primary,
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
            ],
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
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'KARI TRUKU · 族語學習',
                  style: AppTypography.latin(
                    fontSize: AppTypography.caption,
                    fontStyle: FontStyle.italic,
                    color: AppColors.gold,
                    letterSpacing: 3.0,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '一句一句，把話說回來',
                  style: AppTypography.serif(
                    fontSize: AppTypography.display28,
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
                            style: AppTypography.serif(
                              fontSize: AppTypography.subtitle,
                              color: AppColors.gold,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(
                            text: '　可學單字',
                            style: AppTypography.serif(
                              fontSize: AppTypography.body,
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
                            style: AppTypography.serif(
                              fontSize: AppTypography.subtitle,
                              color: AppColors.gold,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(
                            text: '　個級別',
                            style: AppTypography.serif(
                              fontSize: AppTypography.body,
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
