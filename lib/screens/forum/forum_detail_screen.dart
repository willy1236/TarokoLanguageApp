// 貼文詳情 + 兩層留言。
//
// 回覆的層級規則：對第二層回覆按「回覆」時，parent 仍指向它所屬的第一層留言。
// 後端會擋第三層，前端不送出必然失敗的請求。

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../models/forum_models.dart';
import '../../services/forum_service.dart';
import '../../services/user_service.dart';
import 'forum_compose_screen.dart';
import 'widgets/forum_comment_tile.dart';
import 'widgets/forum_image_grid.dart';
import 'widgets/forum_post_card.dart' show forumRelativeTime;
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

  const ForumDetailScreen({super.key, required this.postId, this.onPostChanged});

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

  /// 正在回覆的第一層留言；null 代表回覆貼文本身。
  ForumComment? _replyTarget;

  bool get _isMine => _post?.author.uid == UserService.currentUid;

  @override
  void initState() {
    super.initState();
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

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
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
        setState(() => _post = current.copyWith(isBookmarked: post.isBookmarked));
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

  Future<void> _deleteComment(ForumComment comment) async {
    final confirmed = await _confirm('刪除這則留言？');
    if (confirmed != true) return;
    try {
      await ForumService.deleteComment(comment.id);
      if (!mounted) return;
      setState(() {
        _comments.removeWhere((c) => c.id == comment.id);
        _replies.removeWhere((c) => c.id == comment.id);
        // 第一層被刪時，掛在它底下的回覆也失去容身之處。
        _replies.removeWhere((c) => c.parentCommentId == comment.id);
        final post = _post;
        if (post != null) {
          _post = post.copyWith(
            commentCount: (post.commentCount - 1).clamp(0, 1 << 31),
          );
        }
      });
      final updated = _post;
      if (updated != null) widget.onPostChanged?.call(updated);
    } on ApiException catch (e) {
      if (e.code == 'COMMENT_NOT_FOUND') {
        if (!mounted) return;
        setState(() {
          _comments.removeWhere((c) => c.id == comment.id);
          _replies.removeWhere((c) => c.id == comment.id);
          // 第一層被刪時，掛在它底下的回覆也失去容身之處（與成功路徑一致）。
          _replies.removeWhere((c) => c.parentCommentId == comment.id);
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
    if (updated == true && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final post = _post;
    return Scaffold(
      backgroundColor: AppColors.creamLight,
      appBar: AppBar(
        backgroundColor: AppColors.creamLight,
        elevation: 0,
        foregroundColor: AppColors.ink,
        title: Text(
          '貼文',
          style: GoogleFonts.notoSerifTc(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
        actions: [
          if (post != null)
            PopupMenuButton<String>(
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
      body: _buildBody(post),
    );
  }

  Widget _buildBody(ForumPost? post) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    final error = _error;
    if (error != null || post == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              error ?? '載入失敗',
              style: const TextStyle(color: AppColors.inkSoft),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('重試')),
          ],
        ),
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
                _postBody(post),
                const Divider(color: AppColors.creamDeep, height: 28),
                Text(
                  '留言 ${post.commentCount}',
                  style: GoogleFonts.notoSerifTc(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                if (threads.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      '還沒有人留言，來說第一句吧。',
                      style: TextStyle(color: AppColors.fog),
                    ),
                  ),
                for (final thread in threads) ...[
                  ForumCommentTile(
                    comment: thread.root,
                    isReply: false,
                    isMine: thread.root.author.uid == UserService.currentUid,
                    onLike: () => _likeComment(thread.root),
                    onReply: () => setState(() => _replyTarget = thread.root),
                    onDelete: () => _deleteComment(thread.root),
                    onReport: () => showForumReportSheet(
                      context,
                      targetType: 'comment',
                      targetId: thread.root.id,
                    ),
                  ),
                  for (final reply in thread.replies)
                    ForumCommentTile(
                      comment: reply,
                      isReply: true,
                      isMine: reply.author.uid == UserService.currentUid,
                      onLike: () => _likeComment(reply),
                      // 論壇只有兩層：回覆「回覆」時，parent 仍是第一層那則。
                      onReply: () => setState(() => _replyTarget = thread.root),
                      onDelete: () => _deleteComment(reply),
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
        _inputBar(),
      ],
    );
  }

  Widget _postBody(ForumPost post) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        post.title,
        style: GoogleFonts.notoSerifTc(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
          height: 1.4,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        '${post.author.displayName} · ${post.board.name} · '
        '${forumRelativeTime(post.createdAt)}',
        style: const TextStyle(fontSize: 12, color: AppColors.fog),
      ),
      const SizedBox(height: 14),
      Text(
        post.body,
        style: const TextStyle(
          fontSize: 15,
          color: AppColors.inkSoft,
          height: 1.7,
        ),
      ),
      if (post.images.isNotEmpty) ...[
        const SizedBox(height: 14),
        ForumImageGrid(urls: post.images),
      ],
      if (post.tags.isNotEmpty) ...[
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          children: [
            for (final tag in post.tags)
              Text(
                '#${tag.name}',
                style: GoogleFonts.crimsonPro(
                  fontStyle: FontStyle.italic,
                  fontSize: 12,
                  color: AppColors.primary,
                ),
              ),
          ],
        ),
      ],
      const SizedBox(height: 12),
      Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _likePost,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  post.isLiked ? Icons.favorite : Icons.favorite_border,
                  size: 18,
                  color: post.isLiked ? AppColors.primary : AppColors.fog,
                ),
                const SizedBox(width: 6),
                Text(
                  '${post.likeCount}',
                  style: const TextStyle(fontSize: 13, color: AppColors.fog),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _bookmarkPost,
            child: Icon(
              post.isBookmarked ? Icons.bookmark : Icons.bookmark_border,
              size: 18,
              color: post.isBookmarked ? AppColors.primary : AppColors.fog,
            ),
          ),
        ],
      ),
    ],
  );

  Widget _inputBar() {
    final target = _replyTarget;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cream,
        border: Border(top: BorderSide(color: AppColors.creamDeep)),
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        8 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (target != null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    '回覆 @${target.author.displayName}',
                    style: const TextStyle(fontSize: 12, color: AppColors.fog),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _replyTarget = null),
                  child: const Icon(
                    Icons.close,
                    size: 16,
                    color: AppColors.fog,
                  ),
                ),
              ],
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inputController,
                  maxLength: ForumService.commentMax,
                  minLines: 1,
                  maxLines: 4,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: '說點什麼…',
                    counterText: '',
                    border: InputBorder.none,
                  ),
                ),
              ),
              IconButton(
                onPressed: _sending || _inputController.text.trim().isEmpty
                    ? null
                    : _send,
                icon: const Icon(
                  Icons.send,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
