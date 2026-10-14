// 後台分頁列表：翻頁狀態（AdminPagedListController）與畫面（AdminPagedListView）。
//
// 篩選條件由畫面自己管：fetch 閉包每次讀目前的條件，條件變了呼叫 reset()。
// 晚回來的舊回應、下一頁失敗後不自動重打、非管理員退出後台都在這裡處理，
// 各列表畫面只需要給 fetch 與每一列長什麼樣子。

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../services/admin_service.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../../../shared/widgets/truku_empty_state.dart';
import 'admin_widgets.dart' show AdminLoadMoreFooter;

class AdminPagedListController<T> extends ChangeNotifier {
  /// 取一頁；[cursor] 為 null 是第一頁。
  final Future<AdminPage<T>> Function(String? cursor) fetch;

  /// 錯誤先交給它；回 true 代表已處理（例如非管理員已退出後台），列表不再顯示錯誤。
  final bool Function(Object error)? onError;

  AdminPagedListController({required this.fetch, this.onError});

  final List<T> _items = [];
  String? _cursor;
  bool _loading = true;
  bool _loadingMore = false;

  /// 下一頁載入失敗：捲動不再自動重打，等使用者點尾端的重試列。
  bool _loadMoreFailed = false;
  Object? _error;

  /// 每次重載加一：切換條件或重新整理時，晚回來的舊回應直接丟掉。
  int _generation = 0;
  bool _disposed = false;

  List<T> get items => List.unmodifiable(_items);

  /// 第一頁載入中且畫面上沒有舊資料。
  bool get loading => _loading;
  bool get loadingMore => _loadingMore;
  bool get loadMoreFailed => _loadMoreFailed;
  bool get hasMore => _cursor != null;

  /// 第一頁載入失敗的錯誤；有舊資料時重新整理失敗也會設定。
  Object? get error => _error;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// 重抓第一頁。舊資料留在畫面上直到新資料回來（下拉重新整理用）。
  Future<void> reload() async {
    final generation = ++_generation;
    _loading = _items.isEmpty;
    _error = null;
    _notify();
    try {
      final page = await fetch(null);
      if (_disposed || generation != _generation) return;
      _items
        ..clear()
        ..addAll(page.items);
      _cursor = page.pageInfo.nextCursor;
      _loading = false;
      _loadingMore = false;
      _loadMoreFailed = false;
      _notify();
    } catch (e) {
      if (_disposed || generation != _generation) return;
      if (onError?.call(e) ?? false) return;
      _error = e;
      _loading = false;
      _notify();
    }
  }

  /// 篩選條件變了：清掉舊資料（顯示載入中）再抓第一頁。
  Future<void> reset() {
    _items.clear();
    _cursor = null;
    _loadMoreFailed = false;
    return reload();
  }

  Future<void> loadMore() async {
    final cursor = _cursor;
    if (_loadingMore || _loading || _loadMoreFailed || cursor == null) return;
    final generation = _generation;
    _loadingMore = true;
    _notify();
    try {
      final page = await fetch(cursor);
      if (_disposed || generation != _generation) return;
      _items.addAll(page.items);
      _cursor = page.pageInfo.nextCursor;
      _loadingMore = false;
      _notify();
    } catch (e) {
      if (_disposed || generation != _generation) return;
      _loadingMore = false;
      _loadMoreFailed = true;
      _notify();
      // 尾端重試列已說明失敗，不另跳提示；非管理員仍交給 onError 退出後台。
      onError?.call(e);
    }
  }

  void retryLoadMore() {
    _loadMoreFailed = false;
    loadMore();
  }

  /// 把第一筆符合 [test] 的換成 [item]（例如編輯後伺服器回傳的新資料），
  /// 不重抓列表。沒有符合的回 false。
  bool replace(bool Function(T item) test, T item) {
    final i = _items.indexWhere(test);
    if (i < 0) return false;
    _items[i] = item;
    _notify();
    return true;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// [AdminPagedListController] 的畫面：載入中、錯誤重試、空狀態、下拉重新整理、
/// 捲到底載下一頁。
class AdminPagedListView<T> extends StatefulWidget {
  final AdminPagedListController<T> controller;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final bool seniorMode;
  final String emptyMessage;

  const AdminPagedListView({
    super.key,
    required this.controller,
    required this.itemBuilder,
    required this.seniorMode,
    this.emptyMessage = '目前沒有資料',
  });

  @override
  State<AdminPagedListView<T>> createState() => _AdminPagedListViewState<T>();
}

class _AdminPagedListViewState<T> extends State<AdminPagedListView<T>> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      widget.controller.loadMore();
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) => _content(context),
  );

  Widget _content(BuildContext context) {
    final c = widget.controller;
    final senior = widget.seniorMode;
    if (c.loading) return const TrukuLoadingView();
    if (c.error != null) {
      return TrukuErrorView(
        error: c.error,
        onRetry: c.reload,
        seniorMode: senior,
      );
    }
    final items = c.items;
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: c.reload,
      child: items.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(top: AppSpacing.xl),
              children: [
                TrukuEmptyState(
                  icon: Icons.inbox_outlined,
                  message: widget.emptyMessage,
                  subtitle: '',
                  seniorMode: senior,
                  scrollable: false,
                ),
              ],
            )
          : ListView.builder(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              itemCount: items.length + (c.hasMore ? 1 : 0),
              itemBuilder: (context, i) {
                if (i >= items.length) {
                  return AdminLoadMoreFooter(
                    failed: c.loadMoreFailed,
                    onRetry: c.retryLoadMore,
                    seniorMode: senior,
                  );
                }
                return widget.itemBuilder(context, items[i]);
              },
            ),
    );
  }
}
