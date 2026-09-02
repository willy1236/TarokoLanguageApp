// 貼文列表卡片。視覺沿用 feature/forum-dcard 的語彙：cream 底、creamDeep 邊框、
// 圓角 16、圓形頭像描 gold 邊。
//
// 本元件無狀態：按讚與收藏只回呼給父層，樂觀更新與回滾由持有列表的一方負責，
// 避免同一筆貼文在列表與詳情頁各自持有互相打架的本地狀態。

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../models/forum_models.dart';
import '../../../services/senior_mode_controller.dart';
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
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: seniorModeController,
    builder: (context, _) => _build(seniorModeController.enabled),
  );

  Widget _build(bool seniorMode) => GestureDetector(
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
          _header(seniorMode),
          const SizedBox(height: 10),
          Text(
            post.title,
            // 精簡模式砍到 1 行：長者掃視卡片時先看標題判斷要不要點進去，
            // 內容摘要（下面 body）字級放大後 2 行常常整張卡片高度爆版。
            maxLines: seniorMode ? 1 : 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.notoSerifTc(
              fontSize: seniorMode ? AppTypography.headline : 15,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            post.body,
            maxLines: seniorMode ? 2 : 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: seniorMode ? AppTypography.title : 14,
              color: AppColors.inkSoft,
              height: 1.55,
              letterSpacing: 0.5,
            ),
          ),
          if (post.images.isNotEmpty) ...[
            const SizedBox(height: 10),
            // 列表上點附圖等同點卡片，一律進詳情頁；放大檢視只在詳情頁提供。
            ForumImageGrid(urls: post.images, onTap: onTap),
          ],
          // 精簡模式隱藏標籤列：任務8.1「資訊密度也是精簡的一環」，標籤對是否
          // 點開貼文的判斷幫助不大，卻會多佔一整排視覺雜訊。
          if (post.tags.isNotEmpty && !seniorMode) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final tag in post.tags) _tagChip(tag)],
            ),
          ],
          const SizedBox(height: 6),
          _footer(seniorMode),
        ],
      ),
    ),
  );

  Widget _initialsAvatar(double size) => Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      color: AppColors.primary,
    ),
    alignment: Alignment.center,
    child: Text(
      post.author.displayName.characters.firstOrNull ?? '?',
      style: GoogleFonts.notoSerifTc(
        fontSize: size * 0.37,
        fontWeight: FontWeight.w600,
        color: AppColors.gold,
      ),
    ),
  );

  Widget _avatar(bool seniorMode) {
    final size = seniorMode ? 52.0 : 38.0;
    final avatarUrl = post.author.avatarUrl;
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        border: Border.fromBorderSide(
          BorderSide(color: AppColors.gold, width: 1.5),
        ),
      ),
      child: (avatarUrl == null || avatarUrl.isEmpty)
          ? _initialsAvatar(size)
          : ClipOval(
              child: Image.network(
                avatarUrl,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _initialsAvatar(size),
              ),
            ),
    );
  }

  Widget _header(bool seniorMode) => Row(
    children: [
      _avatar(seniorMode),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              post.author.displayName,
              style: GoogleFonts.notoSerifTc(
                fontSize: seniorMode ? AppTypography.subtitle : 14,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
                letterSpacing: 0.6,
              ),
            ),
            Text(
              '${post.board.name} · ${forumRelativeTime(post.createdAt)}',
              style: TextStyle(
                fontSize: seniorMode ? AppTypography.body : 11,
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
              fontSize: seniorMode ? AppTypography.body : 11,
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

  Widget _footer(bool seniorMode) => Row(
    children: [
      _iconCount(
        key: const ValueKey('forum-post-like'),
        icon: post.isLiked ? Icons.favorite : Icons.favorite_border,
        color: post.isLiked ? AppColors.primary : AppColors.fog,
        count: post.likeCount,
        onTap: onLike,
        seniorMode: seniorMode,
      ),
      const SizedBox(width: 18),
      _iconCount(
        key: const ValueKey('forum-post-comment'),
        icon: Icons.mode_comment_outlined,
        color: AppColors.fog,
        count: post.commentCount,
        onTap: onTap,
        seniorMode: seniorMode,
      ),
      const Spacer(),
      IconButton(
        key: const ValueKey('forum-post-bookmark'),
        onPressed: onBookmark,
        visualDensity: seniorMode ? VisualDensity.standard : VisualDensity.compact,
        icon: Icon(
          post.isBookmarked ? Icons.bookmark : Icons.bookmark_border,
          size: seniorMode ? 34 : 18,
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
    required bool seniorMode,
  }) => GestureDetector(
    key: key,
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Padding(
      // 精簡模式下加大觸控熱區（探索報告任務6無障礙補強精神一致），
      // 避免長者手指誤觸鄰近的留言/收藏按鈕。
      padding: EdgeInsets.symmetric(vertical: seniorMode ? 12 : 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: seniorMode ? 30 : 16, color: color),
          const SizedBox(width: 5),
          Text(
            '$count',
            style: TextStyle(
              fontSize: seniorMode ? AppTypography.subtitle : 12,
              color: color,
            ),
          ),
        ],
      ),
    ),
  );
}
