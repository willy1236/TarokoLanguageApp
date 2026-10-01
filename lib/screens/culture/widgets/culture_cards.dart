// 文化頁的影片卡、文章卡與分類 chip 列。

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../models/article_models.dart';
import '../../../models/video_models.dart';
import '../../../shared/widgets/article_cover_placeholder.dart';
import '../../../shared/widgets/truku_painters.dart';
import '../video_detail_screen.dart';
import 'culture_icons.dart';

/// 分類 chip 列：影音與文章分頁共用的橫向捲動外框。
class CultureChipsRow extends StatelessWidget {
  final Widget chips;

  const CultureChipsRow({super.key, required this.chips});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: chips,
    );
  }
}

class CultureVideoCard extends StatelessWidget {
  final VideoSummary video;
  final bool seniorMode;
  const CultureVideoCard({
    super.key,
    required this.video,
    this.seniorMode = false,
  });

  static String _formatDuration(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  static String? _badgeText(VideoSummary video) {
    final sec = video.durationSec;
    if (sec != null) return _formatDuration(sec);
    return video.isYoutube ? 'YouTube' : null;
  }

  @override
  Widget build(BuildContext context) {
    // 與文章卡同一種排法：左縮圖、右分類＋標題＋觀看次數、最右箭頭。
    final thumbWidth = seniorMode ? 144.0 : 112.0;
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => VideoDetailScreen(videoId: video.id),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.midnightSoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cream.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            Container(
              width: thumbWidth,
              height: thumbWidth * 9 / 16,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
              child: _thumbnail(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: seniorMode ? 4 : 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      VideoCategory.label(video.category),
                      style: TextStyle(
                        fontSize: AppTypography.size(
                          AppTypography.micro,
                          seniorMode: seniorMode,
                        ),
                        color: AppColors.gold,
                        letterSpacing: 2.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    video.title,
                    maxLines: 1, // 標題固定一行，過長以 … 截斷
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.serif(
                      fontSize: AppTypography.size(
                        AppTypography.body,
                        seniorMode: seniorMode,
                      ),
                      fontWeight: FontWeight.w600,
                      color: AppColors.creamLight,
                      letterSpacing: 0.5,
                      height: 1.35,
                    ),
                  ),
                  // 精簡模式比照文章卡隱藏統計數字，聚焦標題判讀
                  if (!seniorMode) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${video.viewCount} 次觀看',
                      style: const TextStyle(
                        fontSize: AppTypography.micro,
                        color: AppColors.fog,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            CultureArrowIcon(size: seniorMode ? 22 : 16),
          ],
        ),
      ),
    );
  }

  Widget _thumbnail() {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (video.thumbnailUrl != null)
          Image.network(
            video.thumbnailUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _fallbackBackground(),
          )
        else
          _fallbackBackground(),
        Center(
          child: Container(
            width: seniorMode ? 32 : 26,
            height: seniorMode ? 32 : 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.5),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
            ),
            child: Center(
              child: CulturePlayIcon(
                size: seniorMode ? 12 : 9,
                color: AppColors.gold,
              ),
            ),
          ),
        ),
        // YouTube 影片沒有長度（duration_sec 為 null）時改標來源；
        // 其他沒長度的影片直接不顯示，不要顯示成 0:00。
        if (_badgeText(video) case final badge?)
          Positioned(
            bottom: 4,
            right: 4,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: seniorMode ? 6 : 4,
                vertical: seniorMode ? 2 : 1,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                badge,
                style: AppTypography.mono(
                  fontSize: AppTypography.size(
                    AppTypography.micro,
                    seniorMode: seniorMode,
                  ),
                  color: AppColors.creamLight,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _fallbackBackground() {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.moss, AppColors.mossDeep],
            ),
          ),
        ),
        CustomPaint(
          painter: TrukuWeavePainter(
            color: AppColors.gold,
            opacity: 0.3,
            scale: 0.5,
          ),
        ),
      ],
    );
  }
}

class CultureArticleCard extends StatelessWidget {
  final ArticleSummary item;
  final VoidCallback onTap;
  final bool seniorMode;
  const CultureArticleCard({
    super.key,
    required this.item,
    required this.onTap,
    this.seniorMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final thumbSize = seniorMode ? 84.0 : 64.0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.midnightSoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cream.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            Container(
              width: thumbSize,
              height: thumbSize,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
              child: item.coverImageUrl != null
                  ? Image.network(
                      item.coverImageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          ArticleCoverPlaceholder(category: item.category),
                    )
                  : ArticleCoverPlaceholder(category: item.category),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: seniorMode ? 4 : 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      ArticleCategory.label(item.category),
                      style: TextStyle(
                        fontSize: AppTypography.size(
                          AppTypography.micro,
                          seniorMode: seniorMode,
                        ),
                        color: AppColors.gold,
                        letterSpacing: 2.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.title,
                    style: AppTypography.serif(
                      fontSize: AppTypography.size(
                        AppTypography.body,
                        seniorMode: seniorMode,
                      ),
                      fontWeight: FontWeight.w600,
                      color: AppColors.creamLight,
                      letterSpacing: 0.5,
                      height: 1.35,
                    ),
                    maxLines: 1, // 與影音卡一致：標題固定一行
                    overflow: TextOverflow.ellipsis,
                  ),
                  // 精簡模式下隱藏閱讀/本週統計數字，密度砍除聚焦標題判讀
                  if (!seniorMode) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${item.viewCount} 閱讀 · 本週 ${item.weeklyViewCount}',
                      style: TextStyle(
                        fontSize: AppTypography.micro,
                        color: AppColors.fog,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            CultureArrowIcon(size: seniorMode ? 22 : 16),
          ],
        ),
      ),
    );
  }
}
