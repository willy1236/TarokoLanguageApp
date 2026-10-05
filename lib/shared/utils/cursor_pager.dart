// 往下捲帶游標翻頁的清單狀態：第一頁、下一頁、下拉重整、翻頁失敗重試。
// 規格：Truku_backend 說明文件/API/00_核心與認證.md §0「列表分頁」
//
// 畫面只管捲到底時呼叫 [CursorPager.loadMore]、下拉時呼叫 [CursorPager.refresh]，
// 世代、去重、旗標重設都在這裡處理。

import 'package:flutter/foundation.dart';

import '../../models/page_info.dart';

class CursorPager<T> extends ChangeNotifier {
  /// [fetch] 取一頁；cursor 為 null 代表第一頁。[idOf] 是去重用的 key。
  CursorPager({
    required Future<(List<T>, PageInfo)> Function(String? cursor) fetch,
    required Object Function(T item) idOf,
  }) : _fetch = fetch,
       _idOf = idOf;

  final Future<(List<T>, PageInfo)> Function(String? cursor) _fetch;
  final Object Function(T item) _idOf;

  List<T> _items = const [];
  String? _cursor;
  bool _loading = false;
  bool _loadingMore = false;
  bool _loadMoreFailed = false;
  Object? _error;
  bool _disposed = false;

  /// 每次重整加一；較早送出的請求回來時世代不同就丟棄，
  /// 不會把舊清單的下一頁接到新清單後面。
  int _generation = 0;

  List<T> get items => _items;

  /// 正在抓第一頁（初次載入或下拉重整）。
  bool get loading => _loading;
  bool get loadingMore => _loadingMore;

  /// 第一頁失敗的原因；成功或重新整理時清掉。
  Object? get error => _error;

  /// 下一頁失敗：捲動不再自動重打，等使用者按重試。
  bool get loadMoreFailed => _loadMoreFailed;
  bool get hasMore => _cursor != null;

  /// 重抓第一頁，換掉整份清單。
  Future<void> refresh() async {
    final generation = ++_generation;
    _loading = true;
    // 進行中的載入更多會因世代不同被丟棄，旗標在這裡清掉，否則之後永遠載不了下一頁。
    _loadingMore = false;
    _loadMoreFailed = false;
    _error = null;
    _notify();
    try {
      final (page, info) = await _fetch(null);
      if (_disposed || generation != _generation) return;
      _items = appendUnique(const [], page, _idOf);
      _cursor = info.nextCursor;
    } catch (e) {
      if (_disposed || generation != _generation) return;
      _error = e;
    }
    _loading = false;
    _notify();
  }

  /// 抓下一頁接在後面。載入中、上次翻頁失敗、或沒有下一頁時不動。
  ///
  /// PagerScrollLoader 會在每次 notify 後呼叫這裡，所以翻頁失敗或沒有下一頁時
  /// 必須維持不動；拿掉這些判斷會變成無限自動重打。
  Future<void> loadMore() async {
    final cursor = _cursor;
    if (_loading || _loadingMore || _loadMoreFailed || cursor == null) return;
    final generation = _generation;
    _loadingMore = true;
    _notify();
    try {
      final (page, info) = await _fetch(cursor);
      if (_disposed || generation != _generation) return;
      _items = appendUnique(_items, page, _idOf);
      _cursor = info.nextCursor;
    } catch (e) {
      debugPrint('CursorPager.loadMore failed: $e');
      if (_disposed || generation != _generation) return;
      _loadMoreFailed = true;
    }
    _loadingMore = false;
    _notify();
  }

  /// 使用者按了底部的重試。
  void retryLoadMore() {
    _loadMoreFailed = false;
    _notify();
    loadMore();
  }

  /// 就地移除項目（例如取消按讚），不重抓。
  void removeWhere(bool Function(T item) test) {
    _items = [
      for (final item in _items)
        if (!test(item)) item,
    ];
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
