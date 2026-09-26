// 活動、廣場等模組頁首右側共用的「＋發起／發布」膠囊鈕與
// 搜尋／通知兩顆圖示（通知有未讀時帶紅點）。

import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_icon_size.dart';
import '../../core/constants/app_typography.dart';

class ModuleComposeButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  /// false 時半透明且不可點（例如沒有發起權限）。
  final bool enabled;
  final bool seniorMode;

  const ModuleComposeButton({
    super.key,
    required this.label,
    required this.onTap,
    this.enabled = true,
    required this.seniorMode,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.4,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: seniorMode ? 20 : 16,
            vertical: seniorMode ? 14 : 10,
          ),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add,
                color: AppColors.creamLight,
                size: AppIconSize.inline(seniorMode),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTypography.serif(
                  fontSize: AppTypography.size(
                    AppTypography.body,
                    seniorMode: seniorMode,
                  ),
                  fontWeight: FontWeight.w600,
                  color: AppColors.creamLight,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 頁首次要入口：搜尋 + 通知。
/// 原本還有一顆「我的收藏」，但三顆擠在標題同一列會壓縮標題寬度，
/// 收藏改由各模組自己的入口進入，這裡只留最常用的兩顆並放大熱區。
class ModuleActionIcons extends StatelessWidget {
  final VoidCallback onSearch;
  final String notificationsTooltip;
  final VoidCallback onNotifications;
  final bool hasUnread;
  final bool seniorMode;

  const ModuleActionIcons({
    super.key,
    required this.onSearch,
    required this.notificationsTooltip,
    required this.onNotifications,
    required this.hasUnread,
    required this.seniorMode,
  });

  @override
  Widget build(BuildContext context) {
    final size = AppIconSize.action(seniorMode);
    const constraints = BoxConstraints.tightFor(
      width: AppIconSize.tapTarget,
      height: AppIconSize.tapTarget,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: '搜尋',
          padding: EdgeInsets.zero,
          constraints: constraints,
          onPressed: onSearch,
          icon: Icon(Icons.search, color: AppColors.ink, size: size),
        ),
        IconButton(
          tooltip: notificationsTooltip,
          padding: EdgeInsets.zero,
          constraints: constraints,
          onPressed: onNotifications,
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(Icons.notifications_none, color: AppColors.ink, size: size),
              if (hasUnread)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
