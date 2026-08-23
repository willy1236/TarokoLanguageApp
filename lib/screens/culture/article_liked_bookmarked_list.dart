// 「我按讚的文章」／「我收藏的文章」清單內容。不含 Scaffold/AppBar，
// 供獨立畫面或 TabBarView 嵌入使用。page/page_size 分頁（非 forum 的 cursor 分頁）。

import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../models/article_models.dart';
import '../../services/article_service.dart';
import 'article_detail_screen.dart';

enum ArticleListMode { liked, bookmarked }

class ArticleLikedBookmarkedList extends StatefulWidget {
  final ArticleListMode mode;
  const ArticleLikedBookmarkedList({super.key, required this.mode});

  @override
  State<ArticleLikedBookmarkedList> createState() =>
      _ArticleLikedBookmarkedListState();
}

class _ArticleLikedBookmarkedListState
    extends State<ArticleLikedBookmarkedList> {
  static const _pageSize = 20;

  final _articles = <ArticleSummary>[];
  final _scrollController = ScrollController();
  int _page = 1;
  int _total = 0;
  bool _loading = true;
  bool _loadingMore = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_loadingMore || _articles.length >= _total) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  Future<ArticleListResponse> _fetch(int page) {
    return widget.mode == ArticleListMode.liked
        ? ArticleService.fetchLikedArticles(page: page, pageSize: _pageSize)
        : ArticleService.fetchArticleBookmarks(page: page, pageSize: _pageSize);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _fetch(1);
      if (!mounted) return;
      setState(() {
        _articles
          ..clear()
          ..addAll(res.articles);
        _page = 1;
        _total = res.total;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    try {
      final res = await _fetch(_page + 1);
      if (!mounted) return;
      setState(() {
        _articles.addAll(res.articles);
        _page += 1;
        _total = res.total;
      });
    } catch (_) {
      // 翻頁失敗保持原清單，使用者可再滑動觸發重試。
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.gold),
      );
    }
    if (_error != null) {
      return _buildError(_error);
    }
    if (_articles.isEmpty) {
      return _buildEmpty();
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.gold,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _articles.length + (_articles.length < _total ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index >= _articles.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.gold,
                  ),
                ),
              ),
            );
          }
          return _ArticleListItem(article: _articles[index]);
        },
      ),
    );
  }

  Widget _buildEmpty() {
    final message = widget.mode == ArticleListMode.liked
        ? '還沒有按讚任何文章'
        : '還沒有收藏任何文章';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.article_outlined, color: AppColors.fog, size: 40),
            const SizedBox(height: 12),
            Text(message, style: TextStyle(color: AppColors.fog, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildError(Object? error) {
    final message = error is ApiException ? error.message : '發生錯誤，請稍後再試';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: AppColors.fog, size: 40),
            const SizedBox(height: 12),
            Text(message, style: TextStyle(color: AppColors.cream, fontSize: 14)),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: _load, child: const Text('重試')),
          ],
        ),
      ),
    );
  }
}

class _ArticleListItem extends StatelessWidget {
  final ArticleSummary article;
  const _ArticleListItem({required this.article});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
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
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 72,
                height: 60,
                child: article.coverImageUrl != null
                    ? Image.network(
                        article.coverImageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          color: AppColors.midnight,
                          child: const Icon(
                            Icons.article_outlined,
                            color: AppColors.fog,
                          ),
                        ),
                      )
                    : Container(
                        color: AppColors.midnight,
                        child: const Icon(
                          Icons.article_outlined,
                          color: AppColors.fog,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.creamLight,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        article.isLiked
                            ? Icons.favorite
                            : Icons.favorite_border,
                        size: 14,
                        color: article.isLiked
                            ? AppColors.gold
                            : AppColors.fog,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${article.likeCount}',
                        style: TextStyle(color: AppColors.fog, fontSize: 12),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.visibility, size: 14, color: AppColors.fog),
                      const SizedBox(width: 4),
                      Text(
                        '${article.viewCount}',
                        style: TextStyle(color: AppColors.fog, fontSize: 12),
                      ),
                    ],
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
