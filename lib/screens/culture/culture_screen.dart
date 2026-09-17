import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_icon_size.dart';
import '../../core/constants/app_typography.dart';
import '../../models/article_models.dart';
import '../../models/video_models.dart';
import '../../services/article_service.dart';
import '../../services/senior_mode_controller.dart';
import '../../services/video_service.dart';
import '../../shared/widgets/truku_painters.dart';
import 'article_detail_screen.dart';
import 'article_search_screen.dart';
import 'video_detail_screen.dart';
import 'video_search_screen.dart';
import '../../shared/widgets/async_state_view.dart';
import 'widgets/culture_article_section.dart';
import 'widgets/culture_cards.dart';
import 'widgets/culture_icons.dart';

class CultureScreen extends StatefulWidget {
  /// 由外層（合併分頁的膠囊切換）注入，顯示在 hero 下方。
  final Widget? topToggle;

  /// 影音(0)/文章(1)。原本是本頁內第二層 tab bar，已併入外層膠囊三格切換。
  final int cultureTabIndex;

  const CultureScreen({super.key, this.topToggle, this.cultureTabIndex = 0});

  @override
  State<CultureScreen> createState() => _CultureScreenState();
}

class _CultureScreenState extends State<CultureScreen> {
  // 0=影音, 1=文章——切換權在外層膠囊，本頁只跟著 widget 走。
  int get _tabIndex => widget.cultureTabIndex;
  int _chipIndex = 0;
  String _sort = 'latest'; // latest | popular | weekly_popular
  late Future<VideoListResponse> _videosFuture;
  late Future<VideoSummary?> _featuredFuture;
  late Future<ArticleSummary?> _featuredArticleFuture;

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
    _featuredFuture = _fetchFeatured();
    _featuredArticleFuture = _fetchFeaturedArticle();
  }

  // 後端無獨立「精選」欄位/endpoint，改用本週熱門第一名頂替本週精選。
  Future<VideoSummary?> _fetchFeatured() async {
    final res = await VideoService.fetchVideos(
      sort: 'weekly_popular',
      pageSize: 1,
    );
    return res.videos.isEmpty ? null : res.videos.first;
  }

  // 文章分頁的本週精選，同樣取本週熱門第一名。
  Future<ArticleSummary?> _fetchFeaturedArticle() async {
    final res = await ArticleService.fetchArticles(
      sort: 'weekly_popular',
      pageSize: 1,
    );
    return res.articles.isEmpty ? null : res.articles.first;
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
        slivers: [
          SliverToBoxAdapter(child: _buildHero(seniorMode)),
          if (widget.topToggle != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: widget.topToggle,
              ),
            ),
          if (_tabIndex == 0) ...[
            SliverToBoxAdapter(child: _buildChips(seniorMode)),
            SliverToBoxAdapter(child: _buildVideoSectionHeader(seniorMode)),
            SliverToBoxAdapter(child: _buildVideoGrid(seniorMode)),
          ],
          // 文章分頁常駐（只是隱藏），切回來時分類、排序與已載入的清單都還在。
          SliverToBoxAdapter(
            child: Offstage(
              offstage: _tabIndex != 1,
              child: CultureArticleSection(seniorMode: seniorMode),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }

  // ── Hero ──────────────────────────────────────────────────────────────────

  // 本週精選依目前分頁切換：影音分頁顯示本週熱門影片，文章分頁顯示本週熱門文章。
  Widget _buildHero(bool seniorMode) {
    if (_tabIndex == 1) {
      return FutureBuilder<ArticleSummary?>(
        future: _featuredArticleFuture,
        builder: (context, snapshot) {
          final article = snapshot.data;
          return _buildHeroContent(
            seniorMode: seniorMode,
            hasData: article != null,
            imageUrl: article?.coverImageUrl,
            title: article?.title ?? '太魯閣族文章',
            subtitle: article == null
                ? null
                : '${ArticleCategory.label(article.category)}　|　本週 ${article.weeklyViewCount} 次閱讀',
            buttonLabel: '立即閱讀',
            onTap: article == null
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          ArticleDetailScreen(articleId: article.id),
                    ),
                  ),
          );
        },
      );
    }
    return FutureBuilder<VideoSummary?>(
      future: _featuredFuture,
      builder: (context, snapshot) {
        final video = snapshot.data;
        return _buildHeroContent(
          seniorMode: seniorMode,
          hasData: video != null,
          imageUrl: video?.thumbnailUrl,
          title: video?.title ?? '太魯閣族影音',
          subtitle: video == null
              ? null
              : '${VideoCategory.label(video.category)}　|　本週 ${video.weeklyViewCount} 次觀看',
          buttonLabel: '立即觀看',
          onTap: video == null
              ? null
              : () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => VideoDetailScreen(videoId: video.id),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildHeroContent({
    required bool seniorMode,
    required bool hasData,
    required String? imageUrl,
    required String title,
    required String? subtitle,
    required String buttonLabel,
    required VoidCallback? onTap,
  }) {
    return SizedBox(
      height: 320,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 封面背景（有精選內容時）／漸層底色 + 裝飾占位圖案
          if (imageUrl != null)
            Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _heroFallbackDecoration(),
            )
          else
            _heroFallbackDecoration(),
          // 漸層遮罩
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.5, 1.0],
                colors: [
                  Colors.transparent,
                  Colors.transparent,
                  AppColors.midnight,
                ],
              ),
            ),
          ),
          // 頂部 nav
          Positioned(
            top: 60,
            left: 20,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 精選標題移到左上角，取代原本的 LNGLUNGAN 標記。
                    Expanded(
                      child: Text(
                        hasData ? '本週精選 · 熱門' : '本週精選',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.mono(
                          fontSize: AppTypography.size(
                            AppTypography.caption,
                            seniorMode: seniorMode,
                          ),
                          color: AppColors.gold,
                          letterSpacing: 4.0,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => _tabIndex == 0
                              ? const VideoSearchScreen()
                              : const ArticleSearchScreen(),
                        ),
                      ),
                      child: Container(
                        // 實機回報圖示太小不好按，圓鈕連同熱區一起放大。
                        width: seniorMode ? 52 : 46,
                        height: seniorMode ? 52 : 46,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.4),
                          border: Border.all(
                            color: AppColors.gold.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.search,
                            size: AppIconSize.action(seniorMode),
                            color: AppColors.gold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Hero info
          Positioned(
            bottom: 24,
            left: 20,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.serif(
                    fontSize: seniorMode
                        ? AppTypography.display32
                        : AppTypography.display26,
                    fontWeight: FontWeight.w600,
                    color: AppColors.creamLight,
                    letterSpacing: 1.0,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle ?? '精選內容載入中…',
                  style: TextStyle(
                    fontSize: AppTypography.size(AppTypography.caption, seniorMode: seniorMode),
                    color: AppColors.creamLight.withValues(alpha: 0.7),
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 14),
                CulturePlayButton(
                  label: buttonLabel,
                  seniorMode: seniorMode,
                  onTap: onTap,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 沒有真實縮圖時的裝飾占位背景（漸層 + 條紋 + 織紋）
  Widget _heroFallbackDecoration() {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.mossDeep, AppColors.midnight],
            ),
          ),
        ),
        CustomPaint(painter: CultureStripePainter()),
        CustomPaint(
          painter: TrukuWeavePainter(
            color: AppColors.gold,
            opacity: 0.25,
            scale: 1.0,
          ),
        ),
      ],
    );
  }

  // ── Category Chips ────────────────────────────────────────────────────────

  Widget _buildChips(bool seniorMode) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
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
                    fontSize: AppTypography.size(AppTypography.body, seniorMode: seniorMode),
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
                  fontSize: AppTypography.size(AppTypography.bodyLarge, seniorMode: seniorMode),
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
                  fontSize: AppTypography.size(AppTypography.micro, seniorMode: seniorMode),
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
          fontSize: AppTypography.size(AppTypography.caption, seniorMode: seniorMode),
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
                    fontSize: AppTypography.size(AppTypography.body, seniorMode: seniorMode),
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
