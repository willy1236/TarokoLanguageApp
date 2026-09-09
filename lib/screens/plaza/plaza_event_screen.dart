import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../events/events_screen.dart';
import 'plaza_screen.dart';

/// 「廣場」與「活動」合併分頁：底部導航列只佔一格，內部用 TabBar 切換兩塊原本
/// 各自獨立的內容（見 lib/main.dart 底部導航列重構計畫）。
/// TODO: 這裡的 AppBar+TabBar 只是暫時的視覺設計，之後要重新設計。
class PlazaEventScreen extends StatefulWidget {
  final int initialTabIndex; // 0=廣場, 1=活動

  const PlazaEventScreen({super.key, this.initialTabIndex = 0});

  @override
  State<PlazaEventScreen> createState() => _PlazaEventScreenState();
}

class _PlazaEventScreenState extends State<PlazaEventScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 2,
    initialIndex: widget.initialTabIndex,
    vsync: this,
  );

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamLight,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        automaticallyImplyLeading: false,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.gold,
          labelColor: AppColors.gold,
          unselectedLabelColor: AppColors.creamLight,
          labelStyle: GoogleFonts.notoSerifTc(
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
          ),
          tabs: const [Tab(text: '廣場'), Tab(text: '活動')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [PlazaScreen(), EventsScreen()],
      ),
    );
  }
}
