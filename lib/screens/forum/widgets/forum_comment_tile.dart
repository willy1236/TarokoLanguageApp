// 單則留言。論壇只有兩層，[isReply] 決定是否縮排，沒有更深的層級。
//
// 被刪除的留言（第一層或回覆，不論作者自刪、後台下架或帳號刪除），後端一律
// 保留成佔位（is_deleted = true，body 與 author 皆為 null），此時只顯示
// 「留言已被刪除」，不給任何操作按鈕——對已刪除的留言做任何操作後端一律回 404。

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../models/forum_models.dart';
import '../../../models/shop_item.dart';
import '../../../services/senior_mode_controller.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../friends/public_profile_screen.dart';
import '../../../core/utils/date_format.dart';
import '../../../shared/widgets/nickname_text.dart';
import '../forum_author_code.dart';

class ForumCommentTile extends StatelessWidget {
  final ForumComment comment;
  final bool isReply;
  final bool isMine;
  final VoidCallback onLike;

  /// null 時不顯示（唯讀帳號不能留言、檢舉）。
  final VoidCallback? onReply;
  final VoidCallback onDelete;
  final VoidCallback? onReport;

  /// 管理員才給：顯示「管理員下架」。自己的留言不顯示（自己走刪除）。
  final VoidCallback? onAdminRemove;
  final Map<String, ShopItem> itemCatalogById;

  const ForumCommentTile({
    super.key,
    required this.comment,
    required this.isReply,
    required this.isMine,
    required this.onLike,
    this.onReply,
    required this.onDelete,
    this.onReport,
    this.onAdminRemove,
    this.itemCatalogById = const {},
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
          '留言已被刪除',
          style: AppTypography.serif(
            fontSize: AppTypography.size(
              AppTypography.body,
              seniorMode: seniorMode,
            ),
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
            Expanded(
              child: Builder(
                builder: (context) => GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _openAuthorProfile(context),
                  child: Row(
                    children: [
                      _avatar(
                        size: seniorMode
                            ? (isReply ? 32 : 40)
                            : (isReply ? 24 : 30),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: NicknameText(
                          comment.author?.displayName ?? '匿名使用者',
                          friendCode: comment.author?.othersFriendCode,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.serif(
                            fontSize: AppTypography.size(
                              AppTypography.body,
                              seniorMode: seniorMode,
                            ),
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              formatRelativeTime(comment.createdAt),
              style: TextStyle(
                fontSize: AppTypography.size(
                  AppTypography.caption,
                  seniorMode: seniorMode,
                ),
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
              fontSize: AppTypography.size(
                AppTypography.body,
                seniorMode: seniorMode,
              ),
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
                        fontSize: AppTypography.size(
                          AppTypography.caption,
                          seniorMode: seniorMode,
                        ),
                        color: AppColors.fog,
                      ),
                    ),
                  ],
                ),
              ),
              if (onReply case final onReply?)
                _action('回覆', onReply, seniorMode),
              if (isMine)
                _action('刪除', onDelete, seniorMode)
              else if (onReport case final onReport?)
                _action('檢舉', onReport, seniorMode),
              if (!isMine && onAdminRemove != null)
                _action('管理員下架', onAdminRemove!, seniorMode),
            ],
          ),
        ),
      ],
    ),
  );

  void _openAuthorProfile(BuildContext context) {
    final friendCode = comment.author?.friendCode;
    if (friendCode == null || friendCode.isEmpty) {
      // 作者帳號刪除中／已刪除時後端不給好友碼，沒有公開檔案可看。
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text('無法查看此使用者的個人檔案')));
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PublicProfileScreen(friendCode: friendCode),
      ),
    );
  }

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
      style: AppTypography.serif(
        fontSize: AppTypography.caption,
        color: AppColors.gold,
      ),
    ),
  );

  Widget _avatar({required double size}) {
    final author = comment.author;
    return FramedUserAvatar(
      avatarId: author?.avatarId,
      avatarUrl: author?.avatarUrl,
      frameId: author?.frameId,
      itemCatalogById: itemCatalogById,
      size: size,
      fallbackIconColor: AppColors.gold,
      fallback: _initialsAvatar(size),
      userFriendCode: author?.friendCode,
    );
  }

  Widget _action(String label, VoidCallback onTap, bool seniorMode) =>
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Text(
          label,
          style: TextStyle(
            fontSize: AppTypography.size(
              AppTypography.caption,
              seniorMode: seniorMode,
            ),
            color: AppColors.fog,
          ),
        ),
      );
}
