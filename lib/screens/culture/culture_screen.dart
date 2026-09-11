import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../models/video_models.dart';
import '../../services/senior_mode_controller.dart';
import '../../services/video_service.dart';
import '../../shared/widgets/truku_painters.dart';
import 'article_search_screen.dart';
import 'video_detail_screen.dart';
import 'video_search_screen.dart';
import '../../shared/widgets/async_state_view.dart';
import 'widgets/culture_article_section.dart';
import 'widgets/culture_cards.dart';
import 'widgets/culture_icons.dart';

class CultureScreen extends StatefulWidget {
  /// 由外層（合併分頁的膠囊切換）注入，顯示在 hero 與影音/文章分頁之間。
  final Widget? topToggle;

  const CultureScreen({super.key, this.topToggle});

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

  @override
  void initState() {
    super.initState();
    _videosFuture = _fetchVideos();
    _featuredFuture = _fetchFeatured();
  }

  // 後端無獨立「精選」欄位/endpoint，改用本週熱門第一名頂替本週精選。
  Future<VideoSummary?> _fetchFeatured() async {
    final res = await VideoService.fetchVideos(
      sort: 'weekly_popular',
      pageSize: 1,
    );
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
          SliverToBoxAdapter(child: _buildTabBar(seniorMode)),
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

  Widget _buildHero(bool seniorMode) {
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
                        Text(
                          'LNGLUNGAN',
                          style: GoogleFonts.crimsonPro(
                            fontStyle: FontStyle.italic,
                            fontSize: 13,
                            color: AppColors.gold,
                            letterSpacing: 4.0,
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
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black.withValues(alpha: 0.4),
                              border: Border.all(
                                color: AppColors.gold.withValues(alpha: 0.25),
                              ),
                            ),
                            child: const Center(child: CultureSearchIcon()),
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
                      featured != null ? '本週精選 · 熱門' : '本週精選',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: seniorMode ? AppTypography.body : 11,
                        color: AppColors.gold,
                        letterSpacing: 4.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      featured?.title ?? '太魯閣族影音',
                      style: GoogleFonts.notoSerifTc(
                        fontSize: seniorMode ? 32 : 26,
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
                        fontSize: seniorMode ? AppTypography.subtitle : 12,
                        color: AppColors.creamLight.withValues(alpha: 0.7),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 14),
                    CulturePlayButton(
                      label: '立即觀看',
                      seniorMode: seniorMode,
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

  // ── Tab Bar ───────────────────────────────────────────────────────────────

  Widget _buildTabBar(bool seniorMode) {
    final tabs = [('影音', 'patas hngak'), ('文章', 'patas kari')];
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.cream.withValues(alpha: 0.09),
            width: 1,
          ),
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
                    padding: EdgeInsets.only(bottom: seniorMode ? 16 : 12),
                    child: Column(
                      children: [
                        Text(
                          tabs[i].$1,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.notoSerifTc(
                            fontSize: seniorMode ? AppTypography.headline : 16,
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
                            fontSize: seniorMode ? AppTypography.body : 10,
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
                    fontSize: seniorMode ? AppTypography.subtitle : 13,
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
                  fontSize: seniorMode ? AppTypography.title : 15,
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
                  fontSize: seniorMode ? AppTypography.body : 10,
                  color: AppColors.fog,
                  letterSpacing: 3.6,
                ),
              ),
            ],
          ),
          Row(
            children: [
              _sortLabel('latest', '最新', seniorMode),
              const SizedBox(width: 10),
              _sortLabel('popular', '熱門', seniorMode),
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
          fontSize: seniorMode ? AppTypography.subtitle : 12,
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
                    fontSize: seniorMode ? AppTypography.subtitle : 13,
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
