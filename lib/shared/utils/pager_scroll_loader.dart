// 把清單的捲動接到 CursorPager：捲到接近底部就翻下一頁。
//
// 只靠捲動事件不夠：第一頁填不滿畫面、或下一頁去重後沒有新增項目時，清單已經在
// 底部，不會再有捲動事件。所以每次 pager 狀態變動後，等版面排好再自己檢查一次。
// 翻頁失敗或沒有下一頁時 CursorPager.loadMore 不動，不會無限重打。

import 'package:flutter/widgets.dart';

import 'cursor_pager.dart';

class PagerScrollLoader {
  /// [nearEndExtent]：距離底部多少以內就翻頁。
  PagerScrollLoader({
    required ScrollController controller,
    required CursorPager<Object?> pager,
    this.nearEndExtent = 300,
  }) : _controller = controller,
       _pager = pager {
    _controller.addListener(_check);
    _pager.addListener(_scheduleCheck);
  }

  final ScrollController _controller;
  final CursorPager<Object?> _pager;
  final double nearEndExtent;
  bool _scheduled = false;
  bool _disposed = false;

  void _scheduleCheck() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!_disposed) _check();
    });
  }

  void _check() {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    if (position.pixels >= position.maxScrollExtent - nearEndExtent) {
      _pager.loadMore();
    }
  }

  /// 在 pager 與 controller dispose 之前呼叫。
  void dispose() {
    _disposed = true;
    _controller.removeListener(_check);
    _pager.removeListener(_scheduleCheck);
  }
}
