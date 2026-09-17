import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../shared/widgets/pill_segmented_toggle.dart';
import '../culture/culture_screen.dart';
import 'learn_screen.dart';

/// 「學習」「影音」「文章」合併分頁：底部導航列只佔一格，內部用膠囊三格切換。
/// 影音/文章原本是文化頁內的第二層 tab，實機回報要點兩次才到文章，故把那一層
/// 併進這裡的膠囊，讓三塊內容都是一次點擊可達。
class LearnCultureScreen extends StatefulWidget {
  final int initialTabIndex; // 0=學習, 1=影音, 2=文章

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
        PillSegmentedItem(label: '學習', subtitle: 'SLHAYAN'),
        PillSegmentedItem(label: '影音', subtitle: 'LNGLUNGAN'),
        PillSegmentedItem(label: '文章', subtitle: 'PATAS KARI'),
      ],
    );
    return Scaffold(
      backgroundColor: _tabIndex == 0
          ? AppColors.creamLight
          : AppColors.midnight,
      // 影音(1)與文章(2)同屬 CultureScreen，只是把子分頁索引往下傳。
      body: IndexedStack(
        index: _tabIndex == 0 ? 0 : 1,
        sizing: StackFit.expand,
        children: [
          LearnScreen(topToggle: toggle),
          CultureScreen(
            topToggle: toggle,
            cultureTabIndex: _tabIndex == 0 ? 0 : _tabIndex - 1,
          ),
        ],
      ),
    );
  }
}
