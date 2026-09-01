// 文章搜尋：關鍵字／時間區間／部落，三者皆選填、可任意組合。
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/network/api_client.dart';
import '../../models/article_models.dart';
import '../../models/tribe_model.dart';
import '../../services/article_service.dart';
import '../../services/senior_mode_controller.dart';
import '../../shared/widgets/module_search_bar.dart';
import 'article_detail_screen.dart';

class ArticleSearchScreen extends StatefulWidget {
  const ArticleSearchScreen({super.key});

  @override
  State<ArticleSearchScreen> createState() => _ArticleSearchScreenState();
}

class _ArticleSearchScreenState extends State<ArticleSearchScreen> {
  final _controller = TextEditingController();
  String? _q;
  String? _range;
  Tribe? _tribe;

  bool _loading = false;
  bool _loadingMore = false;
  String? _error;
  int _page = 1;
  int _total = 0;
  List<ArticleSummary> _articles = [];
  bool _searched = false;

  bool get _hasMore => _articles.length < _total;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      _q = _controller.text.trim();
      _searched = true;
      _loading = true;
      _error = null;
      _page = 1;
    });
    try {
      final res = await ArticleService.searchArticles(
        q: _q,
        range: _range,
        tribeId: _tribe?.id,
        page: 1,
      );
      if (!mounted) return;
      setState(() {
        _articles = res.articles;
        _total = res.total;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : '搜尋失敗，請稍後再試';
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final res = await ArticleService.searchArticles(
        q: _q,
        range: _range,
        tribeId: _tribe?.id,
        page: _page + 1,
      );
      if (!mounted) return;
      setState(() {
        _articles = [..._articles, ...res.articles];
        _page += 1;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _onTribeSelected(Tribe? tribe) {
    setState(() => _tribe = tribe);
    _search();
  }

  void _setRange(String? range) {
    setState(() => _range = range);
    _search();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: seniorModeController,
      builder: (context, _) => _buildScaffold(seniorModeController.enabled),
    );
  }

  Widget _buildScaffold(bool seniorMode) {
    return Scaffold(
      backgroundColor: AppColors.midnight,
      appBar: ModuleSearchAppBar(
        controller: _controller,
        hint: '搜尋文章',
        onSubmit: _search,
        palette: SearchBarPalette.dark,
        seniorMode: seniorMode,
        titleFontSize: AppTypography.title,
      ),
      body: Column(
        children: [
          ModuleSearchFilterRow(
            range: _range,
            onRangeSelected: _setRange,
            tribe: _tribe,
            onTribeSelected: _onTribeSelected,
            palette: SearchBarPalette.dark,
            seniorMode: seniorMode,
            chipFontSize: AppTypography.subtitle,
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                _error!,
                style: TextStyle(
                  color: AppColors.fog,
                  fontSize: seniorMode ? AppTypography.title : null,
                ),
              ),
            ),
          if (!_searched && _error == null)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Text(
                '輸入關鍵字或選擇篩選條件開始搜尋',
                style: GoogleFonts.notoSerifTc(
                  color: AppColors.fog,
                  fontSize: seniorMode ? AppTypography.title : null,
                ),
              ),
            ),
          if (_searched) Expanded(child: _resultList(seniorMode)),
        ],
      ),
    );
  }

  Widget _resultList(bool seniorMode) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.gold),
      );
    }
    if (_articles.isEmpty) {
      return Center(
        child: Text(
          '找不到符合的文章',
          style: TextStyle(
            color: AppColors.fog,
            fontSize: seniorMode ? AppTypography.title : null,
          ),
        ),
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.extentAfter < 200) _loadMore();
        return false;
      },
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _articles.length + (_hasMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          if (i >= _articles.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.gold),
              ),
            );
          }
          return _ArticleResultTile(
            article: _articles[i],
            seniorMode: seniorMode,
          );
        },
      ),
    );
  }
}

class _ArticleResultTile extends StatelessWidget {
  final ArticleSummary article;
  final bool seniorMode;
  const _ArticleResultTile({required this.article, required this.seniorMode});

  @override
  Widget build(BuildContext context) {
    final thumbSize = seniorMode ? 76.0 : 56.0;
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ArticleDetailScreen(articleId: article.id),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.midnightSoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cream.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            Container(
              width: thumbSize,
              height: thumbSize,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: const LinearGradient(
                  colors: [AppColors.moss, AppColors.mossDeep],
                ),
              ),
              child: article.coverImageUrl != null
                  ? Image.network(article.coverImageUrl!, fit: BoxFit.cover)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.title,
                    maxLines: seniorMode ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.notoSerifTc(
                      fontSize: seniorMode ? AppTypography.title : 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.creamLight,
                    ),
                  ),
                  const SizedBox(height: 3),
                  if (!seniorMode)
                    Text(
                      '${ArticleCategory.label(article.category)} · ${article.viewCount} 閱讀',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.fog,
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
}
