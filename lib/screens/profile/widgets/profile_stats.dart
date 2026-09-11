// 個人頁小米幣橫幅與學習統計列。

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../models/user_model.dart';
import '../../../shared/widgets/millet_coin_icon.dart';
import 'profile_rows.dart';

class ProfileCoinBanner extends StatelessWidget {
  final UserModel? user;
  final VoidCallback onTap;

  const ProfileCoinBanner({super.key, required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) => _buildCoinBanner();

  Widget _buildCoinBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.creamDeep),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.gold.withValues(alpha: 0.2),
              ),
              child: const MilletCoinIcon(size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${user?.millet ?? 0}',
                    style: AppTypography.headlineStyle(
                      color: AppColors.primary,
                    ),
                  ),
                  Text(
                    '小米 · 每日登入／完成單元可得',
                    style: AppTypography.captionStyle(color: AppColors.fog),
                  ),
                ],
              ),
            ),
            OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: const Text('明細'),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileStatsRow extends StatelessWidget {
  final UserModel? user;
  final bool seniorMode;

  const ProfileStatsRow({
    super.key,
    required this.user,
    required this.seniorMode,
  });

  @override
  Widget build(BuildContext context) => _buildStatsRow(seniorMode: seniorMode);

  Widget _buildStatsRow({required bool seniorMode}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.creamDeep),
        ),
        child: Row(
          children: [
            profileStatCell(seniorMode, '${user?.studyStreak ?? 0}', '連續學習'),
            profileStatDivider(),
            profileStatCell(seniorMode, '${user?.videoCallCount ?? 0}', '通話次數'),
            profileStatDivider(),
            profileStatCell(seniorMode, '${user?.forumPostCount ?? 0}', '發文'),
          ],
        ),
      ),
    );
  }
}
