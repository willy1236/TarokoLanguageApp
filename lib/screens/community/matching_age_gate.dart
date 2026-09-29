// 隨機配對的年齡限制（POL-01）：未滿 18 歲不得配對、只能跟好友視訊；
// 沒填生日的人後端回 BIRTH_DATE_REQUIRED，導去補填頁。
// 配對入口（community_screen）與等待畫面離開後共用。

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/network/api_client.dart';
import '../../services/senior_mode_controller.dart';
import '../friends/friends_list_screen.dart';

/// 配對被年齡限制擋下時處理並回 true；其他錯誤回 false 交給呼叫端。
bool handleMatchingAgeError(BuildContext context, ApiException e) {
  if (e.isUnderage) {
    showUnderageSheet(context);
    return true;
  }
  if (e.isBirthDateRequired) {
    Navigator.of(context).pushNamedAndRemoveUntil('/birth-date', (_) => false);
    return true;
  }
  return false;
}

/// 未滿 18 歲的說明底板，提供前往好友列表。
Future<void> showUnderageSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.creamLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) => ListenableBuilder(
        listenable: seniorModeController,
        builder: (_, _) => _UnderageSheet(
          seniorMode: seniorModeController.enabled,
          onOpenFriends: () {
            Navigator.pop(sheetContext);
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FriendsListScreen()),
            );
          },
        ),
      ),
    );

class _UnderageSheet extends StatelessWidget {
  final bool seniorMode;
  final VoidCallback onOpenFriends;

  const _UnderageSheet({required this.seniorMode, required this.onOpenFriends});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '隨機配對限 18 歲以上',
              style: AppTypography.subtitleStyle(
                seniorMode: seniorMode,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '未滿 18 歲無法使用隨機配對，可以與好友視訊',
              style: AppTypography.bodyStyle(
                seniorMode: seniorMode,
                color: AppColors.inkSoft,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: seniorMode ? 56 : 48,
              child: ElevatedButton(
                onPressed: onOpenFriends,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.creamLight,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  '前往好友列表',
                  style: AppTypography.bodyStyle(
                    seniorMode: seniorMode,
                    color: AppColors.creamLight,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                '知道了',
                style: AppTypography.bodyStyle(
                  seniorMode: seniorMode,
                  color: AppColors.fog,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
