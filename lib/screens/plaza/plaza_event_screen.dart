import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../shared/widgets/pill_segmented_toggle.dart';
import '../../shared/widgets/swipe_segment_switcher.dart';
import '../events/events_screen.dart';
import 'plaza_screen.dart';

/// 「廣場」與「活動」合併分頁：底部導航列只佔一格，內部用膠囊切換兩塊原本
/// 各自獨立的內容（見 lib/main.dart 底部導航列重構計畫）。
class PlazaEventScreen extends StatefulWidget {
  final int initialTabIndex; // 0=廣場, 1=活動

  const PlazaEventScreen({super.key, this.initialTabIndex = 0});

  @override
  State<PlazaEventScreen> createState() => _PlazaEventScreenState();
}

class _PlazaEventScreenState extends State<PlazaEventScreen> {
  late int _tabIndex = widget.initialTabIndex;

  // 左右滑動進度只給膠囊預移色塊用，不經 setState，免得每一幀重建整頁內容。
  final _dragProgress = ValueNotifier<double>(0);

  @override
  void dispose() {
    _dragProgress.dispose();
    super.dispose();
  }

  void _select(int index) => setState(() => _tabIndex = index);

  @override
  Widget build(BuildContext context) {
    final toggle = ValueListenableBuilder<double>(
      valueListenable: _dragProgress,
      builder: (context, dragProgress, _) => PillSegmentedToggle(
        index: _tabIndex,
        onChanged: _select,
        dragProgress: dragProgress,
        items: const [
          PillSegmentedItem(label: '動態', subtitle: 'PATAS'),
          PillSegmentedItem(label: '活動', subtitle: 'SMRATUC'),
        ],
      ),
    );
    return Scaffold(
      backgroundColor: AppColors.creamLight,
      body: SwipeSegmentSwitcher(
        index: _tabIndex,
        count: 2,
        onChanged: _select,
        onDragProgress: (p) => _dragProgress.value = p,
        child: IndexedStack(
          index: _tabIndex,
          sizing: StackFit.expand,
          children: [
            PlazaScreen(topToggle: toggle),
            EventsScreen(topToggle: toggle),
          ],
        ),
      ),
    );
  }
}
