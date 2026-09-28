import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/date_format.dart';
import '../../../models/event_model.dart';

/// 個人頁活動清單（我發起的、我參加的）的一列：日期、標題、參加人數與狀態標籤。
class EventStatusTile extends StatelessWidget {
  final EventSummary event;
  final bool seniorMode;
  final VoidCallback onTap;

  /// 尚未開始時的狀態標籤文字。
  final String upcomingLabel;

  /// 自己發起的活動在標題下標「我發起的」。
  final bool showHostBadge;

  const EventStatusTile({
    super.key,
    required this.event,
    required this.seniorMode,
    required this.onTap,
    this.upcomingLabel = '即將舉行',
    this.showHostBadge = false,
  });

  ({String text, Color color}) _statusChip() {
    switch (event.displayStatus) {
      case 'cancelled':
        return (text: '已取消', color: AppColors.dangerDark);
      case 'ended':
        return (text: '已結束', color: AppColors.fog);
      case 'ongoing':
        return (text: '進行中', color: AppColors.mossDeep);
      default:
        return (text: upcomingLabel, color: AppColors.primary);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = event;
    final d = e.startsAt.toLocal();
    final chip = _statusChip();
    String two(int n) => n.toString().padLeft(2, '0');
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(seniorMode ? 18 : 14),
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.creamDeep),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: seniorMode ? 76 : 52,
              child: Column(
                children: [
                  Text(
                    monthLabel(d),
                    style: TextStyle(
                      fontSize: AppTypography.size(
                        AppTypography.micro,
                        seniorMode: seniorMode,
                      ),
                      color: AppColors.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    two(d.day),
                    style: AppTypography.serif(
                      fontSize: AppTypography.size(
                        AppTypography.headline,
                        seniorMode: seniorMode,
                      ),
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleStyle(
                      seniorMode: seniorMode,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: seniorMode ? 18 : 12,
                            color: AppColors.inkSoft,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${e.participantCount} 人參加',
                            style: TextStyle(
                              fontSize: AppTypography.size(
                                AppTypography.caption,
                                seniorMode: seniorMode,
                              ),
                              color: AppColors.inkSoft,
                            ),
                          ),
                        ],
                      ),
                      if (showHostBadge)
                        Text(
                          '我發起的',
                          style: AppTypography.bodyStyle(
                            seniorMode: seniorMode,
                            color: AppColors.goldDeep,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: seniorMode ? 10 : 8,
                vertical: seniorMode ? 6 : 4,
              ),
              decoration: BoxDecoration(
                color: chip.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                chip.text,
                style: TextStyle(
                  fontSize: AppTypography.size(
                    AppTypography.caption,
                    seniorMode: seniorMode,
                  ),
                  color: chip.color,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
