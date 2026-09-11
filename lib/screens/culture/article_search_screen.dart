// 文章搜尋：關鍵字／時間區間／部落，三者皆選填、可任意組合。
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../models/article_models.dart';
import '../../services/article_service.dart';
import '../../shared/widgets/article_cover_placeholder.dart';
import 'article_detail_screen.dart';
import 'culture_search_screen.dart';

class ArticleSearchScreen extends StatelessWidget {
  const ArticleSearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CultureSearchScreen<ArticleSummary>(
      hint: '搜尋文章',
      emptyText: '找不到符合的文章',
      fetch: ({q, range, tribeId, required page}) async {
        final res = await ArticleService.searchArticles(
          q: q,
          range: range,
          tribeId: tribeId,
          page: page,
        );
        return (items: res.articles, total: res.total);
      },
      itemBuilder: (article, seniorMode) =>
          _ArticleResultTile(article: article, seniorMode: seniorMode),
    );
  }
}

class _ArticleResultTile extends StatelessWidget {
  final ArticleSummary article;
  final bool seniorMode;
  const _ArticleResultTile({required this.article, required this.seniorMode});

  @override
  Widget build(BuildContext context) {
    final thumbSize = seniorMode ? 76.0 : 56.0;
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ArticleDetailScreen(articleId: article.id),
        ),
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
              width: thumbSize,
              height: thumbSize,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
              child: article.coverImageUrl != null
                  ? Image.network(article.coverImageUrl!, fit: BoxFit.cover)
                  : ArticleCoverPlaceholder(category: article.category),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.title,
                    maxLines: seniorMode ? 1 : 2,
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
                      '${ArticleCategory.label(article.category)} · ${article.viewCount} 閱讀',
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
