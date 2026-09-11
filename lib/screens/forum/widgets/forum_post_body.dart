// 貼文詳情頁的貼文本體：標題、作者與時間、內文、圖片、讚與收藏。

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../models/forum_models.dart';
import 'forum_image_grid.dart';
import 'forum_post_card.dart' show forumRelativeTime;

class ForumPostBody extends StatelessWidget {
  final ForumPost post;
  final bool seniorMode;

  /// 圖片簽章網址過期時呼叫（父層重新取貼文拿新網址）。
  final VoidCallback onImageExpired;
  final VoidCallback onLike;
  final VoidCallback onBookmark;

  const ForumPostBody({
    super.key,
    required this.post,
    required this.seniorMode,
    required this.onImageExpired,
    required this.onLike,
    required this.onBookmark,
  });

  @override
  Widget build(BuildContext context) => _postBody(post, seniorMode);

  Widget _postBody(ForumPost post, bool seniorMode) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        post.title,
        style: GoogleFonts.notoSerifTc(
          fontSize: AppTypography.size(AppTypography.title, seniorMode: seniorMode),
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
          height: 1.4,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        '${post.author.displayName} · ${post.board.name} · '
        '${forumRelativeTime(post.createdAt)}',
        style: TextStyle(
          fontSize: AppTypography.size(AppTypography.caption, seniorMode: seniorMode),
          color: AppColors.fog,
        ),
      ),
      const SizedBox(height: 14),
      Text(
        post.body,
        style: TextStyle(
          fontSize: AppTypography.size(AppTypography.bodyLarge, seniorMode: seniorMode),
          color: AppColors.inkSoft,
          height: 1.7,
        ),
      ),
      if (post.images.isNotEmpty) ...[
        const SizedBox(height: 14),
        ForumImageGrid(urls: post.images, onImageExpired: onImageExpired),
      ],
      if (post.tags.isNotEmpty) ...[
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          children: [
            for (final tag in post.tags)
              Text(
                '#${tag.name}',
                style: GoogleFonts.crimsonPro(
                  fontStyle: FontStyle.italic,
                  fontSize: AppTypography.size(AppTypography.caption, seniorMode: seniorMode),
                  color: AppColors.primary,
                ),
              ),
          ],
        ),
      ],
      const SizedBox(height: 12),
      Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onLike,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  post.isLiked ? Icons.favorite : Icons.favorite_border,
                  size: seniorMode ? 30 : 18,
                  color: post.isLiked ? AppColors.primary : AppColors.fog,
                ),
                const SizedBox(width: 6),
                Text(
                  '${post.likeCount}',
                  style: TextStyle(
                    fontSize: AppTypography.size(AppTypography.body, seniorMode: seniorMode),
                    color: AppColors.fog,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onBookmark,
            child: Icon(
              post.isBookmarked ? Icons.bookmark : Icons.bookmark_border,
              size: seniorMode ? 30 : 18,
              color: post.isBookmarked ? AppColors.primary : AppColors.fog,
            ),
          ),
        ],
      ),
    ],
  );
}
