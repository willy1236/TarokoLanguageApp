import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../shared/widgets/pill_segmented_toggle.dart';
import '../community/community_screen.dart';
import 'profile_screen.dart';

/// 「個人資料」與「視訊配對」合併分頁：底部導航列只佔一格，內部用膠囊切換
/// 兩塊原本各自獨立的內容（同 PlazaEventScreen 的作法）。
class ProfileVideoScreen extends StatefulWidget {
  final int initialTabIndex; // 0=個人資料, 1=視訊配對

  const ProfileVideoScreen({super.key, this.initialTabIndex = 0});

  @override
  State<ProfileVideoScreen> createState() => _ProfileVideoScreenState();
}

class _ProfileVideoScreenState extends State<ProfileVideoScreen> {
  late int _tabIndex = widget.initialTabIndex;

  @override
  Widget build(BuildContext context) {
    final toggle = PillSegmentedToggle(
      index: _tabIndex,
      onChanged: (i) => setState(() => _tabIndex = i),
      items: const [
        PillSegmentedItem(label: '個人資料', subtitle: 'PSPUNG'),
        PillSegmentedItem(label: '視訊配對', subtitle: 'PGKALA'),
      ],
    );
    return Scaffold(
      backgroundColor: AppColors.creamLight,
      body: IndexedStack(
        index: _tabIndex,
        sizing: StackFit.expand,
        children: [
          ProfileScreen(topToggle: toggle),
          CommunityScreen(topToggle: toggle),
        ],
      ),
    );
  }
}
