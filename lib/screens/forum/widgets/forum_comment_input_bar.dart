// 貼文詳情頁底部的留言輸入列；回覆某則留言時上方顯示「回覆 @某人」可取消。

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icon_size.dart';
import '../../../core/constants/app_typography.dart';
import '../../../models/forum_models.dart';
import '../../../services/forum_service.dart';

class ForumCommentInputBar extends StatelessWidget {
  final TextEditingController controller;

  /// 正在回覆的第一層留言；null 代表回覆貼文本身。
  final ForumComment? replyTarget;
  final bool sending;

  /// 唯讀帳號：輸入框停用並提示，不能留言。
  final bool readOnly;
  final bool seniorMode;
  final VoidCallback onSend;
  final VoidCallback onCancelReply;

  const ForumCommentInputBar({
    super.key,
    required this.controller,
    required this.replyTarget,
    required this.sending,
    this.readOnly = false,
    required this.seniorMode,
    required this.onSend,
    required this.onCancelReply,
  });

  @override
  Widget build(BuildContext context) {
    final target = replyTarget;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cream,
        border: Border(top: BorderSide(color: AppColors.creamDeep)),
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        8 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (target != null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    '回覆 @${target.author?.displayName ?? '匿名使用者'}',
                    style: TextStyle(
                      fontSize: AppTypography.size(AppTypography.caption, seniorMode: seniorMode),
                      color: AppColors.fog,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: onCancelReply,
                  child: Icon(
                    Icons.close,
                    size: seniorMode ? 24 : 16,
                    color: AppColors.fog,
                  ),
                ),
              ],
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: !readOnly,
                  maxLength: ForumService.commentMax,
                  minLines: 1,
                  maxLines: 4,
                  style: TextStyle(
                    fontSize: seniorMode ? AppTypography.bodyLarge + AppTypography.seniorStep : null,
                  ),
                  decoration: InputDecoration(
                    hintText: readOnly ? '帳號唯讀中，無法留言' : '說點什麼…',
                    counterText: '',
                    border: InputBorder.none,
                  ),
                ),
              ),
              // 跟著輸入內容即時切換可否送出
              ListenableBuilder(
                listenable: controller,
                builder: (context, _) => IconButton(
                  onPressed: sending || readOnly || controller.text.trim().isEmpty
                      ? null
                      : onSend,
                  iconSize: AppIconSize.action(seniorMode),
                  icon: const Icon(Icons.send, color: AppColors.primary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
