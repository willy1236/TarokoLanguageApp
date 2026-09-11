// 文化頁的影片卡、文章卡與 hero 播放鈕。

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../models/article_models.dart';
import '../../../models/video_models.dart';
import '../../../shared/widgets/article_cover_placeholder.dart';
import '../../../shared/widgets/truku_painters.dart';
import '../video_detail_screen.dart';
import 'culture_icons.dart';

class CulturePlayButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool seniorMode;
  const CulturePlayButton({
    super.key,
    required this.label,
    this.onTap,
    this.seniorMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: seniorMode ? 26 : 20,
          vertical: seniorMode ? 14 : 10,
        ),
        decoration: BoxDecoration(
          color: AppColors.gold,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CulturePlayIcon(size: seniorMode ? 16 : 12, color: AppColors.ink),
            const SizedBox(width: 10),
            Text(
              label,
              style: GoogleFonts.notoSerifTc(
                fontSize: AppTypography.size(AppTypography.body, seniorMode: seniorMode),
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
                letterSpacing: 2.4,
              ),
            ),
          ],
        ),
      ),
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

  static String _formatDuration(int? sec) {
    if (sec == null) return '--:--';
    final m = sec ~/ 60;
    final s = sec % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => VideoDetailScreen(videoId: video.id),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.midnightSoft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cream.withValues(alpha: 0.06)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: seniorMode ? 180 : 100,
              child: Stack(
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
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: seniorMode ? 5 : 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        VideoCategory.label(video.category),
                        style: TextStyle(
                          fontSize: AppTypography.size(AppTypography.micro, seniorMode: seniorMode),
                          color: AppColors.gold,
                          letterSpacing: 2.4,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: seniorMode ? 8 : 6,
                        vertical: seniorMode ? 3 : 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        _formatDuration(video.durationSec),
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: AppTypography.size(AppTypography.micro, seniorMode: seniorMode),
                          color: AppColors.creamLight,
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Container(
                      width: seniorMode ? 52 : 36,
                      height: seniorMode ? 52 : 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.5),
                        border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Center(
                        child: CulturePlayIcon(
                          size: seniorMode ? 18 : 12,
                          color: AppColors.gold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    maxLines: seniorMode ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.notoSerifTc(
                      fontSize: AppTypography.size(AppTypography.body, seniorMode: seniorMode),
                      fontWeight: FontWeight.w600,
                      color: AppColors.creamLight,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${video.viewCount} 次觀看',
                    style: TextStyle(
                      fontSize: AppTypography.size(AppTypography.caption, seniorMode: seniorMode),
                      color: AppColors.fog,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
                        fontSize: AppTypography.size(AppTypography.micro, seniorMode: seniorMode),
                        color: AppColors.gold,
                        letterSpacing: 2.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.title,
                    style: GoogleFonts.notoSerifTc(
                      fontSize: AppTypography.size(AppTypography.body, seniorMode: seniorMode),
                      fontWeight: FontWeight.w600,
                      color: AppColors.creamLight,
                      letterSpacing: 0.5,
                      height: 1.35,
                    ),
                    maxLines: seniorMode ? 1 : 2,
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
