// 「我按讚過的留言」清單。留言沒有獨立頁面，每筆多帶所屬貼文標題，
// 點擊直接前往原貼文。獨立實作（游標同 posts/likes 是 liked_at 時間戳字串）。

import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../models/forum_models.dart';
import '../../services/forum_service.dart';
import '../../services/senior_mode_controller.dart';
import '../../shared/utils/cursor_pager.dart';
import '../../shared/widgets/load_more_retry.dart';
import '../../shared/widgets/async_state_view.dart';
import '../../shared/widgets/truku_empty_state.dart';
import 'forum_detail_screen.dart';

class ForumLikedCommentsList extends StatefulWidget {
  const ForumLikedCommentsList({super.key});

  @override
  State<ForumLikedCommentsList> createState() => _ForumLikedCommentsListState();
}

class _ForumLikedCommentsListState extends State<ForumLikedCommentsList> {
  final _scrollController = ScrollController();
  final _pager = CursorPager<ForumLikedComment>(
    fetch: (cursor) async {
      final page = await ForumService.likedComments(cursor: cursor);
      return (page.comments, page.pageInfo);
    },
    idOf: (item) => item.comment.id,
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
    final comments = _pager.items;
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
    if (comments.isEmpty) {
      return _buildEmpty(seniorMode);
    }
    return RefreshIndicator(
      onRefresh: _pager.refresh,
      color: AppColors.primary,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: comments.length + (_pager.hasMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index >= comments.length) {
            if (_pager.loadMoreFailed) {
              return LoadMoreRetry(
                onRetry: _pager.retryLoadMore,
                color: AppColors.primary,
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
                    color: AppColors.primary,
                  ),
                ),
              ),
            );
          }
          return _CommentListItem(
            item: comments[index],
            seniorMode: seniorMode,
            // 在詳情頁取消按讚後返回，清單要重新整理，否則仍看得到已取消的留言。
            onReturn: _pager.refresh,
          );
        },
      ),
    );
  }

  Widget _buildEmpty(bool seniorMode) {
    return TrukuRefreshableEmpty(
      onRefresh: _pager.refresh,
      color: AppColors.primary,
      emptyState: TrukuEmptyState(
        icon: Icons.favorite_border,
        message: '還沒有按讚過任何留言',
        subtitle: '下拉重新整理，看看有沒有新留言。',
        seniorMode: seniorMode,
        scrollable: false,
      ),
    );
  }
}

class _CommentListItem extends StatelessWidget {
  final ForumLikedComment item;
  final bool seniorMode;

  /// 從詳情頁返回時呼叫，讓清單重新整理。
  final VoidCallback onReturn;

  const _CommentListItem({
    required this.item,
    required this.seniorMode,
    required this.onReturn,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        await Navigator.push(
          context,
          ForumDetailScreen.route(postId: item.postId),
        );
        onReturn();
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.creamDeep),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.postTitle != null)
              Text(
                item.postTitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: AppTypography.size(
                    AppTypography.caption,
                    seniorMode: seniorMode,
                  ),
                  letterSpacing: 0.5,
                ),
              ),
            const SizedBox(height: 4),
            Text(
              item.comment.body,
              maxLines: seniorMode ? 2 : 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.ink,
                fontSize: AppTypography.size(
                  AppTypography.body,
                  seniorMode: seniorMode,
                ),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.favorite,
                  size: seniorMode ? 22 : 14,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  '${item.comment.likeCount}',
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
    );
  }
}
