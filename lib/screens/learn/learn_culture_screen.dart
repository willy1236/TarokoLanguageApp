import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../shared/widgets/pill_segmented_toggle.dart';
import '../culture/culture_screen.dart';
import 'learn_screen.dart';

/// 「學習」與「影音」合併分頁：底部導航列只佔一格，內部用膠囊切換兩塊原本
/// 各自獨立的內容（見 lib/main.dart 底部導航列重構計畫）。
class LearnCultureScreen extends StatefulWidget {
  final int initialTabIndex; // 0=學習, 1=影音

  const LearnCultureScreen({super.key, this.initialTabIndex = 0});

  @override
  State<LearnCultureScreen> createState() => _LearnCultureScreenState();
}

class _LearnCultureScreenState extends State<LearnCultureScreen> {
  late int _tabIndex = widget.initialTabIndex;

  @override
  Widget build(BuildContext context) {
    final toggle = PillSegmentedToggle(
      index: _tabIndex,
      onChanged: (i) => setState(() => _tabIndex = i),
      backgroundColor: Colors.black.withValues(alpha: 0.2),
      selectedColor: AppColors.gold,
      selectedTextColor: AppColors.ink,
      unselectedTextColor: AppColors.creamLight,
      items: const [
        PillSegmentedItem(label: '族語學習', subtitle: 'SLHAYAN'),
        PillSegmentedItem(label: '文化影音', subtitle: 'LNGLUNGAN'),
      ],
    );
    return Scaffold(
      backgroundColor: _tabIndex == 0 ? AppColors.creamLight : AppColors.midnight,
      body: IndexedStack(
        index: _tabIndex,
        sizing: StackFit.expand,
        children: [
          LearnScreen(topToggle: toggle),
          CultureScreen(topToggle: toggle),
        ],
      ),
    );
  }
}
