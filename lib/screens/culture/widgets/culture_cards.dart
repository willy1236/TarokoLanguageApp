// 文化頁的影片卡、文章卡與分類 chip 列。

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../models/article_models.dart';
import '../../../models/video_models.dart';
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

/// 標題列右側的排序字（例如「最新／熱門／本週熱門」）：影音與文章分頁共用。
///
/// [options] 是 `(值, 顯示字)`；點到目前已選的值不會呼叫 [onChanged]。
/// 字級是內文（14，精簡模式 +2），每個字至少 44×44 的點擊範圍。
class CultureSortLabels extends StatelessWidget {
  final List<(String, String)> options;
  final String selected;
  final ValueChanged<String> onChanged;
  final bool seniorMode;

  const CultureSortLabels({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.seniorMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      // 外層若是 Wrap，給子元件的寬度是整行，Row 撐滿就會永遠自成一行。
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (value, label) in options) _label(value, label),
      ],
    );
  }

  Widget _label(String value, String label) {
    final active = selected == value;
    return GestureDetector(
      // 字旁邊的空白也算點到，長輩不必瞄準字本身。
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (active) return;
        onChanged(value);
      },
      child: Container(
        constraints: const BoxConstraints(
          minWidth: _minTapSize,
          minHeight: _minTapSize,
        ),
        // 左右內距同時當字與字的間距。
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTypography.bodyLargeStyle(
            seniorMode: seniorMode,
            color: active ? AppColors.gold : AppColors.fog,
          ).copyWith(
            fontWeight: active ? FontWeight.w700 : FontWeight.w400,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }

  /// 最小點擊範圍（Material／iOS 建議的 44～48）。
  static const _minTapSize = 44.0;
}

/// 總覽清單的大圖卡：上方封面、左上分類標籤、標題疊在封面底部漸層上，
/// 下方摘要＋箭頭。
///
/// 精簡模式標題改放到封面下方的實色區（避免封面色彩複雜時蓋掉放大後的標題），
/// 並隱藏摘要維持密度精簡。
class CultureCoverCard extends StatelessWidget {
  /// 封面內容（圖片或佔位），會被裁成卡片寬、固定高度。
  final Widget cover;
  final String category;
  final String title;
  final String summary;
  final bool seniorMode;
  final VoidCallback onTap;

  const CultureCoverCard({
    super.key,
    required this.cover,
    required this.category,
    required this.title,
    required this.summary,
    required this.onTap,
    this.seniorMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.midnightSoft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cream.withValues(alpha: 0.06)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: seniorMode ? 140 : 120, child: _cover()),
            if (!seniorMode) _summaryRow() else _seniorTitleRow(),
          ],
        ),
      ),
    );
  }

  Widget _cover() {
    return Stack(
      fit: StackFit.expand,
      children: [
        cover,
        Positioned(
          top: 12,
          left: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.gold,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              category,
              style: TextStyle(
                fontSize: AppTypography.size(
                  AppTypography.micro,
                  seniorMode: seniorMode,
                ),
                color: AppColors.ink,
                fontWeight: FontWeight.w600,
                letterSpacing: 2.8,
              ),
            ),
          ),
        ),
        // 底部漸層遮罩，避免淺色封面圖讓標題文字失去對比而看不清（一般模式標題疊在圖上）
        if (!seniorMode) ...[
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 64,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 14,
            left: 16,
            right: 16,
            child: Text(
              title,
              style: AppTypography.serif(
                fontSize: AppTypography.title,
                fontWeight: FontWeight.w600,
                color: AppColors.creamLight,
                letterSpacing: 1.0,
                height: 1.25,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }

  Widget _summaryRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              summary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: AppTypography.caption,
                color: AppColors.fog,
                letterSpacing: 1.0,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const CultureArrowIcon(),
        ],
      ),
    );
  }

  Widget _seniorTitleRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: AppTypography.serif(
                fontSize: AppTypography.display24,
                fontWeight: FontWeight.w600,
                color: AppColors.creamLight,
                letterSpacing: 1.0,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          const CultureArrowIcon(size: 24),
        ],
      ),
    );
  }
}

/// 沒有封面圖時的織紋漸層佔位（酒紅底＋金色織紋）。
class CultureWeaveCover extends StatelessWidget {
  const CultureWeaveCover({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.primaryDeep],
            ),
          ),
        ),
        CustomPaint(
          painter: TrukuWeavePainter(
            color: AppColors.gold,
            opacity: 0.25,
            scale: 0.7,
          ),
        ),
      ],
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

/// 文章總覽的一則：大圖卡，封面用文章封面圖，沒有就用織紋漸層。
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
    final coverUrl = item.coverImageUrl;
    return CultureCoverCard(
      cover: coverUrl != null
          ? Image.network(
              coverUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const CultureWeaveCover(),
            )
          : const CultureWeaveCover(),
      category: ArticleCategory.label(item.category),
      title: item.title,
      summary: item.summary ?? '這篇文章還沒有摘要，點進去看看內容吧',
      seniorMode: seniorMode,
      onTap: onTap,
    );
  }
}
