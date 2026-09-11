import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../shared/widgets/truku_empty_state.dart';
import '../../models/event_model.dart';
import '../../services/event_service.dart';
import '../../services/senior_mode_controller.dart';
import '../../services/user_service.dart';
import 'event_bookmarks_screen.dart';
import 'event_compose_screen.dart';
import 'widgets/event_cards.dart';
import 'event_detail_screen.dart';
import 'event_notifications_screen.dart';
import 'event_search_screen.dart';
import '../../shared/widgets/async_state_view.dart';
import '../../shared/widgets/module_header_actions.dart';
import '../../core/constants/app_typography.dart';

/// 活動列表 —— 真資料版（GET /api/events）。
/// 發起活動返回後自動刷新；下拉可重新整理。需登入（未登入 API 會 401 導回登入）。
class EventsScreen extends StatefulWidget {
  /// 由外層（合併分頁的膠囊切換）注入，顯示在標題與篩選 chips 之間。
  final Widget? topToggle;

  const EventsScreen({super.key, this.topToggle});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  // 前兩顆對應後端 scope（全部=all、近期=upcoming，會重新打 API）；
  // 其餘為分類篩選（對應發起活動表單的分類清單），在目前已載入的 scope 資料上做前端篩選。
  static const _filters = ['全部', '近期', '族語', '走讀', '工藝', '線上', '音樂', '其他'];
  int _filterIndex = 0;
  String _scope = 'all';

  bool _loading = true;
  Object? _error;
  List<EventSummary> _events = [];
  int _unread = 0;

  // 是否可發起活動（organizer/admin），初始 false 保守擋下，取得身分後才放行。
  bool _canCreateEvent = false;

  @override
  void initState() {
    super.initState();
    _load();
    _loadUnread();
    _loadRole();
  }

  Future<void> _loadRole() async {
    try {
      final user = await UserService.fetchMe();
      if (!mounted) return;
      setState(() => _canCreateEvent = user.canCreateEvent);
    } catch (_) {
      // 拿不到身分就維持擋下，不影響列表其餘功能。
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final events = await EventService.fetchEvents(scope: _scope);
      if (!mounted) return;
      setState(() {
        _events = events;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _loadUnread() async {
    try {
      final page = await EventService.notifications();
      if (!mounted) return;
      setState(() => _unread = page.unreadCount);
    } catch (_) {
      // 紅點拿不到就不顯示，不干擾主要內容。
    }
  }

  void _onFilterTap(int i) {
    final filter = _filters[i];
    if (filter == '全部' || filter == '近期') {
      setState(() {
        _filterIndex = i;
        _scope = filter == '全部' ? 'all' : 'upcoming';
      });
      _load();
    } else {
      setState(() => _filterIndex = i);
    }
  }

  List<EventSummary> get _filteredEvents {
    final filter = _filters[_filterIndex];
    if (filter == '全部' || filter == '近期') return _events;
    return _events.where((e) => e.category == filter).toList();
  }

  void _openCompose() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EventComposeScreen()),
    ).then((created) {
      if (created == true) _load(); // 成功發起才刷新列表
    });
  }

  void _openDetail(EventSummary e) {
    // 詳情頁自行以 eventId 打 GET /api/events/:id 取真資料（含發起人姓名、
    // isHost 判斷、報名狀態）。回來後刷新清單，反映報名/退出。
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EventDetailScreen(eventId: e.id)),
    ).then((_) {
      if (mounted) _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: seniorModeController,
      builder: (context, _) => _buildScaffold(seniorModeController.enabled),
    );
  }

  Widget _buildScaffold(bool seniorMode) {
    return ColoredBox(
      color: AppColors.creamLight,
      child: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primary,
        child: CustomScrollView(
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
    );
  }

  List<Widget> _buildContentSlivers(bool seniorMode) {
    if (_loading) {
      return [
        const SliverToBoxAdapter(child: TrukuLoadingView(topPadding: 80)),
      ];
    }
    if (_error != null) {
      return [
        SliverToBoxAdapter(
          child: TrukuErrorView(
            error: _error,
            onRetry: _load,
            seniorMode: seniorMode,
            fallback: '載入活動失敗，請稍後再試',
            topPadding: 80,
          ),
        ),
      ];
    }
    final events = _filteredEvents;
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
    ];
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
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
                Text(
                  '近期部落聚會',
                  style: AppTypography.serif(
                    fontSize: seniorMode ? AppTypography.display32 : AppTypography.display26,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
          // 發起是主要動作放上排，三個次要入口收在它下面：
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
    bookmarksTooltip: '我收藏的活動',
    onBookmarks: () => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EventBookmarksScreen()),
    ),
    notificationsTooltip: '活動通知',
    onNotifications: () async {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const EventNotificationsScreen()),
      );
      if (mounted) _loadUnread();
    },
    hasUnread: _unread > 0,
    seniorMode: seniorMode,
  );

  Widget _buildFilterChips(bool seniorMode) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: SizedBox(
        height: seniorMode ? 48 : 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: _filters.length,
          separatorBuilder: (context, i) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final active = _filterIndex == i;
            return GestureDetector(
              onTap: () => _onFilterTap(i),
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
                  _filters[i],
                  style: TextStyle(
                    fontSize: AppTypography.size(AppTypography.caption, seniorMode: seniorMode),
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
