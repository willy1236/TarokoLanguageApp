import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../culture/culture_screen.dart';
import 'learn_screen.dart';

/// 「學習」與「影音」合併分頁：底部導航列只佔一格，內部用 TabBar 切換兩塊原本
/// 各自獨立的內容（見 lib/main.dart 底部導航列重構計畫）。
/// TODO: 這裡的 AppBar+TabBar 只是暫時的視覺設計，之後要重新設計。
class LearnCultureScreen extends StatefulWidget {
  final int initialTabIndex; // 0=學習, 1=影音

  const LearnCultureScreen({super.key, this.initialTabIndex = 0});

  @override
  State<LearnCultureScreen> createState() => _LearnCultureScreenState();
}

class _LearnCultureScreenState extends State<LearnCultureScreen>
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
          tabs: const [Tab(text: '學習'), Tab(text: '影音')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [LearnScreen(), CultureScreen()],
      ),
    );
  }
}
