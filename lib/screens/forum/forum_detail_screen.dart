// 貼文詳情 + 兩層留言。
//
// 回覆的層級規則：對第二層回覆按「回覆」時，parent 仍指向它所屬的第一層留言。
// 後端會擋第三層，前端不送出必然失敗的請求。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import '../../shared/widgets/async_state_view.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../models/shop_item.dart';
import '../../services/account_lock_controller.dart';
import '../../services/block_refresh_notifier.dart';
import '../../services/shop_service.dart';
import 'forum_theme.dart';
import '../../core/network/api_client.dart';
import '../../models/forum_models.dart';
import '../../models/page_info.dart';
import '../../services/forum_service.dart';
import '../../services/admin_service.dart';
import '../../services/senior_mode_controller.dart';
import '../../services/user_service.dart';
import '../admin/admin_error.dart';
import '../admin/widgets/admin_reason_dialog.dart';
import 'forum_compose_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'widgets/forum_comment_input_bar.dart';
import 'widgets/forum_image_grid.dart' show ForumImageViewer;
import 'widgets/forum_comment_tile.dart';
import 'widgets/forum_new_reply_chip.dart';
import 'widgets/forum_post_body.dart';
import '../../shared/widgets/app_toast.dart';
import 'widgets/forum_report_sheet.dart';
import '../../shared/utils/utf16_length_limit.dart';
import '../../shared/widgets/app_back_button.dart';
import '../../shared/widgets/confirm_dialog.dart';

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

  /// 不為 null 代表是從「有人回覆你」的通知進來的：載入後捲到這則留言。
  /// 留言不在已載入的範圍就往後多載幾頁找，找不到（已刪除等）就停在頂端。
  final int? focusCommentId;

  const ForumDetailScreen({
    super.key,
    required this.postId,
    this.onPostChanged,
    this.initialImageIndex,
    this.focusCommentId,
  });

  /// route 名稱：讓通知導頁判斷最上層是不是這篇貼文。
  static String routeNameFor(int postId) => 'forum/detail/$postId';

  /// 所有呼叫端都走這個工廠，settings.name 才會一致。
  static Route<ForumDetailResult> route({
    required int postId,
    ValueChanged<ForumPost>? onPostChanged,
    int? initialImageIndex,
    int? focusCommentId,
  }) => MaterialPageRoute<ForumDetailResult>(
    settings: RouteSettings(name: routeNameFor(postId)),
    builder: (_) => ForumDetailScreen(
      postId: postId,
      onPostChanged: onPostChanged,
      initialImageIndex: initialImageIndex,
      focusCommentId: focusCommentId,
    ),
  );

  /// 開著的詳情頁，以所在的 route 為 key：同一篇貼文開了兩份時各自登記，
  /// 關掉上層那份不影響下層。
  static final Map<Route<dynamic>, _ForumDetailScreenState> _live = {};

  /// 點回覆通知時人已在 [route] 這份詳情頁：就地重載。帶 [focusCommentId] 時
  /// 重載後改捲到那則留言（規則同 [ForumDetailScreen.focusCommentId]）。
  static void refreshRoute(Route<dynamic> route, {int? focusCommentId}) =>
      _live[route]?._refreshFromPush(focusCommentId);

  /// 人正停在 [route] 這份詳情頁時有人回覆了貼文或其中的留言（前景推播）：
  /// 在頁內浮出提示並回傳 true；[route] 已不是開著的詳情頁則回傳 false，由呼叫端
  /// 照常通知。[type] 是推播的 'reply_post' 或 'reply_comment'。
  static bool notifyNewReply(Route<dynamic> route, String type) {
    final state = _live[route];
    if (state == null) return false;
    state._onNewReply(type);
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
  String? _nextCursor;

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

  /// 累積的推播裡有「回覆留言」。回覆掛在各自的留言串下，不一定排在最後。
  bool _pendingIncludesCommentReply = false;

  /// 每收到一則頁內回覆推播加一。「載入更多」發出後才又收到推播時，那一頁
  /// 可能不含新回覆，不能據此清掉提示。
  int _replySignal = 0;

  /// 正在回覆的第一層留言；null 代表回覆貼文本身。
  ForumComment? _replyTarget;

  /// 要捲去的留言：一開始是 [ForumDetailScreen.focusCommentId]，頁面開著時點了
  /// 別則回覆的通知就換成那一則。
  late int? _focusCommentId = widget.focusCommentId;

  /// 還沒捲到的 [_focusCommentId]；捲到或確定找不到後清成 null。
  late int? _pendingFocusId = _focusCommentId;

  /// 掛在要捲去的那則留言上。
  final _focusKey = GlobalKey();

  /// 捲到後短暫加底色標示那則留言；時間到就淡出。
  bool _focusHighlighted = false;
  Timer? _focusHighlightTimer;
  static const _focusHighlightHold = Duration(milliseconds: 1600);
  static const _focusHighlightFade = Duration(milliseconds: 600);

  /// 為了找那則留言已經往後多載了幾頁。
  int _focusPagesLoaded = 0;
  static const _focusMaxPages = 5;

  Map<String, ShopItem> _itemCatalogById = const {};

  bool get _isMine => UserService.isMe(_post?.author.friendCode);

  /// 管理員：選單多出「管理員下架」「置頂」。
  bool get _isAdmin => UserService.cachedUser?.isAdmin ?? false;

  Future<void> _loadItemCatalog() async {
    try {
      final catalog = await ShopService.fetchItemCatalogCached();
      if (!mounted) return;
      setState(() => _itemCatalogById = catalog);
    } catch (e) {
      debugPrint('Failed to fetch item catalog: $e');
    }
  }

  /// 這份詳情頁所在的 route，通知重載與頁內提示的登記 key。
  Route<dynamic>? _route;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null && _route == null) {
      _route = route;
      ForumDetailScreen._live[route] = this;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadItemCatalog();
    _load();
    BlockRefreshNotifier.revision.addListener(_load);
  }

  @override
  void dispose() {
    final route = _route;
    if (route != null) ForumDetailScreen._live.remove(route);
    _focusHighlightTimer?.cancel();
    BlockRefreshNotifier.revision.removeListener(_load);
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
      _clearPendingReplies();
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
        _nextCursor = page.pageInfo.nextCursor;
        _loading = false;
      });
      _maybeOpenInitialImage();
      _seekFocusComment();
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

  /// 點回覆通知時人已在本頁：有指定留言就改捲到那一則，再整頁重載。
  void _refreshFromPush(int? focusCommentId) {
    // 沒指定留言時也要清掉上一則，重載後才不會把標示掛回舊留言。
    _focusCommentId = focusCommentId;
    _pendingFocusId = focusCommentId;
    _focusPagesLoaded = 0;
    _focusHighlightTimer?.cancel();
    _focusHighlighted = false;
    _load();
  }

  void _onNewReply(String type) {
    if (!mounted) return;
    setState(() {
      _pendingReplyCount++;
      _replySignal++;
      if (type != 'reply_post') _pendingIncludesCommentReply = true;
    });
  }

  void _clearPendingReplies() {
    _pendingReplyCount = 0;
    _pendingIncludesCommentReply = false;
  }

  /// 還有較舊的留言沒載完：新的第一層留言排在最後，要往下載入才看得到。
  bool get _newRepliesBelowUnloaded =>
      !_pendingIncludesCommentReply && _nextCursor != null;

  /// 點「有新回覆」提示。新回覆都是第一層留言、且還有舊留言沒載完時，新回覆
  /// 排在最後：捲到底並載入下一頁，已載入的留言與捲動位置都保留，提示等全部
  /// 載完（新回覆出現）才消失。其餘情況整頁重載：游標是後端給的不透明字串，
  /// 前端不能自己組出「某則之後」的游標，只能從第一頁重新載入。
  ///
  /// 已知限制：「載入更多」在路上時收到第一層回覆推播，若那一頁已是最後一頁，
  /// 提示不會自動清掉（那一頁不一定含新回覆，見 [_replySignal]）；之後已沒有
  /// 下一頁，點提示會退回整頁重載。不另外自動補抓。
  Future<void> _showNewReplies() async {
    if (_newRepliesBelowUnloaded) {
      if (_scrollController.hasClients) {
        unawaited(
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          ),
        );
      }
      unawaited(_loadMoreComments());
      return;
    }
    await _load();
    // 留言數跟著重載變了，回報父層，返回列表時卡片才不會停在舊的留言數。
    final refreshed = _post;
    if (mounted && refreshed != null) widget.onPostChanged?.call(refreshed);
  }

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
    final replySignal = _replySignal;
    setState(() => _loadingMore = true);
    try {
      final page = await ForumService.comments(widget.postId, cursor: cursor);
      if (!mounted || generation != _generation) return;
      setState(() {
        _mergeComments(page, advanceCursor: true);
        _loadingMore = false;
      });
      // 等待期間又收到推播就不清提示；最後一頁時會留到點提示整頁重載（已知限制，
      // 見 _showNewReplies）。
      if (replySignal == _replySignal) _settleNewRepliesBelow(generation);
      _seekFocusComment();
    } on ApiException catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loadingMore = false;
        _pendingFocusId = null;
      });
      _toast(e.message);
    }
  }

  /// 新的第一層回覆排在最後，載完最後一頁就都看得到了：清掉提示，並重抓貼文
  /// 讓留言數跟上、回報父層（返回列表時卡片才不會停在舊的留言數）。
  void _settleNewRepliesBelow(int generation) {
    if (_pendingReplyCount == 0 ||
        _pendingIncludesCommentReply ||
        _nextCursor != null) {
      return;
    }
    setState(_clearPendingReplies);
    unawaited(_refreshPostOnly(generation));
  }

  Future<void> _refreshPostOnly(int generation) async {
    try {
      final post = await ForumService.post(widget.postId);
      if (!mounted || generation != _generation) return;
      setState(() => _post = post);
      widget.onPostChanged?.call(post);
    } on ApiException catch (e) {
      debugPrint('ForumDetailScreen: 重抓貼文留言數失敗：$e');
    }
  }

  /// 捲到通知指的那則留言。還沒載到就往後載下一頁（載完會再回到這裡）。
  void _seekFocusComment() {
    final id = _pendingFocusId;
    if (id == null) return;
    final loaded =
        _comments.any((c) => c.id == id) || _replies.any((c) => c.id == id);
    if (!loaded) {
      if (_nextCursor != null && _focusPagesLoaded < _focusMaxPages) {
        _focusPagesLoaded++;
        _loadMoreComments();
      } else {
        setState(() => _pendingFocusId = null);
      }
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 捲動途中點了另一則回覆的通知（refreshRoute 換了 focus）：這一輪作廢，
      // 不能清掉新的 pending，也不能把標示亮在還沒捲到的新留言上。
      if (!mounted || _pendingFocusId != id) return;
      final target = _focusKey.currentContext;
      if (target != null) {
        await Scrollable.ensureVisible(
          target,
          alignment: 0.2,
          duration: const Duration(milliseconds: 300),
        );
      }
      if (!mounted || _pendingFocusId != id) return;
      setState(() {
        _pendingFocusId = null;
        _focusHighlighted = target != null;
      });
      _focusHighlightTimer?.cancel();
      if (target != null) {
        _focusHighlightTimer = Timer(_focusHighlightHold, () {
          if (mounted) setState(() => _focusHighlighted = false);
        });
      }
    });
  }

  /// 要捲去的那則留言掛上 [_focusKey]，捲到後短暫加底色標示；其他留言原樣回傳。
  Widget _focusable(ForumComment comment, Widget tile) =>
      comment.id == _focusCommentId
      ? KeyedSubtree(
          key: _focusKey,
          child: AnimatedContainer(
            key: const ValueKey('forum_focus_highlight'),
            duration: _focusHighlightFade,
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(
                alpha: _focusHighlighted ? 0.28 : 0,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: tile,
          ),
        )
      : tile;

  /// 把一批留言併進列表：按 id 去重、按 id 排序（id 越大越新）。
  /// 本地先插入的留言之後可能又從伺服器分頁回來，只靠 append 會重複且亂序。
  /// [advanceCursor] 只給伺服器分頁結果用，會推進 [_nextCursor]。
  void _mergeComments(ForumCommentPage page, {bool advanceCursor = false}) {
    _mergeById(_comments, page.comments);
    _mergeById(_replies, page.replies);
    if (advanceCursor) _nextCursor = page.pageInfo.nextCursor;
  }

  static void _mergeById(List<ForumComment> into, List<ForumComment> incoming) {
    if (incoming.isEmpty) return;
    final byId = {for (final c in into) c.id: c};
    for (final c in incoming) {
      byId[c.id] = c;
    }
    into
      ..clear()
      ..addAll(byId.values.toList()..sort((a, b) => a.id.compareTo(b.id)));
  }

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
    showAppToast(context, message);
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
      if (e.isBlocked) return _handleBlocked();
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
      if (e.isBlocked) return _handleBlocked();
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
      if (e.isBlocked) return _handleBlocked();
      _toast(e.message);
    }
  }

  Future<void> _send() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    if (!withinUtf16Limit(
      context,
      text,
      ForumService.commentMax,
      label: '留言',
    )) {
      return;
    }
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
            pageInfo: PageInfo.end,
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
      // 回覆的對象已被刪除（變成佔位）：重載讓畫面換成佔位，輸入內容保留。
      if (e.code == 'COMMENT_NOT_FOUND' && _replyTarget != null) {
        setState(() => _replyTarget = null);
        _toast('這則留言已被刪除，無法回覆');
        _load();
        return;
      }
      if (e.isBlocked) return _handleBlocked();
      _toast(e.message);
    }
  }

  /// 本地反映後端的刪除語意（後端 API 文件 §4.4，2026-09-26 起）：
  /// 被刪的留言（第一層或回覆）一律保留成佔位，底下的回覆照常掛著。
  void _applyCommentDeleted(ForumComment comment) {
    final list = comment.parentCommentId == null ? _comments : _replies;
    final index = list.indexWhere((c) => c.id == comment.id);
    if (index >= 0) list[index] = comment.asDeletedPlaceholder();
  }

  /// 403 BLOCKED：與對方有封鎖關係（畫面還沒重新整理時會發生），提示後重載本頁。
  void _handleBlocked() {
    _toast('無法與此使用者互動');
    _load();
  }

  Future<void> _deleteComment(ForumComment comment) async {
    final confirmed = await _confirm('刪除這則留言？');
    if (confirmed != true) return;
    try {
      await ForumService.deleteComment(comment.id);
      if (!mounted) return;
      _onCommentRemoved(comment);
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

  /// 留言已被刪除（自刪或管理員下架）：換成佔位、扣留言數、通知父層。
  void _onCommentRemoved(ForumComment comment) {
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
  }

  Future<void> _adminRemovePost() async {
    final post = _post;
    if (post == null) return;
    final input = await promptAdminReason(
      context,
      title: '管理員下架貼文',
      description: '貼文會立刻隱藏，並送進違規區等另一位管理員二審。',
      confirmMessage: '確定下架「${post.title}」？',
      confirmText: '下架',
    );
    if (input == null || !mounted) return;
    try {
      await AdminService.removePost(post.id, input.reason);
      showAdminMessage('已下架，等待其他管理員二審');
      if (mounted) {
        Navigator.pop(context, const ForumDetailResult(deleted: true));
      }
    } catch (e) {
      if (mounted) handleAdminError(context, e);
    }
  }

  Future<void> _adminRemoveComment(ForumComment comment) async {
    final input = await promptAdminReason(
      context,
      title: '管理員下架留言',
      description: '留言會顯示為「留言已被刪除」，並送進違規區等另一位管理員二審。',
      confirmMessage: '確定下架這則留言？',
      confirmText: '下架',
    );
    if (input == null || !mounted) return;
    try {
      await AdminService.removeComment(comment.id, input.reason);
      if (!mounted) return;
      _onCommentRemoved(comment);
      showAdminMessage('已下架，等待其他管理員二審');
    } catch (e) {
      if (mounted) handleAdminError(context, e);
    }
  }

  Future<void> _adminTogglePin() async {
    final post = _post;
    if (post == null) return;
    try {
      final pinned = await AdminService.pinPost(
        post.id,
        pinned: !post.isPinned,
      );
      if (!mounted) return;
      setState(() => _post = post.copyWith(isPinned: pinned));
      widget.onPostChanged?.call(_post!);
      showAdminMessage(pinned ? '已置頂' : '已取消置頂');
    } catch (e) {
      if (mounted) handleAdminError(context, e);
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

  Future<bool> _confirm(String message) =>
      showConfirmDialog(context, message: message, confirmText: '刪除');

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
        UserService.userNotifier,
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
          if (post != null && (_isMine || !locked || _isAdmin))
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
                if (value == 'admin_remove') _adminRemovePost();
                if (value == 'admin_pin') _adminTogglePin();
              },
              itemBuilder: (_) => [
                if (_isMine) ...[
                  if (!locked)
                    const PopupMenuItem(value: 'edit', child: Text('編輯')),
                  const PopupMenuItem(value: 'delete', child: Text('刪除')),
                ] else if (!locked)
                  const PopupMenuItem(value: 'report', child: Text('檢舉')),
                if (_isAdmin) ...[
                  PopupMenuItem(
                    value: 'admin_pin',
                    child: Text(post.isPinned ? '取消置頂' : '置頂'),
                  ),
                  if (!_isMine)
                    const PopupMenuItem(
                      value: 'admin_remove',
                      child: Text('管理員下架'),
                    ),
                ],
              ],
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
                    needsScrollToLoad: _newRepliesBelowUnloaded,
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
        // 還沒捲到指定留言前把整串留言都排版出來：捲動目標要先存在才量得到位置。
        scrollCacheExtent: _pendingFocusId == null
            ? null
            : const ScrollCacheExtent.pixels(100000),
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
            _focusable(
              thread.root,
              ForumCommentTile(
                comment: thread.root,
                isReply: false,
                isMine: UserService.isMe(thread.root.author?.friendCode),
                onLike: () => _likeComment(thread.root),
                onReply: locked
                    ? null
                    : () => setState(() => _replyTarget = thread.root),
                onDelete: () => _deleteComment(thread.root),
                onAdminRemove: _isAdmin
                    ? () => _adminRemoveComment(thread.root)
                    : null,
                onReport: locked
                    ? null
                    : () => showForumReportSheet(
                        context,
                        targetType: 'comment',
                        targetId: thread.root.id,
                      ),
                itemCatalogById: _itemCatalogById,
              ),
            ),
            for (final reply in thread.replies)
              _focusable(
                reply,
                ForumCommentTile(
                  comment: reply,
                  isReply: true,
                  isMine: UserService.isMe(reply.author?.friendCode),
                  onLike: () => _likeComment(reply),
                  // 論壇只有兩層：回覆「回覆」時，parent 仍是第一層那則。
                  onReply: locked
                      ? null
                      : () => setState(() => _replyTarget = thread.root),
                  onDelete: () => _deleteComment(reply),
                  onAdminRemove: _isAdmin
                      ? () => _adminRemoveComment(reply)
                      : null,
                  itemCatalogById: _itemCatalogById,
                  onReport: locked
                      ? null
                      : () => showForumReportSheet(
                          context,
                          targetType: 'comment',
                          targetId: reply.id,
                        ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
