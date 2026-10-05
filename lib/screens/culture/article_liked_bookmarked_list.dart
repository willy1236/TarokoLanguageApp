// 「我按讚的文章」／「我收藏的文章」清單內容。不含 Scaffold/AppBar，
// 供獨立畫面或 TabBarView 嵌入使用。page/page_size 分頁（非 forum 的 cursor 分頁）。

import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../models/article_models.dart';
import '../../services/article_service.dart';
import '../../services/senior_mode_controller.dart';
import '../../shared/utils/cursor_pager.dart';
import '../../shared/widgets/load_more_retry.dart';
import '../../shared/widgets/article_cover_placeholder.dart';
import '../../shared/widgets/async_state_view.dart';
import '../../shared/widgets/truku_empty_state.dart';
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
  final _scrollController = ScrollController();
  late final _pager = CursorPager<ArticleSummary>(
    fetch: (cursor) async {
      final res = widget.mode == ArticleListMode.liked
          ? await ArticleService.fetchLikedArticles(cursor: cursor)
          : await ArticleService.fetchArticleBookmarks(cursor: cursor);
      return (res.articles, res.pageInfo);
    },
    idOf: (article) => article.id,
  );

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _pager.refresh();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _pager.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _pager.loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([seniorModeController, _pager]),
      builder: (context, _) => _buildBody(seniorModeController.enabled),
    );
  }

  Widget _buildBody(bool seniorMode) {
    final articles = _pager.items;
    if (_pager.loading) {
      return const TrukuLoadingView();
    }
    if (_pager.error != null) {
      return TrukuErrorView(
        error: _pager.error,
        onRetry: _pager.refresh,
        seniorMode: seniorMode,
      );
    }
    if (articles.isEmpty) {
      return _buildEmpty(seniorMode);
    }
    return RefreshIndicator(
      onRefresh: _pager.refresh,
      color: AppColors.gold,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: articles.length + (_pager.hasMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index >= articles.length) {
            if (_pager.loadMoreFailed) {
              return LoadMoreRetry(
                onRetry: _pager.retryLoadMore,
                color: AppColors.gold,
                seniorMode: seniorMode,
              );
            }
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
          return _ArticleListItem(
            article: articles[index],
            seniorMode: seniorMode,
            // 在詳情頁取消收藏/按讚後返回，清單要重新整理，否則仍看得到
            // 已經取消的項目。
            onReturn: _pager.refresh,
          );
        },
      ),
    );
  }

  Widget _buildEmpty(bool seniorMode) {
    final message = widget.mode == ArticleListMode.liked
        ? '還沒有按讚任何文章'
        : '還沒有收藏任何文章';
    return TrukuRefreshableEmpty(
      onRefresh: _pager.refresh,
      color: AppColors.gold,
      emptyState: TrukuEmptyState(
        icon: Icons.article_outlined,
        message: message,
        subtitle: '下拉重新整理，看看有沒有新文章。',
        seniorMode: seniorMode,
        scrollable: false,
      ),
    );
  }
}

class _ArticleListItem extends StatelessWidget {
  final ArticleSummary article;
  final bool seniorMode;

  /// 從詳情頁返回時呼叫，讓清單重新整理。
  final VoidCallback onReturn;
  const _ArticleListItem({
    required this.article,
    required this.seniorMode,
    required this.onReturn,
  });

  @override
  Widget build(BuildContext context) {
    final thumbWidth = seniorMode ? 96.0 : 72.0;
    final thumbHeight = seniorMode ? 80.0 : 60.0;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ArticleDetailScreen(articleId: article.id),
          ),
        );
        onReturn();
      },
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
                width: thumbWidth,
                height: thumbHeight,
                child: article.coverImageUrl != null
                    ? Image.network(
                        article.coverImageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            ArticleCoverPlaceholder(category: article.category),
                      )
                    : ArticleCoverPlaceholder(category: article.category),
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
                    style: TextStyle(
                      color: AppColors.creamLight,
                      fontSize: AppTypography.size(
                        AppTypography.body,
                        seniorMode: seniorMode,
                      ),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Icon(
                        article.isLiked
                            ? Icons.favorite
                            : Icons.favorite_border,
                        size: seniorMode ? 22 : 14,
                        color: article.isLiked ? AppColors.gold : AppColors.fog,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${article.likeCount}',
                        style: TextStyle(
                          color: AppColors.fog,
                          fontSize: AppTypography.size(
                            AppTypography.caption,
                            seniorMode: seniorMode,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.visibility,
                        size: seniorMode ? 22 : 14,
                        color: AppColors.fog,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${article.viewCount}',
                        style: TextStyle(
                          color: AppColors.fog,
                          fontSize: AppTypography.size(
                            AppTypography.caption,
                            seniorMode: seniorMode,
                          ),
                        ),
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
