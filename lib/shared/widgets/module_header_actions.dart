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
                  right: -3,
                  top: -3,
                  child: _UnreadDot(seniorMode: seniorMode),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 鈴鐺右上的未讀點。比照底部分頁徽章：酒紅底加米白外框，外框把圓點跟
/// 鈴鐺輪廓隔開；原本 8px 純酒紅點貼著深色鈴鐺，在米白頁首上幾乎看不出來。
class _UnreadDot extends StatelessWidget {
  final bool seniorMode;

  const _UnreadDot({required this.seniorMode});

  @override
  Widget build(BuildContext context) {
    final size = seniorMode ? 14.0 : 12.0;
    return Container(
      key: const ValueKey('module-unread-dot'),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.creamLight, width: 1.5),
      ),
    );
  }
}
