// 貼文列表卡片。視覺沿用 feature/forum-dcard 的語彙：cream 底、creamDeep 邊框、
// 圓角 16、圓形頭像描 gold 邊。
//
// 本元件無狀態：按讚與收藏只回呼給父層，樂觀更新與回滾由持有列表的一方負責，
// 避免同一筆貼文在列表與詳情頁各自持有互相打架的本地狀態。

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../models/forum_models.dart';
import 'forum_image_grid.dart';

String forumRelativeTime(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return '剛剛';
  if (diff.inMinutes < 60) return '${diff.inMinutes} 分鐘前';
  if (diff.inHours < 24) return '${diff.inHours} 小時前';
  if (diff.inDays < 7) return '${diff.inDays} 天前';
  return '${time.year}/${time.month}/${time.day}';
}

class ForumPostCard extends StatelessWidget {
  final ForumPost post;
  final VoidCallback onTap;
  final VoidCallback onLike;
  final VoidCallback onBookmark;

  const ForumPostCard({
    super.key,
    required this.post,
    required this.onTap,
    required this.onLike,
    required this.onBookmark,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 10),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.creamDeep),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          const SizedBox(height: 10),
          Text(
            post.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.notoSerifTc(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            post.body,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.inkSoft,
              height: 1.55,
              letterSpacing: 0.5,
            ),
          ),
          if (post.images.isNotEmpty) ...[
            const SizedBox(height: 10),
            ForumImageGrid(urls: post.images),
          ],
          if (post.tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final tag in post.tags) _tagChip(tag)],
            ),
          ],
          const SizedBox(height: 6),
          _footer(),
        ],
      ),
    ),
  );

  Widget _header() => Row(
    children: [
      Container(
        width: 38,
        height: 38,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.primary,
          border: Border.fromBorderSide(
            BorderSide(color: AppColors.gold, width: 1.5),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          post.author.displayName.characters.firstOrNull ?? '?',
          style: GoogleFonts.notoSerifTc(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.gold,
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              post.author.displayName,
              style: GoogleFonts.notoSerifTc(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
                letterSpacing: 0.6,
              ),
            ),
            Text(
              '${post.board.name} · ${forumRelativeTime(post.createdAt)}',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.fog,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
      if (post.isPinned)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '置頂',
            style: GoogleFonts.notoSerifTc(
              fontSize: 11,
              color: AppColors.goldDeep,
              letterSpacing: 1.2,
            ),
          ),
        ),
    ],
  );

  Widget _tagChip(ForumTag tag) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(
      color: AppColors.primary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      '#${tag.name}',
      style: GoogleFonts.crimsonPro(
        fontStyle: FontStyle.italic,
        fontSize: 11,
        color: AppColors.primary,
        letterSpacing: 1.2,
      ),
    ),
  );

  Widget _footer() => Row(
    children: [
      _iconCount(
        key: const ValueKey('forum-post-like'),
        icon: post.isLiked ? Icons.favorite : Icons.favorite_border,
        color: post.isLiked ? AppColors.primary : AppColors.fog,
        count: post.likeCount,
        onTap: onLike,
      ),
      const SizedBox(width: 18),
      _iconCount(
        key: const ValueKey('forum-post-comment'),
        icon: Icons.mode_comment_outlined,
        color: AppColors.fog,
        count: post.commentCount,
        onTap: onTap,
      ),
      const Spacer(),
      IconButton(
        key: const ValueKey('forum-post-bookmark'),
        onPressed: onBookmark,
        visualDensity: VisualDensity.compact,
        icon: Icon(
          post.isBookmarked ? Icons.bookmark : Icons.bookmark_border,
          size: 18,
          color: post.isBookmarked ? AppColors.primary : AppColors.fog,
        ),
      ),
    ],
  );

  Widget _iconCount({
    required Key key,
    required IconData icon,
    required Color color,
    required int count,
    required VoidCallback onTap,
  }) => GestureDetector(
    key: key,
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 5),
          Text('$count', style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    ),
  );
}
