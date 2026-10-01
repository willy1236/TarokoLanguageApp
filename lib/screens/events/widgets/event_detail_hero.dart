// 活動詳情頁頂部：有圖片時是照片輪播，沒有時是漸層背景；上面疊返回鈕、分類標籤、
// 日期與標題。發起人在這裡直接新增、刪除活動圖片。

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_format.dart';
import '../../../models/event_model.dart';
import '../../../shared/widgets/truku_painters.dart';
import '../../../core/constants/app_typography.dart';
import '../../../shared/widgets/app_back_button.dart';
import 'event_image_carousel.dart';

class EventDetailHero extends StatelessWidget {
  final EventDetail event;
  final bool seniorMode;

  /// 發起人上傳或刪除圖片成功後，後端回的該活動全部圖片。
  final ValueChanged<List<EventImage>> onImagesChanged;

  const EventDetailHero({
    super.key,
    required this.event,
    required this.seniorMode,
    required this.onImagesChanged,
  });

  @override
  Widget build(BuildContext context) {
    final e = event;
    final hasImages = e.images.isNotEmpty;
    final cancelled = e.displayStatus == 'cancelled';
    final ended = e.displayStatus == 'ended';
    return SizedBox(
      // 照片用 210 太扁，有圖時拉高；沒圖時維持原本的高度。
      height: hasImages ? 280 : 210,
      child: EventImageCarousel(
        eventId: e.id,
        images: e.images,
        canEdit: e.isHost,
        seniorMode: seniorMode,
        background: _GradientBackground(muted: cancelled || ended),
        onImagesChanged: onImagesChanged,
        overlayBuilder: (context, controls) => Stack(
          fit: StackFit.expand,
          children: [
            if (hasImages) const IgnorePointer(child: _PhotoScrim()),
            // 返回鈕
            Positioned(
              top: 52,
              left: 16,
              child: const AppBackButton(onDark: true),
            ),
            // 頁數指示、發起人按鈕與分類標籤（分類可能沒有）
            Positioned(
              top: 58,
              left: 72,
              right: 16,
              child: Align(
                alignment: Alignment.topRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(child: controls),
                    if (e.category != null && e.category!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Flexible(child: _buildCategory(e.category!)),
                    ],
                  ],
                ),
              ),
            ),
            // 日期 + 標題；不接手勢，左右滑才會落到底下的輪播。
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: IgnorePointer(
                child: _buildTitleBlock(e, cancelled: cancelled, ended: ended),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategory(String category) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: AppColors.gold,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      category,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: AppTypography.size(
          AppTypography.micro,
          seniorMode: seniorMode,
        ),
        color: AppColors.ink,
        fontWeight: FontWeight.w600,
        letterSpacing: 2.5,
      ),
    ),
  );

  Widget _buildTitleBlock(
    EventDetail e, {
    required bool cancelled,
    required bool ended,
  }) {
    final start = e.startsAt.toLocal();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (cancelled || ended)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.ink.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                cancelled ? '已取消' : '已結束',
                style: TextStyle(
                  fontSize: AppTypography.size(
                    AppTypography.caption,
                    seniorMode: seniorMode,
                  ),
                  color: AppColors.creamLight,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
        Text(
          '${monthLabel(start)}${start.day}日 · ${weekdayLabel(start)}',
          style: AppTypography.serif(
            fontStyle: FontStyle.italic,
            fontSize: AppTypography.size(
              AppTypography.body,
              seniorMode: seniorMode,
            ),
            color: AppColors.gold,
            letterSpacing: 2.0,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          e.title,
          style: AppTypography.serif(
            fontSize: seniorMode
                ? AppTypography.display32
                : AppTypography.display26,
            fontWeight: FontWeight.w700,
            color: AppColors.creamLight,
            letterSpacing: 0.8,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

/// 沒有照片時的主視覺；已取消、已結束改灰色。
class _GradientBackground extends StatelessWidget {
  final bool muted;
  const _GradientBackground({required this.muted});

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: muted
                ? const [AppColors.fog, AppColors.inkSoft]
                : const [AppColors.primary, AppColors.primaryDeep],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      Opacity(
        opacity: 0.22,
        child: CustomPaint(painter: TrukuWeavePainter(opacity: 1, scale: 0.8)),
      ),
    ],
  );
}

/// 照片上的遮罩：上緣微暗襯返回鈕與按鈕，下半部漸暗襯日期與標題，亮色照片也讀得清楚。
class _PhotoScrim extends StatelessWidget {
  const _PhotoScrim();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.ink.withValues(alpha: 0.5),
          AppColors.ink.withValues(alpha: 0),
          AppColors.ink.withValues(alpha: 0),
          AppColors.ink.withValues(alpha: 0.8),
        ],
        stops: const [0, 0.3, 0.4, 1],
      ),
    ),
  );
}
