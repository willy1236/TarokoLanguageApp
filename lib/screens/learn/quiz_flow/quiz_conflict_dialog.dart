// 單字、聽力測驗共用的「有未完成的舊測驗」對話框：續接、放棄改測、返回三選一；
// 選放棄時再確認一次（已作答的題目不會保留），取消就回到三選一。

import 'package:flutter/material.dart';

import '../../../shared/widgets/confirm_dialog.dart';
import 'quiz_flow_controller.dart';

/// [subject] 是訊息裡對這份測驗的稱呼，例如「測驗」「聽力測驗」。
Future<QuizConflictChoice> showQuizConflictDialog(
  BuildContext context, {
  required String title,
  required String subject,
  required String oldLevel,
  required String wantedLevel,
}) async {
  while (true) {
    if (!context.mounted) return QuizConflictChoice.back;
    final choice = await showDialog<QuizConflictChoice>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AppDialog(
        title: title,
        message:
            '你還有未完成的「$oldLevel」$subject，'
            '要繼續完成，還是放棄它改測「$wantedLevel」？',
        primaryText: '繼續「$oldLevel」測驗',
        onPrimary: () => Navigator.pop(ctx, QuizConflictChoice.resume),
        stackSecondary: true,
        secondary: [
          (
            '放棄舊測驗，開始「$wantedLevel」',
            () => Navigator.pop(ctx, QuizConflictChoice.abandon),
          ),
          ('返回', () => Navigator.pop(ctx, QuizConflictChoice.back)),
        ],
      ),
    );
    if (choice != QuizConflictChoice.abandon) {
      return choice ?? QuizConflictChoice.back;
    }
    if (!context.mounted) return QuizConflictChoice.back;
    final sure = await showConfirmDialog(
      context,
      title: '放棄「$oldLevel」$subject？',
      message: '已作答的題目不會保留，確定要放棄嗎？',
      confirmText: '放棄並開始「$wantedLevel」',
      cancelText: '取消',
      barrierDismissible: false,
    );
    if (sure) return QuizConflictChoice.abandon;
  }
}
