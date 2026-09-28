import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../models/event_model.dart';
import '../../services/event_service.dart';
import '../../services/senior_mode_controller.dart';
import '../../shared/widgets/app_back_button.dart';
import '../../shared/widgets/async_state_view.dart';
import '../../shared/widgets/truku_empty_state.dart';
import 'event_detail_screen.dart';
import 'widgets/event_status_tile.dart';

/// 我參加的活動（GET /api/events/joined，含自己發起的）。活動開始後就不在活動
/// 列表裡，使用者從這裡找回自己報名的活動。
///   進行中：即將開始與進行中，開始時間升冪
///   結束：已結束與已取消，開始時間降冪
class JoinedEventsScreen extends StatelessWidget {
  const JoinedEventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: seniorModeController,
      builder: (context, _) => _buildScaffold(seniorModeController.enabled),
    );
  }

  Widget _buildScaffold(bool seniorMode) {
    final tabStyle = AppTypography.bodyLargeStyle(seniorMode: seniorMode);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.creamLight,
        appBar: AppBar(
          leading: const AppBackButton(),
          backgroundColor: AppColors.creamLight,
          foregroundColor: AppColors.ink,
          elevation: 0,
          title: Text(
            '我參加的活動',
            style: AppTypography.serif(
              fontSize: AppTypography.size(
                AppTypography.subtitle,
                seniorMode: seniorMode,
              ),
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          bottom: TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.inkSoft,
            indicatorColor: AppColors.primary,
            labelStyle: tabStyle,
            unselectedLabelStyle: tabStyle,
            tabs: const [
              Tab(text: '進行中'),
              Tab(text: '結束'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _JoinedEventsTab(
              tab: 'active',
              seniorMode: seniorMode,
              emptyMessage: '目前沒有即將開始或進行中的活動',
            ),
            _JoinedEventsTab(
              tab: 'ended',
              seniorMode: seniorMode,
              emptyMessage: '還沒有已結束的活動',
            ),
          ],
        ),
      ),
    );
  }
}

class _JoinedEventsTab extends StatefulWidget {
  final String tab;
  final bool seniorMode;
  final String emptyMessage;

  const _JoinedEventsTab({
    required this.tab,
    required this.seniorMode,
    required this.emptyMessage,
  });

  @override
  State<_JoinedEventsTab> createState() => _JoinedEventsTabState();
}

class _JoinedEventsTabState extends State<_JoinedEventsTab>
    with AutomaticKeepAliveClientMixin {
  static const _pageSize = 20;

  final _scrollController = ScrollController();
  final List<EventSummary> _events = [];
  int _total = 0;
  int _page = 0;
  bool _loading = true;
  bool _loadingMore = false;

  /// 載入下一頁失敗：底部改顯示重試，捲動不再自動重打，等使用者點。
  bool _loadMoreFailed = false;
  Object? _error;

  /// 每次整頁重載加一，較早發出的載入更多回來時就丟棄。
  int _generation = 0;

  bool get _hasMore => _events.length < _total;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) _loadMore();
  }

  /// 載入後列表可能已經在底部（重載時捲動位置被還原、或一頁填不滿畫面），
  /// 不會再有捲動事件，版面排好後自己檢查一次。
  void _checkNearEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) _onScroll();
    });
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      // 進行中的載入更多會因世代不同被丟棄，旗標在這裡清掉，否則之後永遠載不了下一頁。
      _loadingMore = false;
      _loadMoreFailed = false;
      _error = null;
    });
    try {
      final result = await EventService.fetchJoinedEvents(
        tab: widget.tab,
        pageSize: _pageSize,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _events
          ..clear()
          ..addAll(result.events);
        _total = result.total;
        _page = 1;
        _loading = false;
      });
      _checkNearEnd();
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || _loadMoreFailed || !_hasMore) return;
    final generation = _generation;
    setState(() => _loadingMore = true);
    try {
      final result = await EventService.fetchJoinedEvents(
        tab: widget.tab,
        page: _page + 1,
        pageSize: _pageSize,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _events.addAll(result.events);
        _total = result.total;
        _page++;
        // 後端筆數在翻頁間變少（例如活動剛被刪除）時，空頁代表已到底。
        if (result.events.isEmpty) _total = _events.length;
        _loadingMore = false;
      });
      _checkNearEnd();
    } catch (e) {
      debugPrint('JoinedEventsScreen._loadMore failed: $e');
      if (!mounted || generation != _generation) return;
      setState(() {
        _loadingMore = false;
        _loadMoreFailed = true;
      });
    }
  }

  void _retryLoadMore() {
    setState(() => _loadMoreFailed = false);
    _loadMore();
  }

  Future<void> _open(EventSummary e) async {
    await Navigator.push(context, EventDetailScreen.route(e.id));
    if (!mounted) return;
    _load(); // 從詳情頁回來可能已退出或被取消，重抓這一頁
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    final seniorMode = widget.seniorMode;
    if (_loading) return const TrukuLoadingView();
    if (_error != null) {
      // 包在 ListView 裡才能維持下拉重新整理
      return ListView(
        children: [
          TrukuErrorView(
            error: _error,
            onRetry: _load,
            seniorMode: seniorMode,
            fallback: '載入活動失敗，請稍後再試',
            topPadding: 90,
          ),
        ],
      );
    }
    if (_events.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 60, bottom: 24),
        children: [
          TrukuEmptyState(
            icon: Icons.event_outlined,
            message: widget.emptyMessage,
            subtitle: '報名的活動會出現在這裡。',
            seniorMode: seniorMode,
            scrollable: false,
          ),
        ],
      );
    }
    return ListView.separated(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      itemCount: _events.length + (_hasMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        if (i == _events.length) {
          if (_loadMoreFailed) {
            return Center(
              child: TextButton(
                onPressed: _retryLoadMore,
                child: Text(
                  '載入失敗，點此重試',
                  style: AppTypography.bodyLargeStyle(
                    seniorMode: seniorMode,
                    color: AppColors.primary,
                  ),
                ),
              ),
            );
          }
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }
        final e = _events[i];
        return EventStatusTile(
          event: e,
          seniorMode: seniorMode,
          upcomingLabel: '即將開始',
          showHostBadge: e.isHost,
          onTap: () => _open(e),
        );
      },
    );
  }
}
