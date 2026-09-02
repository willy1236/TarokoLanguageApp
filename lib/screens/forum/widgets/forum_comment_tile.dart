// 單則留言。論壇只有兩層，[isReply] 決定是否縮排，沒有更深的層級。
//
// 已刪除但底下還有回覆的第一層留言，後端會保留成佔位（is_deleted = true，
// body 與 author 皆為 null），此時只顯示「此留言已刪除」，不給任何操作按鈕——
// 對已刪除的留言做任何操作後端一律回 404。

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../models/forum_models.dart';
import '../../../services/senior_mode_controller.dart';
import 'forum_post_card.dart' show forumRelativeTime;

class ForumCommentTile extends StatelessWidget {
  final ForumComment comment;
  final bool isReply;
  final bool isMine;
  final VoidCallback onLike;
  final VoidCallback onReply;
  final VoidCallback onDelete;
  final VoidCallback onReport;

  const ForumCommentTile({
    super.key,
    required this.comment,
    required this.isReply,
    required this.isMine,
    required this.onLike,
    required this.onReply,
    required this.onDelete,
    required this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: seniorModeController,
      builder: (context, _) {
        final seniorMode = seniorModeController.enabled;
        if (comment.isDeleted) return _deletedPlaceholder(seniorMode);
        return _tile(seniorMode);
      },
    );
  }

  Widget _deletedPlaceholder(bool seniorMode) => Padding(
    key: const ValueKey('forum-comment-indent'),
    padding: EdgeInsets.fromLTRB(isReply ? 34 : 0, 10, 0, 10),
    child: Row(
      children: [
        Icon(
          Icons.block,
          size: seniorMode ? 22 : (isReply ? 14 : 16),
          color: AppColors.mist,
        ),
        const SizedBox(width: 8),
        Text(
          '此留言已刪除',
          style: GoogleFonts.notoSerifTc(
            fontSize: seniorMode ? AppTypography.title : 13,
            fontStyle: FontStyle.italic,
            color: AppColors.fog,
          ),
        ),
      ],
    ),
  );

  Widget _tile(bool seniorMode) => Padding(
    key: const ValueKey('forum-comment-indent'),
    padding: EdgeInsets.fromLTRB(isReply ? 34 : 0, 10, 0, 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _avatar(
              size: seniorMode ? (isReply ? 32 : 40) : (isReply ? 24 : 30),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                comment.author?.displayName ?? '匿名使用者',
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.notoSerifTc(
                  fontSize: seniorMode ? AppTypography.subtitle : 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              forumRelativeTime(comment.createdAt),
              style: TextStyle(
                fontSize: seniorMode ? AppTypography.body : 11,
                color: AppColors.fog,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Padding(
          padding: EdgeInsets.only(left: isReply ? 32 : 38),
          child: Text(
            comment.body,
            style: TextStyle(
              fontSize: seniorMode ? AppTypography.title : 14,
              color: AppColors.inkSoft,
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: EdgeInsets.only(left: isReply ? 32 : 38),
          child: Wrap(
            spacing: 16,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onLike,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      comment.isLiked ? Icons.favorite : Icons.favorite_border,
                      size: seniorMode ? 24 : 14,
                      color: comment.isLiked
                          ? AppColors.primary
                          : AppColors.fog,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${comment.likeCount}',
                      style: TextStyle(
                        fontSize: seniorMode ? AppTypography.subtitle : 12,
                        color: AppColors.fog,
                      ),
                    ),
                  ],
                ),
              ),
              _action('回覆', onReply, seniorMode),
              if (isMine)
                _action('刪除', onDelete, seniorMode)
              else
                _action('檢舉', onReport, seniorMode),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _initialsAvatar(double size) => Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      color: AppColors.moss,
    ),
    alignment: Alignment.center,
    child: Text(
      comment.author?.displayName.characters.firstOrNull ?? '?',
      style: GoogleFonts.notoSerifTc(fontSize: 12, color: AppColors.gold),
    ),
  );

  Widget _avatar({required double size}) {
    final avatarUrl = comment.author?.avatarUrl;
    if (avatarUrl == null || avatarUrl.isEmpty) return _initialsAvatar(size);
    return ClipOval(
      child: Image.network(
        avatarUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _initialsAvatar(size),
      ),
    );
  }

  Widget _action(String label, VoidCallback onTap, bool seniorMode) =>
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Text(
          label,
          style: TextStyle(
            fontSize: seniorMode ? AppTypography.subtitle : 12,
            color: AppColors.fog,
          ),
        ),
      );
}
