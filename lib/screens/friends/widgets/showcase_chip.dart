// 羈絆展示同意狀態的可點擊 chip，三態：未同意/等待對方同意/雙方已顯示。

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../models/friend_model.dart';

class ShowcaseChip extends StatelessWidget {
  final Showcase showcase;
  final bool seniorMode;
  final VoidCallback onTap;

  const ShowcaseChip({
    super.key,
    required this.showcase,
    required this.onTap,
    this.seniorMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final String label;
    final Color color;
    if (showcase.mutual) {
      label = '雙方已顯示';
      color = AppColors.primary;
    } else if (showcase.mine) {
      label = '等待對方同意';
      color = AppColors.fog;
    } else {
      label = '顯示在檔案上';
      color = AppColors.fog;
    }
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(
          label,
          style: AppTypography.captionStyle(seniorMode: seniorMode, color: color),
        ),
      ),
    );
  }
}
