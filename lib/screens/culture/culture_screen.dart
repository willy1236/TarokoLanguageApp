import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../models/article_models.dart';
import '../../models/video_models.dart';
import '../../services/article_service.dart';
import '../../services/video_service.dart';
import '../../shared/widgets/truku_painters.dart';
import 'article_detail_screen.dart';
import 'video_detail_screen.dart';

class CultureScreen extends StatefulWidget {
  const CultureScreen({super.key});

  @override
  State<CultureScreen> createState() => _CultureScreenState();
}

class _CultureScreenState extends State<CultureScreen> {
  int _tabIndex = 0; // 0=影音, 1=文章
  int _chipIndex = 0;
  String _sort = 'latest'; // latest | popular
  late Future<VideoListResponse> _videosFuture;
  late Future<VideoSummary?> _featuredFuture;

  static final _chips = ['全部', ...VideoCategory.all.map(VideoCategory.label)];

  int _articleChipIndex = 0;
  String _articleSort = 'latest'; // latest | popular | weekly_popular
  late Future<ArticleListResponse> _articlesFuture;

  static final _articleChipLabels = [
    '全部',
    ...ArticleCategory.all.map(ArticleCategory.label),
  ];

  @override
  void initState() {
    super.initState();
    _articlesFuture = _fetchArticles();
    _videosFuture = _fetchVideos();
    _featuredFuture = _fetchFeatured();
  }

  String? get _selectedArticleCategory =>
      _articleChipIndex == 0 ? null : ArticleCategory.all[_articleChipIndex - 1];

  Future<ArticleListResponse> _fetchArticles() {
    return ArticleService.fetchArticles(
      category: _selectedArticleCategory,
      sort: _articleSort,
    );
  }

  void _reloadArticles() {
    setState(() {
      _articlesFuture = _fetchArticles();
    });
  }

  // 後端無獨立「精選」欄位/endpoint，改用本週熱門第一名頂替本週精選。
  Future<VideoSummary?> _fetchFeatured() async {
    final res =
        await VideoService.fetchVideos(sort: 'weekly_popular', pageSize: 1);
    return res.videos.isEmpty ? null : res.videos.first;
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
    return Scaffold(
      backgroundColor: AppColors.midnight,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHero()),
          SliverToBoxAdapter(child: _buildTabBar()),
          if (_tabIndex == 0) ...[
            SliverToBoxAdapter(child: _buildChips()),
            SliverToBoxAdapter(child: _buildVideoSectionHeader()),
            SliverToBoxAdapter(child: _buildVideoGrid()),
          ] else ...[
            SliverToBoxAdapter(child: _buildArticleSection()),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }

  // ── Hero ──────────────────────────────────────────────────────────────────

  Widget _buildHero() {
    return FutureBuilder<VideoSummary?>(
      future: _featuredFuture,
      builder: (context, snapshot) {
        final featured = snapshot.data;
        return SizedBox(
          height: 360,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 縮圖背景（有精選影片時）／漸層底色 + 裝飾占位圖案
              if (featured?.thumbnailUrl != null)
                Image.network(
                  featured!.thumbnailUrl!,
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
                    colors: [Colors.transparent, Colors.transparent, AppColors.midnight],
                  ),
                ),
              ),
              // 頂部 nav
              Positioned(
                top: 60,
                left: 20,
                right: 20,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'LNGLUNGAN',
                      style: GoogleFonts.crimsonPro(
                        fontStyle: FontStyle.italic,
                        fontSize: 13,
                        color: AppColors.gold,
                        letterSpacing: 4.0,
                      ),
                    ),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.4),
                        border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
                      ),
                      child: const Center(
                        child: _SearchIcon(),
                      ),
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
                      featured != null ? '本週精選 · 熱門' : '本週精選',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        color: AppColors.gold,
                        letterSpacing: 4.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      featured?.title ?? '太魯閣族影音',
                      style: GoogleFonts.notoSerifTc(
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                        color: AppColors.creamLight,
                        letterSpacing: 1.0,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      featured != null
                          ? '${VideoCategory.label(featured.category)}　|　本週 ${featured.weeklyViewCount} 次觀看'
                          : '精選內容載入中…',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.creamLight.withValues(alpha: 0.7),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _PlayButton(
                      label: '立即觀看',
                      onTap: featured == null
                          ? null
                          : () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      VideoDetailScreen(videoId: featured.id),
                                ),
                              );
                            },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
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
        CustomPaint(painter: _StripePainter()),
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

  // ── Tab Bar ───────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    final tabs = [
      ('影音', 'patas hngak'),
      ('文章', 'patas kari'),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.cream.withValues(alpha: 0.09), width: 1),
        ),
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final active = _tabIndex == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _tabIndex = i),
              behavior: HitTestBehavior.opaque,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      children: [
                        Text(
                          tabs[i].$1,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.notoSerifTc(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: active ? AppColors.gold : AppColors.fog,
                            letterSpacing: 2.0,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tabs[i].$2,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.crimsonPro(
                            fontStyle: FontStyle.italic,
                            fontSize: 10,
                            color: active
                                ? AppColors.cream.withValues(alpha: 0.7)
                                : AppColors.fog.withValues(alpha: 0.5),
                            letterSpacing: 2.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (active)
                    Positioned(
                      bottom: -1,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: FractionallySizedBox(
                          widthFactor: 0.6,
                          child: Container(height: 2, color: AppColors.gold),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Category Chips ────────────────────────────────────────────────────────

  Widget _buildChips() {
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: active ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: active
                      ? null
                      : Border.all(color: AppColors.cream.withValues(alpha: 0.19)),
                ),
                child: Text(
                  _chips[i],
                  style: TextStyle(
                    fontSize: 13,
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

  // ── Section Header ────────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title, String sub) {
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
                style: GoogleFonts.notoSerifTc(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.cream,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sub,
                style: GoogleFonts.crimsonPro(
                  fontStyle: FontStyle.italic,
                  fontSize: 10,
                  color: AppColors.fog,
                  letterSpacing: 3.6,
                ),
              ),
            ],
          ),
          Text(
            '查看全部 →',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.gold,
              letterSpacing: 2.4,
            ),
          ),
        ],
      ),
    );
  }

  // ── Video Section ────────────────────────────────────────────────────────

  Widget _buildVideoSectionHeader() {
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
                _sort == 'popular' ? '熱門影片' : '最新影片',
                style: GoogleFonts.notoSerifTc(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.cream,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'patas hngak',
                style: GoogleFonts.crimsonPro(
                  fontStyle: FontStyle.italic,
                  fontSize: 10,
                  color: AppColors.fog,
                  letterSpacing: 3.6,
                ),
              ),
            ],
          ),
          Row(
            children: [
              _sortLabel('latest', '最新'),
              const SizedBox(width: 10),
              _sortLabel('popular', '熱門'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sortLabel(String value, String label) {
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
          fontSize: 12,
          fontWeight: active ? FontWeight.w700 : FontWeight.w400,
          color: active ? AppColors.gold : AppColors.fog,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildVideoGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: FutureBuilder<VideoListResponse>(
        future: _videosFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.gold),
              ),
            );
          }
          if (snapshot.hasError) {
            final message = snapshot.error is ApiException
                ? (snapshot.error as ApiException).message
                : '影片載入失敗，請稍後再試';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  message,
                  style: TextStyle(color: AppColors.fog, fontSize: 13),
                ),
              ),
            );
          }
          final videos = snapshot.data!.videos;
          if (videos.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  '目前沒有影片',
                  style: TextStyle(color: AppColors.fog, fontSize: 13),
                ),
              ),
            );
          }
          return GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.78,
            children: videos.map((v) => _VideoCard(video: v)).toList(),
          );
        },
      ),
    );
  }

  // ── Article Section ──────────────────────────────────────────────────────

  Widget _buildArticleSection() {
    return FutureBuilder<ArticleListResponse>(
      future: _articlesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: _buildSectionHeader('族人寫的文章', 'patas kari'),
          );
        }
        if (snapshot.hasError) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('族人寫的文章', 'patas kari'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      snapshot.error is ApiException
                          ? (snapshot.error as ApiException).message
                          : '文章載入失敗，請稍後再試',
                      style: TextStyle(color: AppColors.fog, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: _reloadArticles,
                      child: const Text('重試'),
                    ),
                  ],
                ),
              ),
            ],
          );
        }
        final articles = snapshot.data!.articles;
        if (articles.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('族人寫的文章', 'patas kari'),
              _buildArticleChips(),
              _buildArticleSortRow(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Text('目前沒有文章', style: TextStyle(color: AppColors.fog, fontSize: 13)),
              ),
            ],
          );
        }
        final featured = articles.first;
        final rest = articles.skip(1).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('族人寫的文章', 'patas kari · 共 ${snapshot.data!.total} 篇'),
            _buildArticleChips(),
            _buildArticleSortRow(),
            _buildFeaturedArticle(featured),
            _buildArticleList(rest),
          ],
        );
      },
    );
  }

  Widget _buildArticleChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Row(
        children: List.generate(_articleChipLabels.length, (i) {
          final active = _articleChipIndex == i;
          return Padding(
            padding: EdgeInsets.only(right: i < _articleChipLabels.length - 1 ? 8 : 0),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _articleChipIndex = i;
                  _articlesFuture = _fetchArticles();
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: active ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: active
                      ? null
                      : Border.all(color: AppColors.cream.withValues(alpha: 0.19)),
                ),
                child: Text(
                  _articleChipLabels[i],
                  style: TextStyle(
                    fontSize: 13,
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

  Widget _buildArticleSortRow() {
    const options = [
      ('latest', '最新'),
      ('popular', '熱門'),
      ('weekly_popular', '本週熱門'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        children: options.map((opt) {
          final active = _articleSort == opt.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _articleSort = opt.$1;
                  _articlesFuture = _fetchArticles();
                });
              },
              child: Text(
                opt.$2,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                  color: active ? AppColors.gold : AppColors.fog,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Featured Article ──────────────────────────────────────────────────────

  Widget _buildFeaturedArticle(ArticleSummary article) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: GestureDetector(
        onTap: () => _openArticle(article.id),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.midnightSoft,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.cream.withValues(alpha: 0.06)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 圖片區
              SizedBox(
                height: 120,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (article.coverImageUrl != null)
                      Image.network(
                        article.coverImageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _articleCoverPlaceholder(),
                      )
                    else
                      _articleCoverPlaceholder(),
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.gold,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          ArticleCategory.label(article.category),
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.ink,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2.8,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 14,
                      left: 16,
                      right: 16,
                      child: Text(
                        article.title,
                        style: GoogleFonts.notoSerifTc(
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                          color: AppColors.creamLight,
                          letterSpacing: 1.0,
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              // 摘要 / 統計列
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        article.summary ?? '這篇文章還沒有摘要，點進去看看內容吧',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.fog,
                          letterSpacing: 1.0,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const _ArrowIcon(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _articleCoverPlaceholder() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.primaryDeep],
            ),
          ),
        ),
        CustomPaint(
          painter: TrukuWeavePainter(
            color: AppColors.gold,
            opacity: 0.25,
            scale: 0.7,
          ),
        ),
      ],
    );
  }

  // ── Article List ──────────────────────────────────────────────────────────

  Widget _buildArticleList(List<ArticleSummary> articles) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: articles
            .map((a) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ArticleCard(item: a, onTap: () => _openArticle(a.id)),
                ))
            .toList(),
      ),
    );
  }

  void _openArticle(int id) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ArticleDetailScreen(articleId: id)),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _PlayButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const _PlayButton({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.gold,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _PlayIcon(size: 12, color: AppColors.ink),
            const SizedBox(width: 10),
            Text(
              label,
              style: GoogleFonts.notoSerifTc(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
                letterSpacing: 2.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoCard extends StatelessWidget {
  final VideoSummary video;
  const _VideoCard({required this.video});

  static String _formatDuration(int? sec) {
    if (sec == null) return '--:--';
    final m = sec ~/ 60;
    final s = sec % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => VideoDetailScreen(videoId: video.id),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.midnightSoft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cream.withValues(alpha: 0.06)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 100,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (video.thumbnailUrl != null)
                    Image.network(
                      video.thumbnailUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _fallbackBackground(),
                    )
                  else
                    _fallbackBackground(),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        VideoCategory.label(video.category),
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.gold,
                          letterSpacing: 2.4,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        _formatDuration(video.durationSec),
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          color: AppColors.creamLight,
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.5),
                        border: Border.all(
                            color: AppColors.gold.withValues(alpha: 0.5)),
                      ),
                      child: const Center(
                        child: _PlayIcon(size: 12, color: AppColors.gold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.notoSerifTc(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.creamLight,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${video.viewCount} 次觀看',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.fog,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallbackBackground() {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.moss, AppColors.mossDeep],
            ),
          ),
        ),
        CustomPaint(
          painter: TrukuWeavePainter(
            color: AppColors.gold,
            opacity: 0.3,
            scale: 0.5,
          ),
        ),
      ],
    );
  }
}

class _ArticleCard extends StatelessWidget {
  final ArticleSummary item;
  final VoidCallback onTap;
  const _ArticleCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.midnightSoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cream.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.moss, AppColors.mossDeep],
                ),
              ),
              child: item.coverImageUrl != null
                  ? Image.network(
                      item.coverImageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _thumbnailPlaceholder(),
                    )
                  : _thumbnailPlaceholder(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      ArticleCategory.label(item.category),
                      style: TextStyle(
                        fontSize: 9,
                        color: AppColors.gold,
                        letterSpacing: 2.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.title,
                    style: GoogleFonts.notoSerifTc(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.creamLight,
                      letterSpacing: 0.5,
                      height: 1.35,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.viewCount} 閱讀 · 本週 ${item.weeklyViewCount}',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.fog,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const _ArrowIcon(),
          ],
        ),
      ),
    );
  }

  Widget _thumbnailPlaceholder() {
    return Stack(
      alignment: Alignment.center,
      children: [
        CustomPaint(
          size: const Size(64, 64),
          painter: TrukuWeavePainter(
            color: AppColors.gold,
            opacity: 0.4,
            scale: 0.4,
          ),
        ),
        Text(
          '文',
          style: GoogleFonts.notoSerifTc(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: AppColors.gold,
          ),
        ),
      ],
    );
  }
}

// ─── Painters / Icons ─────────────────────────────────────────────────────────

class _StripePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.mossDeep.withValues(alpha: 0.6)
      ..strokeWidth = 0;

    const stripeWidth = 24.0;
    const gapWidth = 4.0;
    const period = stripeWidth + gapWidth;

    final path = Path();
    for (double x = -size.height; x < size.width + size.height; x += period) {
      path.addPolygon([
        Offset(x, 0),
        Offset(x + stripeWidth, 0),
        Offset(x + stripeWidth - size.height, size.height),
        Offset(x - size.height, size.height),
      ], true);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PlayIcon extends StatelessWidget {
  final double size;
  final Color color;
  const _PlayIcon({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _PlayIconPainter(color: color),
    );
  }
}

class _PlayIconPainter extends CustomPainter {
  final Color color;
  const _PlayIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SearchIcon extends StatelessWidget {
  const _SearchIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(16, 16),
      painter: _SearchIconPainter(),
    );
  }
}

class _SearchIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    // circle
    canvas.drawCircle(
      Offset(size.width * 0.46, size.height * 0.46),
      size.width * 0.29,
      paint,
    );
    // line
    final r = size.width * 0.29;
    final cx = size.width * 0.46;
    final cy = size.height * 0.46;
    final angle = math.pi * 0.75;
    final x1 = cx + r * math.cos(angle);
    final y1 = cy + r * math.sin(angle);
    canvas.drawLine(
      Offset(x1, y1),
      Offset(size.width * 0.88, size.height * 0.88),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ArrowIcon extends StatelessWidget {
  const _ArrowIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(16, 16),
      painter: _ArrowIconPainter(),
    );
  }
}

class _ArrowIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.fog
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(size.width * 0.2, size.height * 0.5)
      ..lineTo(size.width * 0.8, size.height * 0.5)
      ..moveTo(size.width * 0.53, size.height * 0.25)
      ..lineTo(size.width * 0.8, size.height * 0.5)
      ..lineTo(size.width * 0.53, size.height * 0.75);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
