import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../shared/widgets/truku_empty_state.dart';
import '../../models/content_category.dart';
import '../../models/event_model.dart';
import '../../models/inbox_models.dart';
import '../../services/account_lock_controller.dart';
import '../../services/category_service.dart';
import '../../services/event_service.dart';
import '../../services/notification_summary_service.dart';
import '../../services/senior_mode_controller.dart';
import '../../services/user_service.dart';
import 'event_compose_screen.dart';
import 'widgets/event_cards.dart';
import 'event_detail_screen.dart';
import 'event_search_screen.dart';
import 'widgets/event_cover.dart';
import '../inbox/inbox_screen.dart';
import '../../shared/widgets/async_state_view.dart';
import '../../shared/widgets/module_header_actions.dart';
import '../../core/constants/app_typography.dart';
import '../../shared/utils/cursor_pager.dart';
import '../../shared/utils/pager_scroll_loader.dart';
import '../../shared/widgets/load_more_retry.dart';

/// 活動列表 —— 真資料版（GET /api/events，往下捲帶游標翻頁）。
/// 發起活動返回後自動刷新；下拉可重新整理。需登入（未登入 API 會 401 導回登入）。
class EventsScreen extends StatefulWidget {
  /// 由外層（合併分頁的膠囊切換）注入，顯示在標題與篩選 chips 之間。
  final Widget? topToggle;

  const EventsScreen({super.key, this.topToggle});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  // 後端列表只回尚未開始的活動、依開始時間升冪（Truku_backend 決策 A22），前端不重排。
  // 「全部」之外的篩選是後端分類表（GET /api/events/categories）裡目前有活動的分類，
  // 選了就帶 category 從第一頁重查，由後端篩選、可一路翻頁到底。

  /// 選中的分類 value；null = 全部。
  String? _category;

  /// 最近一次抓到的分類清單（含 count 0，顯示時才濾掉）。
  /// 重抓失敗時保留上一次的；第一次就沒抓到則只顯示「全部」。
  List<ContentCategory> _categories = const [];

  final _scrollController = ScrollController();
  late final PagerScrollLoader _scrollLoader;
  late final _pager = CursorPager<EventSummary>(
    fetch: (cursor) async {
      final page = await EventService.fetchEvents(
        category: _category,
        cursor: cursor,
      );
      return (page.events, page.pageInfo);
    },
    idOf: (e) => e.id,
  );

  int get _unread => NotificationSummaryService.notifier.value.inbox.event;

  // 是否可發起活動（organizer/admin）。跟著 userNotifier 走：角色被管理員改掉時
  // （account_role 推播會重抓 /api/me）按鈕即時跟著變；還沒取得身分前保守擋下。
  bool get _canCreateEvent =>
      UserService.userNotifier.value?.canCreateEvent ?? false;

  /// 篩選列上的分類：只列目前有活動的，順序照後端。
  List<ContentCategory> get _filterCategories => [
    for (final c in _categories)
      if (c.count > 0) c,
  ];

  @override
  void initState() {
    super.initState();
    NotificationSummaryService.notifier.addListener(_rebuild);
    UserService.userNotifier.addListener(_rebuild);
    _scrollLoader = PagerScrollLoader(
      controller: _scrollController,
      pager: _pager,
    );
    _pager.refresh();
    _loadCategories();
    _loadRole();
  }

  @override
  void dispose() {
    NotificationSummaryService.notifier.removeListener(_rebuild);
    UserService.userNotifier.removeListener(_rebuild);
    _scrollLoader.dispose();
    _scrollController.dispose();
    _pager.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  /// 確保 userNotifier 有值；拿到後由監聽器觸發重繪。
  Future<void> _loadRole() async {
    try {
      await UserService.fetchMe();
    } catch (_) {
      // 拿不到身分就維持擋下，不影響列表其餘功能。
    }
  }

  /// 抓分類清單（每次都向後端要新的，count 才會是最新的）。
  /// 選中的分類已經沒有活動、不在篩選列上時，切回「全部」重載。
  Future<void> _loadCategories() async {
    try {
      final list = await CategoryService.fetch(
        CategoryModule.events,
        refresh: true,
      );
      if (!mounted) return;
      setState(() => _categories = list);
      final selected = _category;
      if (selected != null &&
          !_filterCategories.any((c) => c.value == selected)) {
        _selectCategory(null);
      }
    } catch (e) {
      // 保留上一次的篩選列與選擇；第一次就失敗則只有「全部」。
      debugPrint('EventsScreen: 分類清單載入失敗：$e');
    }
  }

  /// 下拉重新整理：列表與分類清單一起重抓。
  Future<void> _reload() async {
    await Future.wait([_pager.refresh(), _loadCategories()]);
  }

  void _selectCategory(String? value) {
    if (value == _category) return;
    setState(() => _category = value);
    _pager.refresh();
  }

  void _openCompose() {
    if (blockIfReadOnly()) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EventComposeScreen()),
    ).then((created) {
      if (created == true) _pager.refresh(); // 成功發起才刷新列表
    });
  }

  void _openDetail(EventSummary e) {
    // 詳情頁自行以 eventId 打 GET /api/events/:id 取真資料（含發起人姓名、
    // isHost 判斷、報名狀態）。回來後刷新清單，反映報名/退出。
    Navigator.push(context, EventDetailScreen.route(e.id)).then((_) {
      if (mounted) _pager.refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([seniorModeController, _pager]),
      builder: (context, _) => _buildScaffold(seniorModeController.enabled),
    );
  }

  Widget _buildScaffold(bool seniorMode) {
    return ColoredBox(
      color: AppColors.creamLight,
      child: EventCoverRefresher(
        onRefresh: _pager.silentRefresh,
        child: RefreshIndicator(
          onRefresh: _reload,
          color: AppColors.primary,
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(seniorMode)),
              if (widget.topToggle != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: widget.topToggle,
                  ),
                ),
              SliverToBoxAdapter(child: _buildFilterChips(seniorMode)),
              ..._buildContentSlivers(seniorMode),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildContentSlivers(bool seniorMode) {
    if (_pager.loading) {
      return [
        const SliverToBoxAdapter(child: TrukuLoadingView(topPadding: 80)),
      ];
    }
    if (_pager.error != null) {
      return [
        SliverToBoxAdapter(
          child: TrukuErrorView(
            error: _pager.error,
            onRetry: _pager.refresh,
            seniorMode: seniorMode,
            fallback: '載入活動失敗，請稍後再試',
            topPadding: 80,
          ),
        ),
      ];
    }
    final events = _pager.items;
    if (events.isEmpty) {
      return [SliverToBoxAdapter(child: _buildEmpty(seniorMode))];
    }
    return [
      SliverToBoxAdapter(
        child: EventFeaturedCard(
          event: events.first,
          seniorMode: seniorMode,
          onTap: _openDetail,
        ),
      ),
      if (events.length > 1) SliverToBoxAdapter(child: _buildDivider()),
      SliverToBoxAdapter(
        child: EventList(
          events: events,
          seniorMode: seniorMode,
          onTap: _openDetail,
        ),
      ),
      SliverToBoxAdapter(child: _buildLoadMoreFooter(seniorMode)),
    ];
  }

  /// 清單底部：翻頁中轉圈、翻頁失敗顯示重試，其餘不佔位置。
  Widget _buildLoadMoreFooter(bool seniorMode) {
    if (_pager.loadMoreFailed) {
      return LoadMoreRetry(
        onRetry: _pager.retryLoadMore,
        color: AppColors.primary,
        seniorMode: seniorMode,
      );
    }
    if (!_pager.loadingMore) return const SizedBox.shrink();
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
    );
  }

  Widget _buildEmpty(bool seniorMode) {
    return TrukuEmptyState(
      icon: Icons.event_note_outlined,
      message: '目前沒有活動',
      subtitle: '點右上角「發起」開一場部落聚會吧',
      seniorMode: seniorMode,
    );
  }

  Widget _buildHeader(bool seniorMode) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 14),
      // 眉標獨立一行、不進下面那個 Row：它若和主標同欄，右側按鈕會跟「眉標+
      // 主標」整欄置中，中心落在兩行之間，看起來就跟主標沒切齊。
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 精簡模式隱藏羅馬拼音眉標，與首頁、視訊配對一致。
          if (!seniorMode) ...[
            Text(
              'SMRATUC · 活動',
              style: AppTypography.latin(
                fontStyle: FontStyle.italic,
                fontSize: AppTypography.caption,
                color: AppColors.fog,
                letterSpacing: 3.0,
              ),
            ),
            const SizedBox(height: 4),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                // 窄螢幕或放大顯示時寬度不足，縮小字級而非截成「…」。
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    // 精簡模式字級放大後長標題會被截斷，改用與切換鈕一致的短標題。
                    seniorMode ? '活動' : '近期部落聚會',
                    maxLines: 1,
                    style: AppTypography.serif(
                      fontSize: seniorMode
                          ? AppTypography.display32
                          : AppTypography.display26,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
              // 移除「我的收藏」後寬度足夠，次要圖示與發起鈕收回主標同一橫線。
              _actionIcons(seniorMode),
              const SizedBox(width: 4),
              _composeButton(seniorMode),
            ],
          ),
        ],
      ),
    );
  }

  Widget _composeButton(bool seniorMode) => ModuleComposeButton(
    label: '發起',
    enabled: _canCreateEvent,
    onTap: _openCompose,
    seniorMode: seniorMode,
  );

  Widget _actionIcons(bool seniorMode) => ModuleActionIcons(
    onSearch: () => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EventSearchScreen()),
    ),
    notificationsTooltip: '活動通知',
    onNotifications: () async {
      await Navigator.push(
        context,
        InboxScreen.route(initialCategory: InboxCategory.event),
      );
      NotificationSummaryService.refresh();
    },
    hasUnread: _unread > 0,
    seniorMode: seniorMode,
  );

  Widget _buildFilterChips(bool seniorMode) {
    // 第一顆固定是「全部」（value null），其後照後端順序列出目前有活動的分類。
    final chips = <(String?, String)>[
      (null, '全部'),
      for (final c in _filterCategories) (c.value, c.label),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: SizedBox(
        height: seniorMode ? 48 : 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: chips.length,
          separatorBuilder: (context, i) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final (value, label) = chips[i];
            final active = _category == value;
            return GestureDetector(
              onTap: () => _selectCategory(value),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: seniorMode ? 18 : 14,
                  vertical: seniorMode ? 12 : 7,
                ),
                decoration: BoxDecoration(
                  color: active ? AppColors.ink : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: active
                      ? null
                      : Border.all(color: AppColors.creamDeep),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: AppTypography.size(
                      AppTypography.caption,
                      seniorMode: seniorMode,
                    ),
                    color: active ? AppColors.creamLight : AppColors.inkSoft,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
      child: Row(
        children: [
          const Expanded(child: Divider(color: AppColors.creamDeep)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              '更多活動',
              style: AppTypography.latin(
                fontStyle: FontStyle.italic,
                fontSize: AppTypography.micro,
                color: AppColors.fog,
                letterSpacing: 3.0,
              ),
            ),
          ),
          const Expanded(child: Divider(color: AppColors.creamDeep)),
        ],
      ),
    );
  }
}
