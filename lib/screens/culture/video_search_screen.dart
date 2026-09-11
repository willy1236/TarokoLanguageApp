// 影音搜尋：關鍵字／時間區間／部落，三者皆選填、可任意組合。
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../models/video_models.dart';
import '../../services/video_service.dart';
import 'culture_search_screen.dart';
import 'video_detail_screen.dart';

class VideoSearchScreen extends StatelessWidget {
  const VideoSearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CultureSearchScreen<VideoSummary>(
      hint: '搜尋影片',
      emptyText: '找不到符合的影片',
      fetch: ({q, range, tribeId, required page}) async {
        final res = await VideoService.searchVideos(
          q: q,
          range: range,
          tribeId: tribeId,
          page: page,
        );
        return (items: res.videos, total: res.total);
      },
      itemBuilder: (video, seniorMode) =>
          _VideoResultTile(video: video, seniorMode: seniorMode),
    );
  }
}

class _VideoResultTile extends StatelessWidget {
  final VideoSummary video;
  final bool seniorMode;
  const _VideoResultTile({required this.video, required this.seniorMode});

  @override
  Widget build(BuildContext context) {
    final thumbWidth = seniorMode ? 100.0 : 72.0;
    final thumbHeight = seniorMode ? 68.0 : 48.0;
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => VideoDetailScreen(videoId: video.id)),
      ),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.midnightSoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cream.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            Container(
              width: thumbWidth,
              height: thumbHeight,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: const LinearGradient(
                  colors: [AppColors.moss, AppColors.mossDeep],
                ),
              ),
              child: video.thumbnailUrl != null
                  ? Image.network(video.thumbnailUrl!, fit: BoxFit.cover)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.notoSerifTc(
                      fontSize: AppTypography.size(AppTypography.body, seniorMode: seniorMode),
                      fontWeight: FontWeight.w600,
                      color: AppColors.creamLight,
                    ),
                  ),
                  const SizedBox(height: 3),
                  if (!seniorMode)
                    Text(
                      '${VideoCategory.label(video.category)} · ${video.viewCount} 次觀看',
                      style: const TextStyle(
                        fontSize: AppTypography.caption,
                        color: AppColors.fog,
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
}
