import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../models/event_model.dart';
import '../../../models/page_info.dart';
import '../../../services/event_service.dart';
import '../../../shared/widgets/async_state_view.dart';

/// 往下捲分頁的活動清單：下拉重新整理、捲到底載入下一頁、載入下一頁失敗時
/// 底部改顯示重試。「我參加的活動」兩個分頁與「我發起的活動」共用。
class PagedEventList extends StatefulWidget {
  /// 取一頁活動；[cursor] 為 null 代表第一頁。
  final Future<EventPage> Function(String? cursor) loadPage;

  /// 一筆活動的列。[reload] 整頁重載，給從詳情頁回來、活動可能已變動時用。
  final Widget Function(EventSummary event, Future<void> Function() reload)
  itemBuilder;

  /// 第一頁就沒有活動時顯示，會包在可下拉的 ListView 裡。
  final Widget emptyState;
  final bool seniorMode;

  const PagedEventList({
    super.key,
    required this.loadPage,
    required this.itemBuilder,
    required this.emptyState,
    required this.seniorMode,
  });

  @override
  State<PagedEventList> createState() => _PagedEventListState();
}

class _PagedEventListState extends State<PagedEventList>
    with AutomaticKeepAliveClientMixin {
  final _scrollController = ScrollController();
  List<EventSummary> _events = [];
  String? _cursor;
  bool _loading = true;
  bool _loadingMore = false;

  /// 載入下一頁失敗：底部改顯示重試，捲動不再自動重打，等使用者點。
  bool _loadMoreFailed = false;
  Object? _error;

  /// 每次整頁重載加一，較早發出的載入更多回來時就丟棄。
  int _generation = 0;

  // 放在 TabBarView 裡時，切走再切回來保留已載入的頁數與捲動位置。
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
    // 從詳情頁返回才呼叫的重載，這時清單可能已經被移出畫面。
    if (!mounted) return;
    final generation = ++_generation;
    setState(() {
      _loading = true;
      // 進行中的載入更多會因世代不同被丟棄，旗標在這裡清掉，否則之後永遠載不了下一頁。
      _loadingMore = false;
      _loadMoreFailed = false;
      _error = null;
    });
    try {
      final page = await widget.loadPage(null);
      if (!mounted || generation != _generation) return;
      setState(() {
        _events = page.events;
        _cursor = page.pageInfo.nextCursor;
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
    final cursor = _cursor;
    if (_loading || _loadingMore || _loadMoreFailed || cursor == null) return;
    final generation = _generation;
    setState(() => _loadingMore = true);
    try {
      final page = await widget.loadPage(cursor);
      if (!mounted || generation != _generation) return;
      setState(() {
        _events = appendUnique(_events, page.events, (e) => e.id);
        _cursor = page.pageInfo.nextCursor;
        _loadingMore = false;
      });
      _checkNearEnd();
    } catch (e) {
      debugPrint('PagedEventList._loadMore failed: $e');
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
        children: [widget.emptyState],
      );
    }
    return ListView.separated(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      itemCount: _events.length + (_cursor != null ? 1 : 0),
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
        return widget.itemBuilder(_events[i], _load);
      },
    );
  }
}
