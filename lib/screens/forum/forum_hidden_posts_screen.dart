// 已隱藏的貼文。重複使用 ForumBoardView：分頁、空狀態、錯誤重試都現成，
// 每張卡片另加「取消隱藏」。隱藏只影響自己的動態，取消後貼文回到廣場。

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/network/api_client.dart';
import '../../models/forum_models.dart';
import '../../services/forum_service.dart';
import '../../services/senior_mode_controller.dart';
import '../../shared/widgets/app_back_button.dart';
import '../../shared/widgets/app_toast.dart';
import 'forum_board_view.dart';
import 'forum_detail_screen.dart';
import 'forum_theme.dart';

class ForumHiddenPostsScreen extends StatefulWidget {
  const ForumHiddenPostsScreen({super.key});

  @override
  State<ForumHiddenPostsScreen> createState() => _ForumHiddenPostsScreenState();
}

class _ForumHiddenPostsScreenState extends State<ForumHiddenPostsScreen> {
  final _viewKey = GlobalKey<ForumBoardViewState>();

  /// 取消隱藏請求還在路上的貼文，按鈕先停用，避免連點送出多次。
  final Set<int> _unhiding = {};

  @override
  Widget build(BuildContext context) =>
      Theme(data: forumTheme(context), child: _buildScaffold(context));

  Widget _buildScaffold(BuildContext context) => Scaffold(
    backgroundColor: AppColors.creamLight,
    appBar: AppBar(
      leading: const AppBackButton(),
      backgroundColor: AppColors.creamLight,
      elevation: 0,
      foregroundColor: AppColors.ink,
      title: Text(
        '已隱藏的貼文',
        style: AppTypography.titleStyle(color: AppColors.ink),
      ),
    ),
    body: ForumBoardView(
      key: _viewKey,
      emptyMessage: '沒有隱藏的貼文',
      emptySubtitle: '在貼文的選單按「隱藏這篇貼文」，就會列在這裡。',
      // 隱藏清單依隱藏時間排序，沒有「比某貼文 id 新」的語意，下拉刷新一律整份重載。
      prependOnRefresh: false,
      loadPage: ({cursor, after}) => ForumService.hiddenPosts(cursor: cursor),
      toggleLike: ForumService.likePost,
      toggleBookmark: ForumService.bookmarkPost,
      cardAction: _unhideButton,
      onOpenPost: _openPost,
    ),
  );

  Widget _unhideButton(ForumPost post) => TextButton(
    key: const ValueKey('forum-post-unhide'),
    onPressed: _unhiding.contains(post.id) ? null : () => _unhide(post),
    child: Text(
      '取消隱藏',
      style: AppTypography.captionStyle(
        seniorMode: seniorModeController.enabled,
        color: AppColors.primary,
      ),
    ),
  );

  Future<void> _unhide(ForumPost post) async {
    setState(() => _unhiding.add(post.id));
    try {
      final hidden = await ForumService.setHidden(post.id, hidden: false);
      if (!mounted || hidden) return;
      _viewKey.currentState?.removePost(post.id);
      showAppToast(context, '已取消隱藏');
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, e.message);
    } finally {
      if (mounted) setState(() => _unhiding.remove(post.id));
    }
  }

  /// 詳情頁裡可能取消隱藏後又重新隱藏，所以不在 onPostChanged 當下移除，
  /// 返回時才依最後狀態決定這筆的去留。
  Future<void> _openPost(ForumPost post, {int? imageIndex}) async {
    ForumPost? latest;
    final result = await Navigator.push<ForumDetailResult>(
      context,
      ForumDetailScreen.route(
        postId: post.id,
        initialImageIndex: imageIndex,
        onPostChanged: (p) => latest = p,
      ),
    );
    if (!mounted) return;
    _settleAfterDetail(post.id, result, latest);
  }

  void _settleAfterDetail(
    int postId,
    ForumDetailResult? result,
    ForumPost? latest,
  ) {
    final view = _viewKey.currentState;
    if (view == null) return;
    if (result?.deleted == true) return view.removePost(postId);
    // 重新隱藏或檢舉：這篇仍在隱藏清單（檢舉不會解除隱藏），保留並帶回最新計數。
    if (result?.removedFromFeed == true) {
      if (latest != null) view.replacePost(latest.copyWith(isHidden: true));
      return;
    }
    if (latest == null) return;
    if (!latest.isHidden) return view.removePost(postId);
    view.replacePost(latest);
  }
}
