import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import 'pressable.dart';

/// App 唯一的篩選／分類選擇元件：選中是 ink 實心底，未選中是 creamDeep 外框。
///
/// 活動分類、商店分類、紀錄篩選、廣場看板、論壇搜尋看板、後台狀態篩選都用它，
/// 不再各畫各的（文字 tab、Material ChoiceChip、不同顏色的 pill）。
/// 排列方式由呼叫端決定（橫向捲動列用 [FilterPillRow]，換行用 Wrap）。
class FilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool seniorMode;

  const FilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.seniorMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      selected: selected,
      child: Container(
        // 觸控高度：一般模式 40、精簡模式 48。
        constraints: BoxConstraints(minHeight: seniorMode ? 48 : 40),
        padding: EdgeInsets.symmetric(horizontal: seniorMode ? 18 : 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: selected ? null : Border.all(color: AppColors.creamDeep),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.captionStyle(
                  seniorMode: seniorMode,
                  color: selected ? AppColors.creamLight : AppColors.inkSoft,
                ).copyWith(letterSpacing: 1.0),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 橫向可捲動的 [FilterPill] 列。
class FilterPillRow extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool seniorMode;
  final EdgeInsetsGeometry padding;

  const FilterPillRow({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    this.seniorMode = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: seniorMode ? 48 : 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: labels.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => FilterPill(
          label: labels[i],
          selected: i == selectedIndex,
          seniorMode: seniorMode,
          onTap: () => onSelected(i),
        ),
      ),
    );
  }
}
