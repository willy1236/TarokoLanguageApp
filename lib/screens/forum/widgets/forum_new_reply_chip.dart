// 貼文詳情頁的「有新回覆」提示：停在頁內時收到回覆推播，就浮在留言列表頂端，
// 直到使用者點它或離開頁面才消失。不用 SnackBar，它會蓋住留言輸入列。

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';

class ForumNewReplyChip extends StatelessWidget {
  /// 累積的新回覆數；0 代表沒有，不顯示。
  final int count;

  /// 還有較舊的留言沒載完，新留言要往下載入才看得到。
  final bool needsScrollToLoad;
  final bool seniorMode;
  final VoidCallback onTap;

  const ForumNewReplyChip({
    super.key,
    required this.count,
    required this.seniorMode,
    required this.onTap,
    this.needsScrollToLoad = false,
  });

  @override
  Widget build(BuildContext context) {
    final label = needsScrollToLoad
        ? '有 $count 則新回覆，往下載入就看得到'
        : '有 $count 則新回覆';
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SizeTransition(sizeFactor: animation, child: child),
      ),
      child: count <= 0
          ? const SizedBox.shrink()
          : Material(
              key: const ValueKey('forum_new_reply_chip'),
              color: AppColors.primary,
              elevation: 3,
              shadowColor: AppColors.ink.withValues(alpha: 0.4),
              shape: const StadiumBorder(),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: onTap,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: seniorMode ? 10 : 8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        needsScrollToLoad
                            ? Icons.arrow_downward
                            : Icons.arrow_upward,
                        size: seniorMode ? 20 : 16,
                        color: AppColors.creamLight,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: AppTypography.subtitleStyle(
                          seniorMode: seniorMode,
                          color: AppColors.creamLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
