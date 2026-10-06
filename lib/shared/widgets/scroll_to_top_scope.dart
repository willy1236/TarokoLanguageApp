import 'package:flutter/widgets.dart';

/// 收到 [signal] 時，把 [child] 底下所有垂直捲動元件直接跳回最上面（不做動畫）。
///
/// 給底部導航的分頁根部用：分頁裡的捲動元件有的自帶 controller、有的沒有，
/// 膠囊切換又用 `IndexedStack` 把兩塊內容都留在 tree 裡。這裡直接走訪子樹找
/// [ScrollableState]，不必替每個捲動元件補 controller，也不依賴
/// [PrimaryScrollController]（它只在行動平台預設自動繼承，Web／桌面行為不同）。
///
/// 只動捲動位置，不動任何 State：分類、排序、輸入內容都保留。
/// 橫向捲動（輪播、chip 列）不動。
///
/// 前提：子樹裡「所有」垂直 [Scrollable] 都會被歸零，不只頁面主體那一條——
/// 多行 `TextField` 內部的捲動、直式 `PageView`、巢狀的垂直清單都算在內。
/// 若子樹裡有不該被重設的垂直捲動（例如直式翻頁要停在原頁），不要把它放在
/// 這個元件底下，或另外處理。
class ScrollToTopScope extends StatefulWidget {
  final Listenable signal;
  final Widget child;

  const ScrollToTopScope({
    super.key,
    required this.signal,
    required this.child,
  });

  @override
  State<ScrollToTopScope> createState() => _ScrollToTopScopeState();
}

class _ScrollToTopScopeState extends State<ScrollToTopScope> {
  @override
  void initState() {
    super.initState();
    widget.signal.addListener(_scrollToTop);
  }

  @override
  void didUpdateWidget(ScrollToTopScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.signal != widget.signal) {
      oldWidget.signal.removeListener(_scrollToTop);
      widget.signal.addListener(_scrollToTop);
    }
  }

  @override
  void dispose() {
    widget.signal.removeListener(_scrollToTop);
    super.dispose();
  }

  void _scrollToTop() {
    if (!mounted) return;
    void visit(Element element) {
      if (element is StatefulElement) {
        final state = element.state;
        if (state is ScrollableState) _jumpToTop(state.position);
      }
      element.visitChildren(visit);
    }

    context.visitChildElements(visit);
  }

  static void _jumpToTop(ScrollPosition position) {
    if (axisDirectionToAxis(position.axisDirection) != Axis.vertical) return;
    if (!position.hasPixels || position.pixels == 0) return;
    position.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
