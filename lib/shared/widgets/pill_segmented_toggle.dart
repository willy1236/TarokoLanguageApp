import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../services/senior_mode_controller.dart';

/// 膠囊分段切換的單一選項：中文主標題 + 英文/羅馬拼音副標題。
class PillSegmentedItem {
  final String label;
  final String subtitle;

  const PillSegmentedItem({required this.label, required this.subtitle});
}

/// 兩段式膠囊切換元件——取代各畫面各自手刻的 TabBar/自製切換，統一視覺：
/// 未選中為透明底，選中的那一半用實心圓角色塊蓋住並套用選中色。
class PillSegmentedToggle extends StatelessWidget {
  final List<PillSegmentedItem> items;
  final int index;
  final ValueChanged<int> onChanged;
  final Color backgroundColor;
  final Color selectedColor;
  final Color selectedTextColor;
  final Color unselectedTextColor;

  const PillSegmentedToggle({
    super.key,
    required this.items,
    required this.index,
    required this.onChanged,
    this.backgroundColor = AppColors.cream,
    this.selectedColor = AppColors.primary,
    this.selectedTextColor = AppColors.creamLight,
    this.unselectedTextColor = AppColors.inkSoft,
  }) : assert(items.length == 2);

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: seniorModeController,
    builder: (context, _) => _buildToggle(seniorModeController.enabled),
  );

  Widget _buildToggle(bool seniorMode) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(child: _segment(i, seniorMode)),
        ],
      ),
    );
  }

  // 精簡模式：主標放大、隱藏羅馬拼音副標（資訊密度收斂），熱區至少 56 高。
  Widget _segment(int i, bool seniorMode) {
    final selected = i == index;
    final item = items[i];
    final textColor = selected ? selectedTextColor : unselectedTextColor;
    return GestureDetector(
      onTap: () => onChanged(i),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        constraints: BoxConstraints(minHeight: seniorMode ? 56 : 0),
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(vertical: seniorMode ? 12 : 14),
        decoration: BoxDecoration(
          color: selected ? selectedColor : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              item.label,
              style: GoogleFonts.notoSerifTc(
                fontSize: AppTypography.size(AppTypography.subtitle, seniorMode: seniorMode),
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            if (!seniorMode) ...[
              const SizedBox(height: 2),
              Text(
                item.subtitle,
                style: GoogleFonts.crimsonPro(
                  fontSize: AppTypography.caption,
                  fontStyle: FontStyle.italic,
                  letterSpacing: 1.5,
                  color: textColor.withValues(alpha: selected ? 0.85 : 0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
