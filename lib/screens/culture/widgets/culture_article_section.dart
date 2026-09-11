// 文化頁「文章」分頁：分類 chip、排序、精選文章與清單。自己持有篩選狀態與
// 請求，切換影音／文章分頁時不影響影音那邊的狀態。

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../models/article_models.dart';
import '../../../services/article_service.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../../../shared/widgets/truku_painters.dart';
import '../article_detail_screen.dart';
import 'culture_cards.dart';
import 'culture_icons.dart';

class CultureArticleSection extends StatefulWidget {
  final bool seniorMode;

  const CultureArticleSection({super.key, required this.seniorMode});

  @override
  State<CultureArticleSection> createState() => _CultureArticleSectionState();
}

class _CultureArticleSectionState extends State<CultureArticleSection> {
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
  }

  @override
  Widget build(BuildContext context) => _buildArticleSection(widget.seniorMode);

  String? get _selectedArticleCategory => _articleChipIndex == 0
      ? null
      : ArticleCategory.all[_articleChipIndex - 1];

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

  Widget _buildArticleSection(bool seniorMode) {
    return FutureBuilder<ArticleListResponse>(
      future: _articlesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildArticleChips(seniorMode),
              _buildArticleSectionHeader(seniorMode),
            ],
          );
        }
        if (snapshot.hasError) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildArticleChips(seniorMode),
              _buildArticleSectionHeader(seniorMode),
              TrukuErrorView(
                error: snapshot.error,
                onRetry: _reloadArticles,
                seniorMode: seniorMode,
                fallback: '文章載入失敗，請稍後再試',
                topPadding: 16,
              ),
            ],
          );
        }
        final articles = snapshot.data!.articles;
        if (articles.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildArticleChips(seniorMode),
              _buildArticleSectionHeader(seniorMode),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Text(
                  '目前沒有文章',
                  style: TextStyle(
                    color: AppColors.fog,
                    fontSize: AppTypography.size(AppTypography.body, seniorMode: seniorMode),
                  ),
                ),
              ),
            ],
          );
        }
        final featured = articles.first;
        final rest = articles.skip(1).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildArticleChips(seniorMode),
            _buildArticleSectionHeader(seniorMode),
            _buildFeaturedArticle(featured, seniorMode),
            _buildArticleList(rest, seniorMode),
          ],
        );
      },
    );
  }

  Widget _buildArticleChips(bool seniorMode) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: List.generate(_articleChipLabels.length, (i) {
          final active = _articleChipIndex == i;
          return Padding(
            padding: EdgeInsets.only(
              right: i < _articleChipLabels.length - 1 ? 8 : 0,
            ),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _articleChipIndex = i;
                  _articlesFuture = _fetchArticles();
                });
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
                  _articleChipLabels[i],
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

  static const _articleSortOptions = [
    ('latest', '最新文章', '最新'),
    ('popular', '熱門文章', '熱門'),
    ('weekly_popular', '本週熱門文章', '本週熱門'),
  ];

  Widget _buildArticleSectionHeader(bool seniorMode) {
    final title = _articleSortOptions
        .firstWhere((opt) => opt.$1 == _articleSort)
        .$2;
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
                'patas kari',
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
              for (final opt in _articleSortOptions) ...[
                _articleSortLabel(opt.$1, opt.$3, seniorMode),
                if (opt != _articleSortOptions.last) const SizedBox(width: 10),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _articleSortLabel(String value, String label, bool seniorMode) {
    final active = _articleSort == value;
    return GestureDetector(
      onTap: () {
        if (_articleSort == value) return;
        setState(() {
          _articleSort = value;
          _articlesFuture = _fetchArticles();
        });
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

  // ── Featured Article ──────────────────────────────────────────────────────

  Widget _buildFeaturedArticle(ArticleSummary article, bool seniorMode) {
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
                height: seniorMode ? 140 : 120,
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.gold,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          ArticleCategory.label(article.category),
                          style: TextStyle(
                            fontSize: AppTypography.size(AppTypography.micro, seniorMode: seniorMode),
                            color: AppColors.ink,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2.8,
                          ),
                        ),
                      ),
                    ),
                    // 底部漸層遮罩，避免淺色封面圖讓標題文字失去對比而看不清（一般模式標題疊在圖上）
                    if (!seniorMode) ...[
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          height: 64,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black87],
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
                          style: AppTypography.serif(
                            fontSize: AppTypography.title,
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
                  ],
                ),
              ),
              // 摘要 / 統計列。精簡模式下改把標題移到這塊實色底色區塊顯示（而非疊在封面圖上），
              // 避免圖片色彩複雜時蓋掉放大後的標題文字，同時隱藏摘要維持密度精簡
              if (!seniorMode)
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
                            fontSize: AppTypography.caption,
                            color: AppColors.fog,
                            letterSpacing: 1.0,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const CultureArrowIcon(),
                    ],
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          article.title,
                          style: AppTypography.serif(
                            fontSize: AppTypography.display24,
                            fontWeight: FontWeight.w600,
                            color: AppColors.creamLight,
                            letterSpacing: 1.0,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const CultureArrowIcon(size: 24),
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

  Widget _buildArticleList(List<ArticleSummary> articles, bool seniorMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: articles
            .map(
              (a) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: CultureArticleCard(
                  item: a,
                  seniorMode: seniorMode,
                  onTap: () => _openArticle(a.id),
                ),
              ),
            )
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
