// 羈絆等級徽章。六級名稱與後端 bond_level.name 一致：初識/相識/語伴/摯友/知己/一世之交。

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';

class BondLevelBadge extends StatelessWidget {
  final int level;
  final String name;
  final bool seniorMode;

  const BondLevelBadge({
    super.key,
    required this.level,
    required this.name,
    this.seniorMode = false,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    decoration: BoxDecoration(
      color: AppColors.gold.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
    ),
    child: Text(
      '羈絆 · $name',
      style: AppTypography.subtitleStyle(seniorMode: seniorMode, color: AppColors.goldDeep),
    ),
  );
}
