import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../models/event_model.dart';
import '../../models/forum_models.dart';
import '../../services/event_service.dart';
import '../../services/forum_service.dart';
import '../../shared/widgets/truku_widgets.dart';
import '../forum/forum_board_view.dart';
import '../forum/forum_bookmarks_screen.dart';
import '../forum/forum_compose_screen.dart';
import '../forum/forum_detail_screen.dart';
import '../forum/forum_notifications_screen.dart';
import '../forum/forum_search_screen.dart';
import '../forum/forum_theme.dart';
import '../events/event_detail_screen.dart';

class PlazaScreen extends StatefulWidget {
  const PlazaScreen({super.key});

  @override
  State<PlazaScreen> createState() => _PlazaScreenState();
}

class _PlazaScreenState extends State<PlazaScreen> {
  bool _eventsLoading = true;
  List<EventSummary> _events = [];

  List<ForumBoard> _boards = [];

  /// 目前選到的看板 slug；null 代表「全部」（跨看板），也是預設。
  String? _boardSlug;

  /// 「全部」沒有 slug，借一個不可能與看板 slug 相撞的字串當重載識別。
  static const _allBoardsKey = '__all__';

  bool _boardsLoading = true;
  int _unread = 0;
  final _boardViewKey = GlobalKey<ForumBoardViewState>();

  @override
  void initState() {
    super.initState();
    _loadEvents();
    _loadBoards();
    _loadUnread();
  }

  Future<void> _loadEvents() async {
    try {
      final events = await EventService.fetchEvents(scope: 'upcoming');
      if (!mounted) return;
      setState(() {
        _events = events;
        _eventsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _eventsLoading = false);
    }
  }

  Future<void> _loadBoards() async {
    try {
      final boards = await ForumService.boards();
      if (!mounted) return;
      setState(() {
        _boards = boards;
        // 預設停在「全部」，不自動選第一個看板。
        _boardsLoading = false;
      });
    } on ApiException {
      // 看板載不到不應該讓整頁失效，活動小卡仍要顯示。
      if (!mounted) return;
      setState(() => _boardsLoading = false);
    }
  }

  Future<void> _loadUnread() async {
    try {
      final page = await ForumService.notifications();
      if (!mounted) return;
      setState(() => _unread = page.unreadCount);
    } on ApiException {
      // 紅點拿不到就不顯示，不干擾主要內容。
    }
  }

  void _openEventDetail(EventSummary e) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EventDetailScreen(eventId: e.id)),
    ).then((_) {
      if (mounted) _loadEvents();
    });
  }

  /// 收藏頁或搜尋頁改了某篇的收藏狀態時，同步廣場列表上的書籤圖示，
  /// 否則返回後那一列仍會顯示成已收藏。
  void _syncBookmark(int postId, bool bookmarked) {
    _boardViewKey.currentState?.setBookmarked(postId, bookmarked);
  }

  Future<void> _openPost(ForumPost post) async {
    final result = await Navigator.push<ForumDetailResult>(
      context,
      MaterialPageRoute(
        builder: (_) => ForumDetailScreen(
          postId: post.id,
          onPostChanged: (p) => _boardViewKey.currentState?.replacePost(p),
        ),
      ),
    );
    if (result == null) return;
    if (result.deleted) {
      _boardViewKey.currentState?.removePost(post.id);
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: forumTheme(context),
    child: Scaffold(
      backgroundColor: AppColors.creamLight,
      // 順序沿用改版前：標題、近期活動橫向小卡、看板 tab，最後才是貼文列表。
      // 只有貼文列表捲動，上面三段固定。
      body: Column(
        children: [
          _buildHeader(context),
          if (!_eventsLoading && _events.isNotEmpty) _buildMiniEventCards(),
          _buildTabBar(),
          Expanded(child: _buildPostsSection()),
        ],
      ),
    ),
  );

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ALANG · 廣場',
                  style: GoogleFonts.crimsonPro(
                    fontStyle: FontStyle.italic,
                    fontSize: 12,
                    color: AppColors.fog,
                    letterSpacing: 3.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '族人在這裡',
                  style: GoogleFonts.notoSerifTc(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ForumSearchScreen(
                  boards: _boards,
                  onBookmarkChanged: _syncBookmark,
                ),
              ),
            ),
            icon: const Icon(Icons.search, color: AppColors.ink, size: 20),
          ),
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    ForumBookmarksScreen(onBookmarkChanged: _syncBookmark),
              ),
            ),
            icon: const Icon(
              Icons.bookmark_border,
              color: AppColors.ink,
              size: 20,
            ),
          ),
          IconButton(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ForumNotificationsScreen(),
                ),
              );
              if (mounted) _loadUnread();
            },
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(
                  Icons.notifications_none,
                  color: AppColors.ink,
                  size: 20,
                ),
                if (_unread > 0)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _boards.isEmpty
                ? null
                : () async {
                    final created = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ForumComposeScreen(boards: _boards),
                      ),
                    );
                    if (created == true) {
                      _boardViewKey.currentState?.refresh();
                    }
                  },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add, color: AppColors.creamLight, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    '發布',
                    style: GoogleFonts.notoSerifTc(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.creamLight,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() => Container(
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AppColors.creamDeep)),
    ),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // slug 為 null 代表「全部」，排在最前面且是預設。
          _BoardTab(
            label: '全部',
            selected: _boardSlug == null,
            onTap: () => setState(() => _boardSlug = null),
          ),
          for (final board in _boards)
            _BoardTab(
              label: board.name,
              selected: board.slug == _boardSlug,
              onTap: () => setState(() => _boardSlug = board.slug),
            ),
        ],
      ),
    ),
  );

  Widget _buildMiniEventCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Text(
            'SMRATUC · 近期活動',
            style: GoogleFonts.crimsonPro(
              fontStyle: FontStyle.italic,
              fontSize: 10,
              color: AppColors.fog,
              letterSpacing: 3.0,
            ),
          ),
        ),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            itemCount: _events.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, i) => _MiniEventCard(
              event: _events[i],
              onTap: () => _openEventDetail(_events[i]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPostsSection() {
    final slug = _boardSlug;
    if (_boardsLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }
    // slug 為 null 是「全部」，走跨看板端點；否則走該看板的貼文。
    final reloadKey = slug ?? _allBoardsKey;
    return KeyedSubtree(
      key: ValueKey(reloadKey),
      child: ForumBoardView(
        key: _boardViewKey,
        reloadKey: reloadKey,
        emptyMessage: slug == null ? '還沒有人發文' : '這個分類還沒有貼文',
        loadPage: ({cursor, after}) => slug == null
            ? ForumService.allPosts(cursor: cursor, after: after)
            : ForumService.posts(slug, cursor: cursor, after: after),
        toggleLike: ForumService.likePost,
        toggleBookmark: ForumService.bookmarkPost,
        onOpenPost: _openPost,
      ),
    );
  }
}

// ── 看板 Tab 元件 ──────────────────────────────────────────────

class _BoardTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _BoardTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.fog;
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(right: 22),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                label,
                style: GoogleFonts.notoSerifTc(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            if (selected)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(height: 2, color: AppColors.primary),
              ),
          ],
        ),
      ),
    );
  }
}

// ── 近期活動小卡 ─────────────────────────────────────────────

class _MiniEventCard extends StatelessWidget {
  final EventSummary event;
  final VoidCallback onTap;

  const _MiniEventCard({required this.event, required this.onTap});

  static const _months = [
    '1月',
    '2月',
    '3月',
    '4月',
    '5月',
    '6月',
    '7月',
    '8月',
    '9月',
    '10月',
    '11月',
    '12月',
  ];

  @override
  Widget build(BuildContext context) {
    final d = event.startsAt.toLocal();
    final month = _months[d.month - 1];
    final day = d.day.toString().padLeft(2, '0');
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -16,
              top: -16,
              child: Opacity(
                opacity: 0.13,
                child: TrukuDiamond(size: 80, color: AppColors.gold),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: event.isJoined
                            ? AppColors.primary
                            : AppColors.moss,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            month,
                            style: const TextStyle(
                              fontSize: 8,
                              color: AppColors.gold,
                              letterSpacing: 0.3,
                            ),
                          ),
                          Text(
                            day,
                            style: GoogleFonts.notoSerifTc(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.creamLight,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.notoSerifTc(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.creamLight,
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            event.location ?? '線上',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.creamLight.withValues(
                                alpha: 0.65,
                              ),
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '● ${event.participantCount} 人報名',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.gold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.5),
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        event.isJoined ? '已報名' : '我要參加',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.gold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
