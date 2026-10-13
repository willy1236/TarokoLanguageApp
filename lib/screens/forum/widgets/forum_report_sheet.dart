// 檢舉貼文、留言、個人檔案或活動（都走 POST /api/forum/reports）。同一人對同一目標重複檢舉，後端回 201 不視為錯誤
// （規格 §10），因此成功一律提示「已收到檢舉」。
//
// 貼文、留言、活動一送出檢舉，後端就不再列給檢舉人自己（決策紀錄 A47），預設文案因此告知「不會再顯示給你」；
// 個人檔案後端不排除，呼叫端要傳自己的 [successMessage]。

import 'package:flutter/material.dart';

import '../../../services/forum_service.dart';
import '../../../shared/widgets/report_sheet.dart';

/// 回傳是否送出成功；直接關掉面板或送出失敗（面板留著）都不會是 true。
Future<bool> showForumReportSheet(
  BuildContext context, {
  required String targetType,
  required Object targetId,
  String successMessage = '已收到檢舉，這則內容不會再顯示給你',
}) => showReportSheet(
  context,
  title: '檢舉',
  description: '請說明檢舉的原因，管理員會再確認。',
  hintText: '例如：廣告、人身攻擊、不實資訊',
  submitLabel: '送出檢舉',
  successMessage: successMessage,
  maxLength: ForumService.reasonMax,
  onSubmit: (reason) => ForumService.report(
    targetType: targetType,
    targetId: targetId,
    reason: reason,
  ),
);
