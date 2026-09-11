// 活動詳情頁頂部：漸層背景、返回鈕、分類標籤、日期與標題。

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_format.dart';
import '../../../models/event_model.dart';
import '../../../shared/widgets/truku_painters.dart';

class EventDetailHero extends StatelessWidget {
  final EventDetail event;
  final bool seniorMode;

  const EventDetailHero({
    super.key,
    required this.event,
    required this.seniorMode,
  });

  @override
  Widget build(BuildContext context) => _buildHero(context, event, seniorMode);

  Widget _buildHero(BuildContext context, EventDetail e, bool seniorMode) {
    final start = e.startsAt.toLocal();
    final cancelled = e.displayStatus == 'cancelled';
    final ended = e.displayStatus == 'ended';
    final gradient = cancelled || ended
        ? const [AppColors.fog, AppColors.inkSoft]
        : const [AppColors.primary, AppColors.primaryDeep];
    return SizedBox(
      height: 210,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Opacity(
            opacity: 0.22,
            child: CustomPaint(
              painter: TrukuWeavePainter(opacity: 1, scale: 0.8),
            ),
          ),
          // 返回鈕
          Positioned(
            top: 52,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: seniorMode ? 50 : 38,
                height: seniorMode ? 50 : 38,
                decoration: BoxDecoration(
                  color: AppColors.ink.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.creamLight.withValues(alpha: 0.25),
                  ),
                ),
                child: Icon(
                  Icons.arrow_back,
                  color: AppColors.creamLight,
                  size: seniorMode ? 26 : 18,
                ),
              ),
            ),
          ),
          // 標籤（分類，可能沒有）
          if (e.category != null && e.category!.isNotEmpty)
            Positioned(
              top: 58,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  e.category!,
                  style: TextStyle(
                    fontSize: seniorMode ? 14 : 10,
                    color: AppColors.ink,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2.5,
                  ),
                ),
              ),
            ),
          // 日期 + 標題
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (cancelled || ended)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.ink.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        cancelled ? '已取消' : '已結束',
                        style: TextStyle(
                          fontSize: seniorMode ? 15 : 11,
                          color: AppColors.creamLight,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),
                Text(
                  '${monthLabel(start)}${start.day}日 · ${weekdayLabel(start)}',
                  style: GoogleFonts.notoSerifTc(
                    fontStyle: FontStyle.italic,
                    fontSize: seniorMode ? 17 : 13,
                    color: AppColors.gold,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  e.title,
                  style: GoogleFonts.notoSerifTc(
                    fontSize: seniorMode ? 32 : 26,
                    fontWeight: FontWeight.w700,
                    color: AppColors.creamLight,
                    letterSpacing: 0.8,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
