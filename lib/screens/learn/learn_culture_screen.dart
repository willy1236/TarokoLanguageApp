import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../shared/widgets/pill_segmented_toggle.dart';
import '../../shared/widgets/truku_painters.dart';
import '../culture/culture_screen.dart';
import 'learn_screen.dart';

/// 「學習」「影音」「文章」合併分頁：底部導航列只佔一格，內部用膠囊三格切換。
/// 影音/文章原本是文化頁內的第二層 tab，實機回報要點兩次才到文章，故把那一層
/// 併進這裡的膠囊，讓三塊內容都是一次點擊可達。
///
/// 膠囊固定在頂部、不跟內容捲動：原本各分頁把膠囊放在高度不同的 hero 下方，
/// 切換時膠囊會上下跳，組員回報看了不舒服。
class LearnCultureScreen extends StatefulWidget {
  final int initialTabIndex; // 0=學習, 1=影音, 2=文章

  /// 使用者再次點擊底部「學習影音」時觸發，由目前分頁捲回頂部並重新整理。
  final Listenable? reselectSignal;

  const LearnCultureScreen({
    super.key,
    this.initialTabIndex = 0,
    this.reselectSignal,
  });

  @override
  State<LearnCultureScreen> createState() => _LearnCultureScreenState();
}

class _LearnCultureScreenState extends State<LearnCultureScreen> {
  late int _tabIndex = widget.initialTabIndex;

  @override
  Widget build(BuildContext context) {
    final isLearn = _tabIndex == 0;
    return Scaffold(
      backgroundColor: isLearn ? AppColors.creamLight : AppColors.midnight,
      body: Column(
        children: [
          _buildHeader(isLearn),
          Expanded(
            // 影音(1)與文章(2)同屬 CultureScreen，只是把子分頁索引往下傳。
            child: IndexedStack(
              index: isLearn ? 0 : 1,
              sizing: StackFit.expand,
              children: [
                LearnScreen(
                  reselectSignal: isLearn ? widget.reselectSignal : null,
                ),
                CultureScreen(
                  cultureTabIndex: isLearn ? 0 : _tabIndex - 1,
                  reselectSignal: isLearn ? null : widget.reselectSignal,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 底色跟著分頁走（學習紅、文化深色），膠囊本身的位置與大小三頁完全一致。
  Widget _buildHeader(bool isLearn) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      color: isLearn ? AppColors.primary : AppColors.midnight,
      child: Stack(
        children: [
          if (isLearn)
            Positioned.fill(
              child: Opacity(
                opacity: 0.2,
                child: CustomPaint(
                  painter: TrukuWeavePainter(
                    color: AppColors.gold,
                    opacity: 1.0,
                    scale: 0.7,
                  ),
                ),
              ),
            ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: PillSegmentedToggle(
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
              ),
            ),
          ),
        ],
      ),
    );
  }
}
