// 看板貼文列表。下拉刷新、觸底分頁、按讚與收藏的樂觀更新都在這裡。
//
// 資料來源以 callback 注入而不是直接呼叫 ForumService：測試才能在沒有網路的
// 情況下驅動分頁與回滾，同一個元件也能被「我的收藏」與搜尋結果重複使用。

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../models/forum_models.dart';
import '../../shared/widgets/truku_widgets.dart';
import 'widgets/forum_post_card.dart';

typedef ForumPageLoader =
    Future<ForumPostPage> Function({int? cursor, int? after});
typedef ForumLikeToggler =
    Future<({bool liked, int likeCount})> Function(
      int postId, {
      required bool like,
    });
typedef ForumBookmarkToggler =
    Future<bool> Function(int postId, {required bool add});

class ForumBoardView extends StatefulWidget {
  final ForumPageLoader loadPage;
  final ForumLikeToggler toggleLike;
  final ForumBookmarkToggler toggleBookmark;
  final void Function(ForumPost post) onOpenPost;
  final String emptyMessage;
  final bool prependOnRefresh;

  /// 資料來源的身分識別。closure 之間永遠不會相等（即使程式碼相同），
  /// 所以是否要整份重載改用這個值比對，而不是比較 loadPage 本身。
  /// null 代表這個畫面不需要身分驅動的重載（例如收藏頁）。
  final String? reloadKey;

  const ForumBoardView({
    super.key,
    required this.loadPage,
    required this.toggleLike,
    required this.toggleBookmark,
    required this.onOpenPost,
    this.emptyMessage = '這個看板還沒有貼文',
    this.prependOnRefresh = true,
    this.reloadKey,
  });

  @override
  State<ForumBoardView> createState() => ForumBoardViewState();
}

class ForumBoardViewState extends State<ForumBoardView> {
  final _scrollController = ScrollController();
  final List<ForumPost> _pinned = [];
  final List<ForumPost> _posts = [];

  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int? _nextCursor;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void didUpdateWidget(covariant ForumBoardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // reloadKey 代表資料來源的身分；closure 本身即使程式碼相同也永遠不相等，
    // 比較它會在無關的 setState（例如父層更新未讀數）時誤觸發整份重載。
    if (oldWidget.reloadKey != widget.reloadKey) _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 300) _loadMore();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.loadPage();
      if (!mounted) return;
      setState(() {
        _pinned
          ..clear()
          ..addAll(page.pinned);
        _posts
          ..clear()
          ..addAll(page.posts);
        _nextCursor = page.nextCursor;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _nextCursor == null) return;
    setState(() => _loadingMore = true);
    try {
      final page = await widget.loadPage(cursor: _nextCursor);
      if (!mounted) return;
      setState(() {
        _posts.addAll(page.posts);
        _nextCursor = page.nextCursor;
        _loadingMore = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      _toast(e.message);
    }
  }

  /// 下拉刷新用 after 只取斷層後的新貼文，接在最前面。
  /// 列表為空、或呼叫端表示沒有「比某 id 新」語意（如收藏頁）時，退回整份重載。
  Future<void> refresh() async {
    if (_posts.isEmpty || !widget.prependOnRefresh) return _load();
    try {
      final page = await widget.loadPage(after: _posts.first.id);
      if (!mounted) return;
      setState(() {
        _pinned
          ..clear()
          ..addAll(page.pinned);
        _posts.insertAll(0, page.posts);
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      _toast(e.message);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// 就地替換一筆貼文（置頂區與一般區都找）。
  void _replace(ForumPost post) {
    final pinnedIndex = _pinned.indexWhere((p) => p.id == post.id);
    if (pinnedIndex >= 0) _pinned[pinnedIndex] = post;
    final index = _posts.indexWhere((p) => p.id == post.id);
    if (index >= 0) _posts[index] = post;
  }

  Future<void> _like(ForumPost post) async {
    final original = post;
    setState(() => _replace(post.toggledLike()));
    try {
      final result = await widget.toggleLike(post.id, like: !post.isLiked);
      if (!mounted) return;
      // 以後端算出的真實計數校正，不沿用樂觀值。
      setState(
        () => _replace(
          original.copyWith(isLiked: result.liked, likeCount: result.likeCount),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _replace(original));
      _toast(e.message);
    }
  }

  Future<void> _bookmark(ForumPost post) async {
    final original = post;
    setState(() => _replace(post.toggledBookmark()));
    try {
      final added = await widget.toggleBookmark(
        post.id,
        add: !post.isBookmarked,
      );
      if (!mounted) return;
      setState(() => _replace(original.copyWith(isBookmarked: added)));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _replace(original));
      _toast(e.message);
    }
  }

  /// 貼文被刪除（詳情頁回報 404 或作者本人刪除）時從列表移除。
  void removePost(int postId) {
    setState(() {
      _pinned.removeWhere((p) => p.id == postId);
      _posts.removeWhere((p) => p.id == postId);
    });
  }

  /// 詳情頁把更新後的貼文（讚數、留言數、收藏狀態…）帶回來時，就地替換這一筆。
  void replacePost(ForumPost post) {
    setState(() => _replace(post));
  }

  /// 別的畫面（收藏頁、搜尋頁）改了收藏狀態時同步這一筆。
  /// 只有收藏欄位會變，其餘沿用本地既有的值——那些畫面沒有更新的計數可帶回來。
  void setBookmarked(int postId, bool bookmarked) {
    ForumPost? found;
    final pinnedIndex = _pinned.indexWhere((p) => p.id == postId);
    if (pinnedIndex >= 0) found = _pinned[pinnedIndex];
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index >= 0) found = _posts[index];
    if (found == null) return;
    final updated = found.copyWith(isBookmarked: bookmarked);
    setState(() => _replace(updated));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }
    if (_error != null) {
      return _ForumErrorState(message: _error!, onRetry: _load);
    }

    final all = [..._pinned, ..._posts];
    if (all.isEmpty) {
      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [_ForumEmptyState(message: widget.emptyMessage)],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: refresh,
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
        itemCount: all.length + (_loadingMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          if (i >= all.length) {
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
          final post = all[i];
          return ForumPostCard(
            post: post,
            onTap: () => widget.onOpenPost(post),
            onLike: () => _like(post),
            onBookmark: () => _bookmark(post),
          );
        },
      ),
    );
  }
}

class _ForumEmptyState extends StatelessWidget {
  final String message;

  const _ForumEmptyState({required this.message});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
    child: Column(
      children: [
        SizedBox(
          width: 76,
          height: 76,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.creamDeep,
                  shape: BoxShape.circle,
                ),
                child: SizedBox.expand(),
              ),
              Positioned(
                right: -6,
                top: -6,
                child: Opacity(
                  opacity: 0.13,
                  child: TrukuDiamond(size: 40, color: AppColors.primary),
                ),
              ),
              const Icon(
                Icons.forum_outlined,
                color: AppColors.primary,
                size: 34,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          message,
          style: GoogleFonts.notoSerifTc(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          '下拉重新整理，或成為第一位分享的人。',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.fog),
        ),
      ],
    ),
  );
}

class _ForumErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ForumErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
    child: Column(
      children: [
        const Icon(Icons.cloud_off_outlined, size: 40, color: AppColors.fog),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.inkSoft),
        ),
        const SizedBox(height: 14),
        OutlinedButton(
          onPressed: onRetry,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
          ),
          child: const Text('重試'),
        ),
      ],
    ),
  );
}
