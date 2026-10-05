// 「我按讚過的貼文」清單。獨立實作，不套用 ForumBoardView——
// ForumBoardView 的 loadPage cursor 綁死貼文 id 整數，而
// GET /forum/posts/likes 的游標是 liked_at 時間戳字串，兩者不相容。

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

class ForumLikedPostsList extends StatefulWidget {
  const ForumLikedPostsList({super.key});

  @override
  State<ForumLikedPostsList> createState() => _ForumLikedPostsListState();
}

class _ForumLikedPostsListState extends State<ForumLikedPostsList> {
  final _scrollController = ScrollController();
  final _pager = CursorPager<ForumPost>(
    fetch: (cursor) async {
      final page = await ForumService.likedPosts(cursor: cursor);
      return (page.posts, page.pageInfo);
    },
    idOf: (post) => post.id,
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
    final posts = _pager.items;
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
    if (posts.isEmpty) {
      return _buildEmpty(seniorMode);
    }
    return RefreshIndicator(
      onRefresh: _pager.refresh,
      color: AppColors.primary,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: posts.length + (_pager.hasMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index >= posts.length) {
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
          return _PostListItem(
            post: posts[index],
            seniorMode: seniorMode,
            // 在詳情頁取消按讚後返回，清單要重新整理，否則仍看得到已取消的貼文。
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
        message: '還沒有按讚過任何貼文',
        subtitle: '下拉重新整理，看看有沒有新貼文。',
        seniorMode: seniorMode,
        scrollable: false,
      ),
    );
  }
}

class _PostListItem extends StatelessWidget {
  final ForumPost post;
  final bool seniorMode;

  /// 從詳情頁返回時呼叫，讓清單重新整理。
  final VoidCallback onReturn;

  const _PostListItem({
    required this.post,
    required this.seniorMode,
    required this.onReturn,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        await Navigator.push(context, ForumDetailScreen.route(postId: post.id));
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
            Text(
              post.board.name,
              style: TextStyle(
                color: AppColors.primary,
                fontSize: AppTypography.size(
                  AppTypography.caption,
                  seniorMode: seniorMode,
                ),
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              post.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.ink,
                fontSize: AppTypography.size(
                  AppTypography.body,
                  seniorMode: seniorMode,
                ),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Icon(
                  post.isLiked ? Icons.favorite : Icons.favorite_border,
                  size: seniorMode ? 22 : 14,
                  color: post.isLiked ? AppColors.primary : AppColors.fog,
                ),
                const SizedBox(width: 4),
                Text(
                  '${post.likeCount}',
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
                  Icons.mode_comment_outlined,
                  size: seniorMode ? 22 : 14,
                  color: AppColors.fog,
                ),
                const SizedBox(width: 4),
                Text(
                  '${post.commentCount}',
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
