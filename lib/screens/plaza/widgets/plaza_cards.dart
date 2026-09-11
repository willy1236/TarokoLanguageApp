// 廣場頁的小元件：活動訊息卡、看板 Tab、近期活動小卡。

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/date_format.dart';
import '../../../models/event_model.dart';
import '../../../shared/widgets/truku_widgets.dart';

class PlazaEventMessageCard extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const PlazaEventMessageCard({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      color: AppColors.cream,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.creamDeep),
    ),
    child: Row(
      children: [
        Icon(icon, size: 18, color: AppColors.fog),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: GoogleFonts.notoSerifTc(
              fontSize: AppTypography.body,
              color: AppColors.fog,
              letterSpacing: 0.8,
            ),
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    ),
  );
}

// ── 看板 Tab 元件 ──────────────────────────────────────────────

class PlazaBoardTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// 精簡模式：字級放大、上下留白加大，讓 tab 熱區至少 48 高。
  final bool seniorMode;

  const PlazaBoardTab({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.seniorMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.fog;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: seniorMode ? 10 : 6),
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(vertical: seniorMode ? 14 : 10),
              child: Text(
                label,
                style: GoogleFonts.notoSerifTc(
                  fontSize: AppTypography.size(AppTypography.body, seniorMode: seniorMode),
                  fontWeight: FontWeight.w600,
                  color: color,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            if (selected)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(height: 2, color: AppColors.primary),
              ),
          ],
        ),
      ),
    );
  }
}

// ── 近期活動小卡 ─────────────────────────────────────────────

class PlazaMiniEventCard extends StatelessWidget {
  final EventSummary event;
  final VoidCallback onTap;

  const PlazaMiniEventCard({
    super.key,
    required this.event,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final d = event.startsAt.toLocal();
    final month = monthLabel(d);
    final day = d.day.toString().padLeft(2, '0');
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -16,
              top: -16,
              child: Opacity(
                opacity: 0.13,
                child: TrukuDiamond(size: 80, color: AppColors.gold),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: event.isJoined
                            ? AppColors.primary
                            : AppColors.moss,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            month,
                            style: const TextStyle(
                              fontSize: AppTypography.micro,
                              color: AppColors.gold,
                              letterSpacing: 0.3,
                            ),
                          ),
                          Text(
                            day,
                            style: GoogleFonts.notoSerifTc(
                              fontSize: AppTypography.subtitle,
                              fontWeight: FontWeight.w700,
                              color: AppColors.creamLight,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.notoSerifTc(
                              fontSize: AppTypography.body,
                              fontWeight: FontWeight.w600,
                              color: AppColors.creamLight,
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            event.location ?? '線上',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: AppTypography.micro,
                              color: AppColors.creamLight.withValues(
                                alpha: 0.65,
                              ),
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '● ${event.participantCount} 人報名',
                      style: const TextStyle(
                        fontSize: AppTypography.micro,
                        color: AppColors.gold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.5),
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        event.isJoined ? '已報名' : '我要參加',
                        style: const TextStyle(
                          fontSize: AppTypography.caption,
                          color: AppColors.gold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
