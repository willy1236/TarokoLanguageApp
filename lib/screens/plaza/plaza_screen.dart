import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../models/event_model.dart';
import '../../models/forum_models.dart';
import '../../services/event_service.dart';
import '../../services/forum_service.dart';
import '../../services/senior_mode_controller.dart';
import '../forum/forum_board_view.dart';
import '../forum/forum_bookmarks_screen.dart';
import '../forum/forum_compose_screen.dart';
import '../forum/forum_detail_screen.dart';
import '../forum/forum_notifications_screen.dart';
import '../forum/forum_search_screen.dart';
import '../forum/forum_theme.dart';
import '../events/event_detail_screen.dart';
import '../../shared/widgets/module_header_actions.dart';
import 'widgets/plaza_cards.dart';

class PlazaScreen extends StatefulWidget {
  /// 由外層（合併分頁的膠囊切換）注入，顯示在標題與近期活動之間。
  final Widget? topToggle;

  const PlazaScreen({super.key, this.topToggle});

  @override
  State<PlazaScreen> createState() => _PlazaScreenState();
}

// MainContainer 用 IndexedStack，廣場的 State 建立一次就一直活著——切到別的
// 分頁再切回來不會重跑 initState。因此除了首次載入，另外掛兩個更新時機：
// 下拉刷新與 App 回到前景。沒有這兩個，剛建立的活動要等重開 App 才看得到。
class _PlazaScreenState extends State<PlazaScreen> with WidgetsBindingObserver {
  bool _eventsLoading = true;
  List<EventSummary> _events = [];
  String? _eventsError;

  List<ForumBoard> _boards = [];

  /// 目前選到的看板 slug；null 代表「全部」（跨看板），也是預設。
  String? _boardSlug;

  /// 「全部」沒有 slug，借一個不可能與看板 slug 相撞的字串當重載識別。
  static const _allBoardsKey = '__all__';

  bool _boardsLoading = true;

  /// 發文畫面開啟中：擋住連點疊出第二個 ForumComposeScreen。
  bool _composing = false;
  int _unread = 0;
  final _boardViewKey = GlobalKey<ForumBoardViewState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadEvents();
    _loadBoards();
    _loadUnread();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // 只重載頁首那兩塊。貼文列表不動，否則使用者切出去再回來會失去捲動位置。
    _loadEvents();
    _loadUnread();
  }

  /// 下拉刷新時與貼文一起更新的頁首內容。
  Future<void> _refreshHeader() async {
    await Future.wait([_loadEvents(), _loadUnread()]);
  }

  Future<void> _loadEvents() async {
    try {
      final events = await EventService.fetchEvents(scope: 'upcoming');
      if (!mounted) return;
      setState(() {
        _events = events;
        _eventsError = null;
        _eventsLoading = false;
      });
    } on ApiException catch (e) {
      debugPrint('[PlazaScreen] _loadEvents ApiException: ${e.message}');
      if (!mounted) return;
      setState(() {
        _events = [];
        _eventsError = e.message;
        _eventsLoading = false;
      });
    } catch (e) {
      debugPrint('[PlazaScreen] _loadEvents error: $e');
      if (!mounted) return;
      setState(() {
        _events = [];
        _eventsError = '活動載入失敗，請稍後再試';
        _eventsLoading = false;
      });
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
    } on ApiException catch (e) {
      // 看板載不到不應該讓整頁失效，活動小卡仍要顯示。
      debugPrint('[PlazaScreen] _loadBoards ApiException: ${e.message}');
      if (!mounted) return;
      setState(() => _boardsLoading = false);
    } catch (e) {
      debugPrint('[PlazaScreen] _loadBoards error: $e');
      if (!mounted) return;
      setState(() => _boardsLoading = false);
    }
  }

  Future<void> _loadUnread() async {
    try {
      final page = await ForumService.notifications();
      if (!mounted) return;
      setState(() => _unread = page.unreadCount);
    } on ApiException catch (e) {
      // 紅點拿不到就不顯示，不干擾主要內容。
      debugPrint('[PlazaScreen] _loadUnread ApiException: ${e.message}');
    } catch (e) {
      debugPrint('[PlazaScreen] _loadUnread error: $e');
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
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: seniorModeController,
    builder: (context, _) => _buildScaffold(seniorModeController.enabled),
  );

  Widget _buildScaffold(bool seniorMode) => Theme(
    data: forumTheme(context),
    child: ColoredBox(
      color: AppColors.creamLight,
      // 標題、近期活動小卡、看板 tab 都併入貼文列表一起捲動，不再浮在畫面上
      // ——下拉手勢因此也涵蓋得到頁首（見 ForumBoardView.header）。
      child: _buildPostsSection(seniorMode),
    ),
  );

  Widget _buildScrollingHeader(bool seniorMode) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _buildHeader(context, seniorMode),
      if (widget.topToggle != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: widget.topToggle,
        ),
      // 精簡模式不顯示活動，避免與族語學習內容混雜。
      if (!seniorMode) _buildMiniEventCards(),
      _buildTabBar(),
    ],
  );

  Widget _buildHeader(BuildContext context, bool seniorMode) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ALANG · 廣場',
                  style: GoogleFonts.crimsonPro(
                    fontStyle: FontStyle.italic,
                    fontSize: seniorMode ? 16 : 12,
                    color: AppColors.fog,
                    letterSpacing: 3.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '族人在這裡',
                  style: GoogleFonts.notoSerifTc(
                    fontSize: seniorMode ? 32 : 26,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
          // 發布是主要動作放上排，三個次要入口收在它下面：
          // 全部擠在同一列時，標題可用的寬度會被壓到換行。
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _composeButton(seniorMode),
              const SizedBox(height: 2),
              _actionIcons(seniorMode),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _compose() async {
    // 連點會疊出兩個發文畫面：async onTap 沒有 in-flight 防護。
    if (_composing) return;
    if (_boardsLoading) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('看板載入中，請稍候')));
      return;
    }
    if (_boards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('看板載入失敗，請稍後再試'),
          action: SnackBarAction(label: '重試', onPressed: _loadBoards),
        ),
      );
      return;
    }
    _composing = true;
    try {
      final created = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => ForumComposeScreen(boards: _boards)),
      );
      if (created == true) {
        _boardViewKey.currentState?.refresh();
      }
    } finally {
      _composing = false;
    }
  }

  Widget _composeButton(bool seniorMode) =>
      ModuleComposeButton(label: '發布', onTap: _compose, seniorMode: seniorMode);

  Widget _actionIcons(bool seniorMode) => ModuleActionIcons(
    onSearch: () => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ForumSearchScreen(
          boards: _boards,
          onBookmarkChanged: _syncBookmark,
        ),
      ),
    ),
    bookmarksTooltip: '我的收藏',
    onBookmarks: () => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ForumBookmarksScreen(onBookmarkChanged: _syncBookmark),
      ),
    ),
    notificationsTooltip: '通知',
    onNotifications: () async {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ForumNotificationsScreen()),
      );
      if (mounted) _loadUnread();
    },
    hasUnread: _unread > 0,
    seniorMode: seniorMode,
  );

  /// 看板 tab，併入 [_buildScrollingHeader] 隨頁首一起捲動，接在近期活動
  /// 小卡之後、貼文列表之前。名稱短時平均分佈填滿整列，多到放不下才變成
  /// 可捲動——固定間距在只有六個兩字看板時會全部擠在左半邊，右邊留一大片空白。
  Widget _buildTabBar() => Container(
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AppColors.creamDeep)),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          // IntrinsicWidth 讓 Row 先量出自己的寬度，ConstrainedBox 再把它撐到
          // 至少一個螢幕寬，spaceEvenly 才有東西可以分佈。
          child: IntrinsicWidth(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // slug 為 null 代表「全部」，排在最前面且是預設。
                  PlazaBoardTab(
                    label: '全部',
                    selected: _boardSlug == null,
                    onTap: () => setState(() => _boardSlug = null),
                  ),
                  for (final board in _boards)
                    PlazaBoardTab(
                      label: board.name,
                      selected: board.slug == _boardSlug,
                      onTap: () => setState(() => _boardSlug = board.slug),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  /// 近期活動區塊一律顯示，沒有活動時給一句話而不是整塊消失——
  /// 區塊時有時無會讓下面的看板 tab 跟著上下跳。
  Widget _buildMiniEventCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
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
        if (_eventsLoading)
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
          )
        else if (_eventsError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: PlazaEventMessageCard(
              icon: Icons.cloud_off_outlined,
              message: _eventsError!,
              actionLabel: '重試',
              onAction: _loadEvents,
            ),
          )
        else if (_events.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: const PlazaEventMessageCard(
              icon: Icons.event_available_outlined,
              message: '近期暫無活動，敬請期待',
            ),
          )
        else
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              itemCount: _events.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, i) => PlazaMiniEventCard(
                event: _events[i],
                onTap: () => _openEventDetail(_events[i]),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPostsSection(bool seniorMode) {
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
        header: _buildScrollingHeader(seniorMode),
        emptyMessage: slug == null ? '還沒有人發文' : '這個分類還沒有貼文',
        loadPage: ({cursor, after}) => slug == null
            ? ForumService.allPosts(cursor: cursor, after: after)
            : ForumService.posts(slug, cursor: cursor, after: after),
        toggleLike: ForumService.likePost,
        toggleBookmark: ForumService.bookmarkPost,
        onOpenPost: _openPost,
        onRefresh: _refreshHeader,
      ),
    );
  }
}
