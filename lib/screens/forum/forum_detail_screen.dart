// 貼文詳情 + 兩層留言。
//
// 回覆的層級規則：對第二層回覆按「回覆」時，parent 仍指向它所屬的第一層留言。
// 後端會擋第三層，前端不送出必然失敗的請求。

import 'package:flutter/material.dart';
import '../../shared/widgets/async_state_view.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../models/shop_item.dart';
import '../../services/shop_service.dart';
import 'forum_theme.dart';
import '../../core/network/api_client.dart';
import '../../models/forum_models.dart';
import '../../services/forum_service.dart';
import '../../services/senior_mode_controller.dart';
import '../../services/user_service.dart';
import 'forum_compose_screen.dart';
import 'widgets/forum_comment_input_bar.dart';
import 'widgets/forum_comment_tile.dart';
import 'widgets/forum_post_body.dart';
import 'widgets/forum_toast.dart';
import 'widgets/forum_report_sheet.dart';

/// 詳情頁關閉時回報的結果：貼文是否被刪除。
class ForumDetailResult {
  final bool deleted;

  const ForumDetailResult({this.deleted = false});
}

class ForumDetailScreen extends StatefulWidget {
  final int postId;

  /// 貼文有異動（讚、收藏、留言數）時即時回報，讓列表頁不必等關閉才更新。
  final ValueChanged<ForumPost>? onPostChanged;

  const ForumDetailScreen({
    super.key,
    required this.postId,
    this.onPostChanged,
  });

  @override
  State<ForumDetailScreen> createState() => _ForumDetailScreenState();
}

class _ForumDetailScreenState extends State<ForumDetailScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  ForumPost? _post;
  final List<ForumComment> _comments = [];
  final List<ForumComment> _replies = [];
  int? _nextCursor;
  bool _loading = true;
  bool _loadingMore = false;
  bool _sending = false;
  String? _error;

  /// 圖片過期自動重整每次載入只做一次，避免多張圖同時過期時連環重打 API。
  bool _imageAutoRefreshed = false;

  /// 正在回覆的第一層留言；null 代表回覆貼文本身。
  ForumComment? _replyTarget;

  Map<String, ShopItem> _itemCatalogById = const {};

  bool get _isMine => _post?.author.uid == UserService.currentUid;

  Future<void> _loadItemCatalog() async {
    try {
      final catalog = await ShopService.fetchItemCatalogCached();
      if (!mounted) return;
      setState(() => _itemCatalogById = catalog);
    } catch (e) {
      debugPrint('Failed to fetch item catalog: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _loadItemCatalog();
    _load();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _imageAutoRefreshed = false;
    });
    try {
      final post = await ForumService.post(widget.postId);
      final page = await ForumService.comments(widget.postId);
      if (!mounted) return;
      setState(() {
        _post = post;
        _comments
          ..clear()
          ..addAll(page.comments);
        _replies
          ..clear()
          ..addAll(page.replies);
        _nextCursor = page.nextCursor;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'POST_NOT_FOUND') {
        _popDeleted('這篇貼文已被刪除');
        return;
      }
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _loadMoreComments() async {
    if (_loadingMore) return;
    final cursor = _nextCursor;
    if (cursor == null) return;
    setState(() => _loadingMore = true);
    try {
      final page = await ForumService.comments(widget.postId, cursor: cursor);
      if (!mounted) return;
      setState(() {
        _comments.addAll(page.comments);
        _replies.addAll(page.replies);
        _nextCursor = page.nextCursor;
        _loadingMore = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      _toast(e.message);
    }
  }

  /// 圖片簽章網址過期時自動重打貼文 API 拿新網址；用旗標保證每次進頁最多
  /// 自動重試一次，避免多張圖同時過期或重整後仍失敗時無限連環重打。
  void _onImageExpired() {
    if (_imageAutoRefreshed || _loading) return;
    _imageAutoRefreshed = true;
    _load();
  }

  void _toast(String message) {
    if (!mounted) return;
    showForumToast(context, message);
  }

  /// 貼文已不存在：回到列表並回報已刪除，讓呼叫端把它移除。
  void _popDeleted(String message) {
    if (!mounted) return;
    Navigator.pop(context, const ForumDetailResult(deleted: true));
    _toast(message);
  }

  Future<void> _likePost() async {
    final post = _post;
    if (post == null) return;
    setState(() => _post = post.toggledLike());
    try {
      final result = await ForumService.likePost(post.id, like: !post.isLiked);
      if (!mounted) return;
      final current = _post;
      if (current == null) return;
      setState(
        () => _post = current.copyWith(
          isLiked: result.liked,
          likeCount: result.likeCount,
        ),
      );
      widget.onPostChanged?.call(_post!);
    } on ApiException catch (e) {
      if (!mounted) return;
      final current = _post;
      if (current != null) {
        setState(
          () => _post = current.copyWith(
            isLiked: post.isLiked,
            likeCount: post.likeCount,
          ),
        );
      }
      _toast(e.message);
    }
  }

  Future<void> _bookmarkPost() async {
    final post = _post;
    if (post == null) return;
    setState(() => _post = post.toggledBookmark());
    try {
      final added = await ForumService.bookmarkPost(
        post.id,
        add: !post.isBookmarked,
      );
      if (!mounted) return;
      final current = _post;
      if (current == null) return;
      setState(() => _post = current.copyWith(isBookmarked: added));
      widget.onPostChanged?.call(_post!);
    } on ApiException catch (e) {
      if (!mounted) return;
      final current = _post;
      if (current != null) {
        setState(
          () => _post = current.copyWith(isBookmarked: post.isBookmarked),
        );
      }
      _toast(e.message);
    }
  }

  Future<void> _likeComment(ForumComment comment) async {
    void replace(ForumComment next) {
      final i = _comments.indexWhere((c) => c.id == next.id);
      if (i >= 0) _comments[i] = next;
      final j = _replies.indexWhere((c) => c.id == next.id);
      if (j >= 0) _replies[j] = next;
    }

    setState(() => replace(comment.toggledLike()));
    try {
      final result = await ForumService.likeComment(
        comment.id,
        like: !comment.isLiked,
      );
      if (!mounted) return;
      setState(
        () => replace(
          comment.copyWith(isLiked: result.liked, likeCount: result.likeCount),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => replace(comment));
      _toast(e.message);
    }
  }

  Future<void> _send() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || text.length > ForumService.commentMax) return;
    setState(() => _sending = true);
    try {
      final created = await ForumService.createComment(
        widget.postId,
        text,
        parentCommentId: _replyTarget?.id,
      );
      if (!mounted) return;
      setState(() {
        if (created.parentCommentId == null) {
          _comments.add(created);
        } else {
          _replies.add(created);
        }
        final post = _post;
        if (post != null) {
          _post = post.copyWith(commentCount: post.commentCount + 1);
        }
        _inputController.clear();
        _replyTarget = null;
        _sending = false;
      });
      final updated = _post;
      if (updated != null) widget.onPostChanged?.call(updated);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      if (e.code == 'POST_NOT_FOUND') {
        _popDeleted('這篇貼文已被刪除');
        return;
      }
      _toast(e.message);
    }
  }

  /// 本地反映後端的刪除語意（後端 API 文件 §4.3 / §4.4）：
  /// 第一層留言底下若還有存活回覆，後端會把它保留成佔位讓回覆有東西可掛，
  /// 只有沒有回覆時才整則消失。回覆本身一律直接消失。
  void _applyCommentDeleted(ForumComment comment) {
    if (comment.parentCommentId != null) {
      _replies.removeWhere((c) => c.id == comment.id);
      return;
    }
    final hasLiveReplies = _replies.any((c) => c.parentCommentId == comment.id);
    final index = _comments.indexWhere((c) => c.id == comment.id);
    if (index < 0) return;
    if (hasLiveReplies) {
      _comments[index] = comment.asDeletedPlaceholder();
    } else {
      _comments.removeAt(index);
    }
  }

  Future<void> _deleteComment(ForumComment comment) async {
    final confirmed = await _confirm('刪除這則留言？');
    if (confirmed != true) return;
    try {
      await ForumService.deleteComment(comment.id);
      if (!mounted) return;
      setState(() {
        _applyCommentDeleted(comment);
        // 佔位不計入 comment_count，後端也是這樣算的。
        final post = _post;
        if (post != null) {
          _post = post.copyWith(
            commentCount: (post.commentCount - 1).clamp(0, 1 << 31),
          );
        }
        // 正在回覆的就是被刪的那則時，取消回覆對象。
        if (_replyTarget?.id == comment.id) _replyTarget = null;
      });
      final updated = _post;
      if (updated != null) widget.onPostChanged?.call(updated);
    } on ApiException catch (e) {
      if (e.code == 'COMMENT_NOT_FOUND') {
        if (!mounted) return;
        setState(() {
          _applyCommentDeleted(comment);
          if (_replyTarget?.id == comment.id) _replyTarget = null;
        });
        return;
      }
      _toast(e.message);
    }
  }

  Future<void> _deletePost() async {
    final confirmed = await _confirm('刪除這篇貼文？');
    if (confirmed != true) return;
    try {
      await ForumService.deletePost(widget.postId);
      if (!mounted) return;
      Navigator.pop(context, const ForumDetailResult(deleted: true));
    } on ApiException catch (e) {
      _toast(e.message);
    }
  }

  Future<bool?> _confirm(String message) => showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(c, true),
          child: const Text('刪除'),
        ),
      ],
    ),
  );

  Future<void> _edit() async {
    final post = _post;
    if (post == null) return;
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ForumComposeScreen(boards: [post.board], editing: post),
      ),
    );
    if (updated != true || !mounted) return;
    await _load();
    // 按讚/收藏/留言都會回報父層，唯獨編輯漏做，導致返回列表仍是舊標題內文。
    final refreshed = _post;
    if (refreshed != null) widget.onPostChanged?.call(refreshed);
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: forumTheme(context),
    child: ListenableBuilder(
      listenable: seniorModeController,
      builder: (context, _) =>
          _buildScaffold(context, seniorModeController.enabled),
    ),
  );

  Widget _buildScaffold(BuildContext context, bool seniorMode) {
    final post = _post;
    return Scaffold(
      backgroundColor: AppColors.creamLight,
      appBar: AppBar(
        backgroundColor: AppColors.creamLight,
        elevation: 0,
        foregroundColor: AppColors.ink,
        title: Text(
          '貼文',
          style: AppTypography.titleStyle(seniorMode: seniorMode, color: AppColors.ink),
        ),
        actions: [
          if (post != null)
            PopupMenuButton<String>(
              iconSize: seniorMode ? 30 : 24,
              onSelected: (value) {
                if (value == 'edit') _edit();
                if (value == 'delete') _deletePost();
                if (value == 'report') {
                  showForumReportSheet(
                    context,
                    targetType: 'post',
                    targetId: post.id,
                  );
                }
              },
              itemBuilder: (_) => _isMine
                  ? const [
                      PopupMenuItem(value: 'edit', child: Text('編輯')),
                      PopupMenuItem(value: 'delete', child: Text('刪除')),
                    ]
                  : const [PopupMenuItem(value: 'report', child: Text('檢舉'))],
            ),
        ],
      ),
      body: _buildBody(post, seniorMode),
    );
  }

  Widget _buildBody(ForumPost? post, bool seniorMode) {
    if (_loading) {
      return const TrukuLoadingView();
    }
    final error = _error;
    if (error != null || post == null) {
      return TrukuErrorView(
        message: error ?? '載入失敗',
        onRetry: _load,
        seniorMode: seniorMode,
      );
    }

    final threads = groupComments(_comments, _replies);
    return Column(
      children: [
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.metrics.pixels >= n.metrics.maxScrollExtent - 200) {
                _loadMoreComments();
              }
              return false;
            },
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              children: [
                ForumPostBody(
                  post: post,
                  seniorMode: seniorMode,
                  onImageExpired: _onImageExpired,
                  onLike: _likePost,
                  onBookmark: _bookmarkPost,
                ),
                const Divider(color: AppColors.creamDeep, height: 28),
                Text(
                  '留言 ${post.commentCount}',
                  style: AppTypography.serif(
                    fontSize: AppTypography.size(AppTypography.body, seniorMode: seniorMode),
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                if (threads.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      '還沒有人留言，來說第一句吧。',
                      style: TextStyle(
                        color: AppColors.fog,
                        fontSize: seniorMode ? AppTypography.bodyLarge + AppTypography.seniorStep : null,
                      ),
                    ),
                  ),
                for (final thread in threads) ...[
                  ForumCommentTile(
                    comment: thread.root,
                    isReply: false,
                    isMine: thread.root.author?.uid == UserService.currentUid,
                    onLike: () => _likeComment(thread.root),
                    onReply: () => setState(() => _replyTarget = thread.root),
                    onDelete: () => _deleteComment(thread.root),
                    onReport: () => showForumReportSheet(
                      context,
                      targetType: 'comment',
                      targetId: thread.root.id,
                    ),
                    itemCatalogById: _itemCatalogById,
                  ),
                  for (final reply in thread.replies)
                    ForumCommentTile(
                      comment: reply,
                      isReply: true,
                      isMine: reply.author?.uid == UserService.currentUid,
                      onLike: () => _likeComment(reply),
                      // 論壇只有兩層：回覆「回覆」時，parent 仍是第一層那則。
                      onReply: () => setState(() => _replyTarget = thread.root),
                      onDelete: () => _deleteComment(reply),
                      itemCatalogById: _itemCatalogById,
                      onReport: () => showForumReportSheet(
                        context,
                        targetType: 'comment',
                        targetId: reply.id,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
        ForumCommentInputBar(
          controller: _inputController,
          replyTarget: _replyTarget,
          sending: _sending,
          seniorMode: seniorMode,
          onSend: _send,
          onCancelReply: () => setState(() => _replyTarget = null),
        ),
      ],
    );
  }
}
