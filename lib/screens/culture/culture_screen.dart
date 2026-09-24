import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_icon_size.dart';
import '../../core/constants/app_typography.dart';
import '../../models/article_models.dart';
import '../../models/video_models.dart';
import '../../services/article_service.dart';
import '../../services/senior_mode_controller.dart';
import '../../services/video_service.dart';
import 'article_detail_screen.dart';
import 'article_search_screen.dart';
import 'video_detail_screen.dart';
import 'video_search_screen.dart';
import '../../shared/widgets/async_state_view.dart';
import 'widgets/culture_article_section.dart';
import 'widgets/culture_cards.dart';
import 'widgets/culture_featured_carousel.dart';

class CultureScreen extends StatefulWidget {
  /// 影音(0)/文章(1)。切換權在外層 LearnCultureScreen 固定在頂部的膠囊。
  final int cultureTabIndex;

  /// 使用者再次點擊底部「學習影音」時觸發：捲回頂部並重新整理目前分頁。
  final Listenable? reselectSignal;

  const CultureScreen({
    super.key,
    this.cultureTabIndex = 0,
    this.reselectSignal,
  });

  @override
  State<CultureScreen> createState() => _CultureScreenState();
}

class _CultureScreenState extends State<CultureScreen> {
  static const _featuredCount = 5;

  // 0=影音, 1=文章——切換權在外層膠囊，本頁只跟著 widget 走。
  int get _tabIndex => widget.cultureTabIndex;
  int _chipIndex = 0;
  String _sort = 'latest'; // latest | popular | weekly_popular
  late Future<VideoListResponse> _videosFuture;
  List<VideoSummary>? _featuredVideos;
  List<ArticleSummary>? _featuredArticles;
  final _scrollController = ScrollController();
  final _articleSectionKey = GlobalKey<CultureArticleSectionState>();

  static final _chips = ['全部', ...VideoCategory.all.map(VideoCategory.label)];

  static const _videoSortOptions = [
    ('latest', '最新影片', '最新'),
    ('popular', '熱門影片', '熱門'),
    ('weekly_popular', '本週熱門影片', '本週熱門'),
  ];

  @override
  void initState() {
    super.initState();
    _videosFuture = _fetchVideos();
    _loadFeaturedVideos();
    _loadFeaturedArticles();
    widget.reselectSignal?.addListener(_onReselect);
  }

  @override
  void didUpdateWidget(CultureScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reselectSignal != widget.reselectSignal) {
      oldWidget.reselectSignal?.removeListener(_onReselect);
      widget.reselectSignal?.addListener(_onReselect);
    }
    // 影音與文章共用同一條捲動，切分頁時回到頂部，不要停在另一頁的捲動位置。
    if (oldWidget.cultureTabIndex != widget.cultureTabIndex &&
        _scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  @override
  void dispose() {
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
    if (_tabIndex == 0) {
      _loadFeaturedVideos();
      _reloadVideos();
    } else {
      _loadFeaturedArticles();
      _articleSectionKey.currentState?.reload();
    }
  }

  // 後端無獨立「精選」欄位/endpoint，改用本週熱門前幾名當本週精選輪播。
  Future<void> _loadFeaturedVideos() async {
    try {
      final res = await VideoService.fetchVideos(
        sort: 'weekly_popular',
        pageSize: _featuredCount,
      );
      if (mounted) setState(() => _featuredVideos = res.videos);
    } catch (e) {
      debugPrint('CultureScreen._loadFeaturedVideos failed: $e');
      if (mounted) setState(() => _featuredVideos = const []);
    }
  }

  Future<void> _loadFeaturedArticles() async {
    try {
      final res = await ArticleService.fetchArticles(
        sort: 'weekly_popular',
        pageSize: _featuredCount,
      );
      if (mounted) setState(() => _featuredArticles = res.articles);
    } catch (e) {
      debugPrint('CultureScreen._loadFeaturedArticles failed: $e');
      if (mounted) setState(() => _featuredArticles = const []);
    }
  }

  String? get _selectedCategory =>
      _chipIndex == 0 ? null : VideoCategory.all[_chipIndex - 1];

  Future<VideoListResponse> _fetchVideos() {
    return VideoService.fetchVideos(category: _selectedCategory, sort: _sort);
  }

  void _reloadVideos() {
    setState(() {
      _videosFuture = _fetchVideos();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: seniorModeController,
      builder: (context, _) => _buildScaffold(seniorModeController.enabled),
    );
  }

  Widget _buildScaffold(bool seniorMode) {
    return ColoredBox(
      color: AppColors.midnight,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverToBoxAdapter(child: _buildFeatured(seniorMode)),
          if (_tabIndex == 0) ...[
            SliverToBoxAdapter(child: _buildChips(seniorMode)),
            SliverToBoxAdapter(child: _buildVideoSectionHeader(seniorMode)),
            SliverToBoxAdapter(child: _buildVideoGrid(seniorMode)),
          ],
          // 文章分頁常駐（只是隱藏），切回來時分類、排序與已載入的清單都還在。
          SliverToBoxAdapter(
            child: Offstage(
              offstage: _tabIndex != 1,
              child: CultureArticleSection(
                key: _articleSectionKey,
                seniorMode: seniorMode,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }

  // ── 本週精選輪播 ──────────────────────────────────────────────────────────

  Widget _buildFeatured(bool seniorMode) {
    if (_tabIndex == 1) {
      return CultureFeaturedCarousel(
        key: const ValueKey('featured_articles'),
        seniorMode: seniorMode,
        action: _buildSearchButton(seniorMode),
        items: _featuredArticles
            ?.map(
              (a) => CultureFeaturedItem(
                imageUrl: a.coverImageUrl,
                title: a.title,
                subtitle:
                    '${ArticleCategory.label(a.category)}　|　本週 ${a.weeklyViewCount} 次閱讀',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ArticleDetailScreen(articleId: a.id),
                  ),
                ),
              ),
            )
            .toList(),
      );
    }
    return CultureFeaturedCarousel(
      key: const ValueKey('featured_videos'),
      seniorMode: seniorMode,
      action: _buildSearchButton(seniorMode),
      items: _featuredVideos
          ?.map(
            (v) => CultureFeaturedItem(
              imageUrl: v.thumbnailUrl,
              title: v.title,
              subtitle:
                  '${VideoCategory.label(v.category)}　|　本週 ${v.weeklyViewCount} 次觀看',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => VideoDetailScreen(videoId: v.id),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  // 搜尋鈕沿用原本 hero 的位置：疊在精選卡右上角，不跟著輪播翻頁。
  Widget _buildSearchButton(bool seniorMode) {
    final size = seniorMode ? 48.0 : 40.0;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _tabIndex == 0
              ? const VideoSearchScreen()
              : const ArticleSearchScreen(),
        ),
      ),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.3),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
        ),
        child: Center(
          child: Icon(
            Icons.search,
            size: AppIconSize.action(seniorMode),
            color: AppColors.gold,
          ),
        ),
      ),
    );
  }

  // ── Category Chips ────────────────────────────────────────────────────────

  Widget _buildChips(bool seniorMode) {
    return CultureChipsRow(
      chips: Row(
        children: List.generate(_chips.length, (i) {
          final active = _chipIndex == i;
          return Padding(
            padding: EdgeInsets.only(right: i < _chips.length - 1 ? 8 : 0),
            child: GestureDetector(
              onTap: () {
                setState(() => _chipIndex = i);
                _reloadVideos();
              },
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: seniorMode ? 12 : 8,
                ),
                decoration: BoxDecoration(
                  color: active ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: active
                      ? null
                      : Border.all(
                          color: AppColors.cream.withValues(alpha: 0.19),
                        ),
                ),
                child: Text(
                  _chips[i],
                  style: TextStyle(
                    fontSize: AppTypography.size(
                      AppTypography.body,
                      seniorMode: seniorMode,
                    ),
                    color: active ? AppColors.creamLight : AppColors.cream,
                    letterSpacing: 2.0,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Video Section ────────────────────────────────────────────────────────

  Widget _buildVideoSectionHeader(bool seniorMode) {
    final title = _videoSortOptions.firstWhere((opt) => opt.$1 == _sort).$2;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.serif(
                  fontSize: AppTypography.size(
                    AppTypography.bodyLarge,
                    seniorMode: seniorMode,
                  ),
                  fontWeight: FontWeight.w600,
                  color: AppColors.cream,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'patas hngak',
                style: AppTypography.latin(
                  fontStyle: FontStyle.italic,
                  fontSize: AppTypography.size(
                    AppTypography.micro,
                    seniorMode: seniorMode,
                  ),
                  color: AppColors.fog,
                  letterSpacing: 3.6,
                ),
              ),
            ],
          ),
          Row(
            children: [
              for (final opt in _videoSortOptions) ...[
                _sortLabel(opt.$1, opt.$3, seniorMode),
                if (opt != _videoSortOptions.last) const SizedBox(width: 10),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _sortLabel(String value, String label, bool seniorMode) {
    final active = _sort == value;
    return GestureDetector(
      onTap: () {
        if (_sort == value) return;
        setState(() => _sort = value);
        _reloadVideos();
      },
      child: Text(
        label,
        style: TextStyle(
          fontSize: AppTypography.size(
            AppTypography.caption,
            seniorMode: seniorMode,
          ),
          fontWeight: active ? FontWeight.w700 : FontWeight.w400,
          color: active ? AppColors.gold : AppColors.fog,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildVideoGrid(bool seniorMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: FutureBuilder<VideoListResponse>(
        future: _videosFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const TrukuLoadingView(topPadding: 40);
          }
          if (snapshot.hasError) {
            return TrukuErrorView(
              error: snapshot.error,
              onRetry: _reloadVideos,
              seniorMode: seniorMode,
              fallback: '影片載入失敗，請稍後再試',
              topPadding: 24,
            );
          }
          final videos = snapshot.data!.videos;
          if (videos.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  '目前沒有影片',
                  style: TextStyle(
                    color: AppColors.fog,
                    fontSize: AppTypography.size(
                      AppTypography.body,
                      seniorMode: seniorMode,
                    ),
                  ),
                ),
              ),
            );
          }
          // 精簡模式下 2 欄改 1 欄，避免字級放大後卡片過擠（探索報告 8.1 節資訊密度原則）。
          // 改用固定 aspect ratio 的 Grid 會因放大後標題行高不固定而溢位，故精簡模式改用
          // 自然高度的 Column 逐張排列；一般模式維持原本 GridView 兩欄版面不變。
          if (seniorMode) {
            return Column(
              children: videos
                  .map(
                    (v) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: CultureVideoCard(video: v, seniorMode: true),
                    ),
                  )
                  .toList(),
            );
          }
          return GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.78,
            children: videos
                .map((v) => CultureVideoCard(video: v, seniorMode: false))
                .toList(),
          );
        },
      ),
    );
  }
}
