// 貼文詳情 + 兩層留言。
//
// 回覆的層級規則：對第二層回覆按「回覆」時，parent 仍指向它所屬的第一層留言。
// 後端會擋第三層，前端不送出必然失敗的請求。

import 'package:flutter/material.dart';
import '../../shared/widgets/async_state_view.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../models/shop_item.dart';
import '../../services/account_lock_controller.dart';
import '../../services/shop_service.dart';
import 'forum_theme.dart';
import '../../core/network/api_client.dart';
import '../../models/forum_models.dart';
import '../../services/forum_service.dart';
import '../../services/senior_mode_controller.dart';
import '../../services/user_service.dart';
import 'forum_compose_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'widgets/forum_comment_input_bar.dart';
import 'widgets/forum_image_grid.dart' show ForumImageViewer;
import 'widgets/forum_comment_tile.dart';
import 'widgets/forum_new_reply_chip.dart';
import 'widgets/forum_post_body.dart';
import 'widgets/forum_toast.dart';
import 'widgets/forum_report_sheet.dart';
import '../../shared/widgets/app_back_button.dart';

/// 詳情頁關閉時回報的結果：貼文是否被刪除。
class ForumDetailResult {
  final bool deleted;

  const ForumDetailResult({this.deleted = false});
}

class ForumDetailScreen extends StatefulWidget {
  final int postId;

  /// 貼文有異動（讚、收藏、留言數）時即時回報，讓列表頁不必等關閉才更新。
  final ValueChanged<ForumPost>? onPostChanged;

  /// 不為 null 代表使用者是在列表上點附圖進來的：貼文載入完成後自動疊上
  /// 全螢幕圖片檢視，於是返回時會先停在內文頁，再返回才回列表。
  final int? initialImageIndex;

  const ForumDetailScreen({
    super.key,
    required this.postId,
    this.onPostChanged,
    this.initialImageIndex,
  });

  /// route 名稱：讓通知導頁能用 popUntil 找回已經開著的那一份。
  static String routeNameFor(int postId) => 'forum/detail/$postId';

  /// 所有呼叫端都走這個工廠，settings.name 才會一致。
  static Route<ForumDetailResult> route({
    required int postId,
    ValueChanged<ForumPost>? onPostChanged,
    int? initialImageIndex,
  }) => MaterialPageRoute<ForumDetailResult>(
    settings: RouteSettings(name: routeNameFor(postId)),
    builder: (_) => ForumDetailScreen(
      postId: postId,
      onPostChanged: onPostChanged,
      initialImageIndex: initialImageIndex,
    ),
  );

  /// 目前開著的詳情頁：key = postId。
  static final Map<int, _ForumDetailScreenState> _live = {};

  /// 該貼文的詳情頁是否已在畫面上。
  static bool isOpen(int postId) => _live.containsKey(postId);

  /// 開著才重載；沒開就什麼都不做。
  static void refreshIfOpen(int postId) => _live[postId]?._load();

  /// 有人回覆了這篇貼文或其中的留言（前景推播）。該篇開著時在頁內浮出提示並
  /// 回傳 true；沒開則回傳 false，由呼叫端照常通知。
  /// [type] 是推播的 'reply_post' 或 'reply_comment'。
  static bool notifyNewReply(int postId, String type, int? commentId) {
    final state = _live[postId];
    if (state == null) return false;
    state._onNewReply(type, commentId);
    return true;
  }

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

  /// 伺服器回過的第一層留言裡最大的 id。和 [_nextCursor] 不同：自己送出的
  /// 留言只在本地插入、沒經過伺服器分頁，所以不推進它。
  int? _serverCursor;

  /// 每次 [_load] 加一；非同步請求回來時對不上就代表列表已被整頁換掉，
  /// 結果直接丟掉，不能接到新列表上。
  int _generation = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _sending = false;
  String? _error;

  /// 圖片過期自動重整每次載入只做一次，避免多張圖同時過期時連環重打 API。
  bool _imageAutoRefreshed = false;

  /// [ForumDetailScreen.initialImageIndex] 帶進來的全螢幕檢視只自動開一次，
  /// 圖片過期重載或使用者關掉檢視後都不該再彈出來。
  bool _autoViewerShown = false;

  /// 停在本頁時收到、還沒載入的回覆推播數，大於 0 就浮出提示。
  /// 不自動重載：會閃載入畫面並丟掉已載入的留言，交給使用者點提示決定。
  int _pendingReplyCount = 0;

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
    ForumDetailScreen._live[widget.postId] = this;
    _loadItemCatalog();
    _load();
  }

  @override
  void dispose() {
    // 同一 postId 若已被新實例接手，不要把它的登記清掉。
    if (ForumDetailScreen._live[widget.postId] == this) {
      ForumDetailScreen._live.remove(widget.postId);
    }
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// [resetImageRetry] 為 false 時保留 [_imageAutoRefreshed]。圖片過期觸發的
  /// 重載必須這樣呼叫——否則它會把擋住自己的旗標清掉，變成無限重打。
  Future<void> _load({bool resetImageRetry = true}) async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _loadingMore = false;
      _pendingReplyCount = 0;
      _error = null;
      if (resetImageRetry) _imageAutoRefreshed = false;
    });
    try {
      final post = await ForumService.post(widget.postId);
      final page = await ForumService.comments(widget.postId);
      if (!mounted || generation != _generation) return;
      setState(() {
        _post = post;
        _comments
          ..clear()
          ..addAll(page.comments);
        _replies
          ..clear()
          ..addAll(page.replies);
        _nextCursor = page.nextCursor;
        _serverCursor = _maxId(page.comments);
        _loading = false;
      });
      _maybeOpenInitialImage();
    } on ApiException catch (e) {
      if (!mounted || generation != _generation) return;
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

  void _onNewReply(String type, int? commentId) {
    if (!mounted) return;
    setState(() => _pendingReplyCount++);
  }

  /// 點「有新回覆」提示：整頁重載，新留言就在裡面。
  void _showNewReplies() => _load();

  /// 從列表點附圖進來時，等貼文（含圖片網址）到手後才疊上全螢幕檢視。
  void _maybeOpenInitialImage() {
    final index = widget.initialImageIndex;
    if (index == null || _autoViewerShown) return;
    final images = _post?.images ?? const <String>[];
    if (index < 0 || index >= images.length) return;
    _autoViewerShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ForumImageViewer(
            images: [for (final url in images) CachedNetworkImageProvider(url)],
            initialIndex: index,
          ),
        ),
      );
    });
  }

  Future<void> _loadMoreComments() async {
    if (_loadingMore) return;
    final cursor = _nextCursor;
    if (cursor == null) return;
    final generation = _generation;
    setState(() => _loadingMore = true);
    try {
      final page = await ForumService.comments(widget.postId, cursor: cursor);
      if (!mounted || generation != _generation) return;
      setState(() {
        _mergeComments(page, advanceCursors: true);
        _loadingMore = false;
      });
    } on ApiException catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() => _loadingMore = false);
      _toast(e.message);
    }
  }

  /// 把一批留言併進列表：按 id 去重、按 id 排序（id 越大越新）。
  /// 本地先插入的留言之後可能又從伺服器分頁回來，只靠 append 會重複且亂序。
  /// [advanceCursors] 只給伺服器分頁結果用，會推進 [_nextCursor] 與 [_serverCursor]。
  /// 回傳真正新加入的筆數。
  int _mergeComments(ForumCommentPage page, {bool advanceCursors = false}) {
    final added =
        _mergeById(_comments, page.comments) +
        _mergeById(_replies, page.replies);
    if (advanceCursors) {
      _nextCursor = page.nextCursor;
      final maxId = _maxId(page.comments);
      final current = _serverCursor;
      if (maxId != null && (current == null || maxId > current)) {
        _serverCursor = maxId;
      }
    }
    return added;
  }

  static int _mergeById(List<ForumComment> into, List<ForumComment> incoming) {
    if (incoming.isEmpty) return 0;
    final byId = {for (final c in into) c.id: c};
    final before = byId.length;
    for (final c in incoming) {
      byId[c.id] = c;
    }
    into
      ..clear()
      ..addAll(byId.values.toList()..sort((a, b) => a.id.compareTo(b.id)));
    return byId.length - before;
  }

  static int? _maxId(List<ForumComment> comments) => comments.isEmpty
      ? null
      : comments.map((c) => c.id).reduce((a, b) => a > b ? a : b);

  /// 圖片簽章網址過期時自動重打貼文 API 拿新網址；用旗標保證每次進頁最多
  /// 自動重試一次，避免多張圖同時過期或重整後仍失敗時無限連環重打。
  void _onImageExpired() {
    if (_imageAutoRefreshed || _loading) return;
    _imageAutoRefreshed = true;
    _load(resetImageRetry: false);
  }

  /// 使用者手動點破圖重試：明確的使用者意圖，重新開放一次自動重試額度。
  void _onImageRetryTap() {
    if (_loading) return;
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
    // 唯讀帳號只擋「按讚」，取消讚後端放行。
    if (!post.isLiked && blockIfReadOnly()) return;
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
    if (!comment.isLiked && blockIfReadOnly()) return;
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
        final isRoot = created.parentCommentId == null;
        _mergeComments(
          ForumCommentPage(
            comments: isRoot ? [created] : const [],
            replies: isRoot ? const [] : [created],
            nextCursor: null,
          ),
        );
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
      listenable: Listenable.merge([
        seniorModeController,
        accountLockController,
      ]),
      builder: (context, _) =>
          _buildScaffold(context, seniorModeController.enabled),
    ),
  );

  Widget _buildScaffold(BuildContext context, bool seniorMode) {
    final post = _post;
    // 唯讀帳號：編輯（PATCH）與檢舉會被後端擋，選單直接不給；刪除仍保留。
    final locked = accountLockController.locked;
    return Scaffold(
      backgroundColor: AppColors.creamLight,
      appBar: AppBar(
        leading: const AppBackButton(),
        backgroundColor: AppColors.creamLight,
        elevation: 0,
        foregroundColor: AppColors.ink,
        title: Text(
          '貼文',
          style: AppTypography.titleStyle(
            seniorMode: seniorMode,
            color: AppColors.ink,
          ),
        ),
        actions: [
          if (post != null && (_isMine || !locked))
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
                  ? [
                      if (!locked)
                        const PopupMenuItem(value: 'edit', child: Text('編輯')),
                      const PopupMenuItem(value: 'delete', child: Text('刪除')),
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
    final locked = accountLockController.locked;
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              _buildCommentList(post, threads, locked, seniorMode),
              // 浮在列表頂端、不跟著捲動：捲到很下面或正在輸入時都看得到，
              // 也不會蓋住底下的輸入列。
              Positioned(
                top: 12,
                left: 0,
                right: 0,
                child: Center(
                  child: ForumNewReplyChip(
                    count: _pendingReplyCount,
                    seniorMode: seniorMode,
                    onTap: _showNewReplies,
                  ),
                ),
              ),
            ],
          ),
        ),
        ForumCommentInputBar(
          controller: _inputController,
          replyTarget: _replyTarget,
          sending: _sending,
          readOnly: locked,
          seniorMode: seniorMode,
          onSend: _send,
          onCancelReply: () => setState(() => _replyTarget = null),
        ),
      ],
    );
  }

  Widget _buildCommentList(
    ForumPost post,
    List<ForumCommentThread> threads,
    bool locked,
    bool seniorMode,
  ) {
    return NotificationListener<ScrollNotification>(
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
            onImageRetryTap: _onImageRetryTap,
            onLike: _likePost,
            onBookmark: _bookmarkPost,
          ),
          const Divider(color: AppColors.creamDeep, height: 28),
          Text(
            '留言 ${post.commentCount}',
            style: AppTypography.serif(
              fontSize: AppTypography.size(
                AppTypography.body,
                seniorMode: seniorMode,
              ),
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
                  fontSize: seniorMode
                      ? AppTypography.bodyLarge + AppTypography.seniorStep
                      : null,
                ),
              ),
            ),
          for (final thread in threads) ...[
            ForumCommentTile(
              comment: thread.root,
              isReply: false,
              isMine: thread.root.author?.uid == UserService.currentUid,
              onLike: () => _likeComment(thread.root),
              onReply: locked
                  ? null
                  : () => setState(() => _replyTarget = thread.root),
              onDelete: () => _deleteComment(thread.root),
              onReport: locked
                  ? null
                  : () => showForumReportSheet(
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
                onReply: locked
                    ? null
                    : () => setState(() => _replyTarget = thread.root),
                onDelete: () => _deleteComment(reply),
                itemCatalogById: _itemCatalogById,
                onReport: locked
                    ? null
                    : () => showForumReportSheet(
                        context,
                        targetType: 'comment',
                        targetId: reply.id,
                      ),
              ),
          ],
        ],
      ),
    );
  }
}
