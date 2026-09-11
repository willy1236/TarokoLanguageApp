import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../shared/widgets/pill_segmented_toggle.dart';
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

  @override
  Widget build(BuildContext context) {
    final toggle = PillSegmentedToggle(
      index: _tabIndex,
      onChanged: (i) => setState(() => _tabIndex = i),
      items: const [
        PillSegmentedItem(label: '動態', subtitle: 'PATAS'),
        PillSegmentedItem(label: '活動', subtitle: 'SMRATUC'),
      ],
    );
    return Scaffold(
      backgroundColor: AppColors.creamLight,
      body: IndexedStack(
        index: _tabIndex,
        sizing: StackFit.expand,
        children: [
          PlazaScreen(topToggle: toggle),
          EventsScreen(topToggle: toggle),
        ],
      ),
    );
  }
}
