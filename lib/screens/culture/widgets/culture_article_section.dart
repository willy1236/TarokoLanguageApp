// 文化頁「文章」分頁：分類 chip、排序、精選文章與清單。自己持有篩選狀態與
// 請求，切換影音／文章分頁時不影響影音那邊的狀態。

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../models/article_models.dart';
import '../../../models/content_category.dart';
import '../../../services/article_service.dart';
import '../../../services/category_service.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../article_detail_screen.dart';
import 'culture_cards.dart';

class CultureArticleSection extends StatefulWidget {
  final bool seniorMode;

  const CultureArticleSection({super.key, required this.seniorMode});

  @override
  State<CultureArticleSection> createState() => CultureArticleSectionState();
}

class CultureArticleSectionState extends State<CultureArticleSection> {
  /// 選中的文章分類 value，null 是「全部」。
  String? _selectedArticleCategory;

  /// 後端的文章分類清單；還沒抓到（或第一次就失敗）時是 null，篩選列只有「全部」。
  List<ContentCategory>? _articleCategories;

  /// 最近一次載入分類的工作，外層精選輪播組 subtitle 前等它；不會失敗。
  Future<void> categoriesLoad = Future.value();
  String _articleSort = 'latest'; // latest | popular | weekly_popular
  late Future<ArticleListResponse> _articlesFuture;

  @override
  void initState() {
    super.initState();
    _articlesFuture = _fetchArticles();
    loadCategories(refresh: true);
  }

  @override
  Widget build(BuildContext context) => _buildArticleSection(widget.seniorMode);

  Future<ArticleListResponse> _fetchArticles() {
    return ArticleService.fetchArticles(
      category: _selectedArticleCategory,
      sort: _articleSort,
    );
  }

  /// 外層（再次點擊底部分頁、管理員改了文章）要求重新整理時呼叫，分類一起重抓。
  void reload() {
    loadCategories(refresh: true);
    _reloadArticles();
  }

  /// 載入文章分類清單。[refresh] 為 false 時有快取就用快取（切進文化分頁時）。
  /// 失敗時保留上次的篩選列與選擇；回傳的 Future 不會失敗。
  Future<void> loadCategories({bool refresh = false}) {
    return categoriesLoad = _doLoadCategories(refresh);
  }

  Future<void> _doLoadCategories(bool refresh) async {
    final List<ContentCategory> list;
    try {
      list = await CategoryService.fetch(
        CategoryModule.articles,
        refresh: refresh,
      );
    } catch (e) {
      debugPrint('CultureArticleSection.loadCategories failed: $e');
      return;
    }
    if (!mounted) return;
    // 選中的分類已不在篩選列（被刪或沒有文章了）：切回「全部」並重查。
    final selected = _selectedArticleCategory;
    final dropped =
        selected != null &&
        !_visibleCategories(list).any((c) => c.value == selected);
    setState(() {
      _articleCategories = list;
      if (dropped) {
        _selectedArticleCategory = null;
        _articlesFuture = _fetchArticles();
      }
    });
  }

  /// 篩選列只顯示有文章的分類，照後端順序。
  static List<ContentCategory> _visibleCategories(List<ContentCategory> list) =>
      list.where((c) => c.count > 0).toList();

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
                    fontSize: AppTypography.size(
                      AppTypography.body,
                      seniorMode: seniorMode,
                    ),
                  ),
                ),
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildArticleChips(seniorMode),
            _buildArticleSectionHeader(seniorMode),
            _buildArticleList(articles, seniorMode),
          ],
        );
      },
    );
  }

  Widget _buildArticleChips(bool seniorMode) {
    // 第一顆固定是「全部」（value null），其後照後端順序。
    final chips = <(String?, String)>[
      (null, '全部'),
      for (final c in _visibleCategories(_articleCategories ?? const []))
        (c.value, c.label),
    ];
    return CultureChipsRow(
      chips: Row(
        children: List.generate(chips.length, (i) {
          final (value, label) = chips[i];
          final active = _selectedArticleCategory == value;
          return Padding(
            padding: EdgeInsets.only(right: i < chips.length - 1 ? 8 : 0),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedArticleCategory = value;
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
                  label,
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
      // 窄螢幕（精簡模式字級放大後）標題與排序放不下一行時，排序換到下一行。
      // 外層 Column 是 start 對齊、給的是鬆寬度，Wrap 會縮成內容寬，
      // spaceBetween 就推不到右邊，所以要撐滿整行。
      child: SizedBox(
        width: double.infinity,
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.end,
          alignment: WrapAlignment.spaceBetween,
          runSpacing: 8,
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
                  'patas kari',
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
            CultureSortLabels(
              options: [
                for (final opt in _articleSortOptions) (opt.$1, opt.$3),
              ],
              selected: _articleSort,
              seniorMode: seniorMode,
              onChanged: (value) {
                setState(() {
                  _articleSort = value;
                  _articlesFuture = _fetchArticles();
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Article List ──────────────────────────────────────────────────────────

  Widget _buildArticleList(List<ArticleSummary> articles, bool seniorMode) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Column(
        children: articles
            .map(
              (a) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
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
