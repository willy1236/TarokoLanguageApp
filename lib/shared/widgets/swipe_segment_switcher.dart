import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// 在內容區左右大滑切換膠囊分頁：往左滑到右邊一段、往右滑到左邊一段，兩端不繞回。
///
/// 只看放開時的總位移：水平距離達寬度 × [distanceFraction]、且明顯比垂直位移大
/// 才切換；不看甩動速度，避免輕甩或斜著捲清單誤切。只認觸控與觸控筆，滑鼠拖曳
/// 不觸發。內層能橫滑的元件（輪播、chip 列）在手勢競技場裡較深、會先贏，不必排除。
///
/// 滑動中 [child] 跟手微移並略淡化，[onDragProgress] 同步回報進度給膠囊預移色塊；
/// 不到門檻放開時平滑彈回，換段時直接歸零，新內容從正常位置出現。
class SwipeSegmentSwitcher extends StatefulWidget {
  final int index;
  final int count;
  final ValueChanged<int> onChanged;

  /// 滑動進度（-1..1，相對門檻的比例；正值往右邊一段）。兩端往外滑時為 0，
  /// 放開或取消後回到 0。
  final ValueChanged<double>? onDragProgress;

  final double distanceFraction;
  final Widget child;

  const SwipeSegmentSwitcher({
    super.key,
    required this.index,
    required this.count,
    required this.onChanged,
    required this.child,
    this.onDragProgress,
    this.distanceFraction = 0.4,
  });

  @override
  State<SwipeSegmentSwitcher> createState() => _SwipeSegmentSwitcherState();
}

class _SwipeSegmentSwitcherState extends State<SwipeSegmentSwitcher>
    with SingleTickerProviderStateMixin {
  static const _maxShift = 24.0;
  static const _minOpacity = 0.85;

  late final AnimationController _settle;
  double _settleFrom = 0;

  Offset _start = Offset.zero;
  Offset _last = Offset.zero;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _settle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..addListener(_onSettleTick);
  }

  @override
  void dispose() {
    _settle.dispose();
    super.dispose();
  }

  double get _threshold => (context.size?.width ?? 0) * widget.distanceFraction;

  // 手指往左（dx 為負）代表要去右邊一段，進度為正。
  double get _dragProgress {
    final threshold = _threshold;
    if (threshold <= 0) return 0;
    final p = (-(_last.dx - _start.dx) / threshold).clamp(-1.0, 1.0);
    final atStart = widget.index == 0 && p < 0;
    final atEnd = widget.index == widget.count - 1 && p > 0;
    return atStart || atEnd ? 0 : p;
  }

  void _setProgress(double value) {
    if (value == _progress) return;
    setState(() => _progress = value);
    widget.onDragProgress?.call(value);
  }

  void _onSettleTick() {
    _setProgress(_settleFrom * (1 - Curves.easeOut.transform(_settle.value)));
  }

  // 點擊或縱向捲動時水平辨識器輸掉競技場也會走到這裡，進度本來就是 0 不必跑動畫。
  void _settleBack() {
    if (_progress == 0) return;
    _settleFrom = _progress;
    _settle.forward(from: 0);
  }

  void _onStart(DragStartDetails details) {
    _settle.stop();
    _start = _last = details.globalPosition;
  }

  void _onUpdate(DragUpdateDetails details) {
    _last = details.globalPosition;
    _setProgress(_dragProgress);
  }

  void _onEnd(DragEndDetails _) {
    final dx = _last.dx - _start.dx;
    final dy = _last.dy - _start.dy;
    final target = dx < 0 ? widget.index + 1 : widget.index - 1;
    final switches =
        dx.abs() >= _threshold &&
        dx.abs() > 2 * dy.abs() &&
        target >= 0 &&
        target < widget.count;
    if (!switches) {
      _settleBack();
      return;
    }
    _setProgress(0);
    widget.onChanged(target);
  }

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      behavior: HitTestBehavior.translucent,
      gestures: {
        _HorizontalDominantDragRecognizer:
            GestureRecognizerFactoryWithHandlers<
              _HorizontalDominantDragRecognizer
            >(
              () => _HorizontalDominantDragRecognizer(
                supportedDevices: const {
                  PointerDeviceKind.touch,
                  PointerDeviceKind.stylus,
                  PointerDeviceKind.invertedStylus,
                },
              ),
              (recognizer) => recognizer
                ..dragStartBehavior = DragStartBehavior.down
                ..onStart = _onStart
                ..onUpdate = _onUpdate
                ..onEnd = _onEnd
                ..onCancel = _settleBack,
            ),
      },
      child: Transform.translate(
        offset: Offset(-_progress * _maxShift, 0),
        child: Opacity(
          opacity: 1 - _progress.abs() * (1 - _minOpacity),
          child: widget.child,
        ),
      ),
    );
  }
}

/// 水平位移過了觸控 slop、且明顯大於垂直位移（> 2 倍，約 27° 以內）才搶下手勢。
///
/// 一般的水平拖曳只要水平分量先過 slop 就搶，斜著往上捲清單（27°～45°）會被
/// 它搶走、放開時又不夠水平而不切換，變成兩邊都不動；角度跟切換條件一致後，
/// 這類斜滑會留給垂直捲動。
class _HorizontalDominantDragRecognizer
    extends HorizontalDragGestureRecognizer {
  _HorizontalDominantDragRecognizer({super.supportedDevices});

  Offset _down = Offset.zero;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _down = event.position;
    super.addAllowedPointer(event);
  }

  @override
  bool hasSufficientGlobalDistanceToAccept(
    PointerDeviceKind pointerDeviceKind,
    double? deviceTouchSlop,
  ) {
    if (!super.hasSufficientGlobalDistanceToAccept(
      pointerDeviceKind,
      deviceTouchSlop,
    )) {
      return false;
    }
    final moved = lastPosition.global - _down;
    return moved.dx.abs() > 2 * moved.dy.abs();
  }
}
