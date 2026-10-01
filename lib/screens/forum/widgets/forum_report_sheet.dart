// 檢舉貼文、留言、個人檔案或活動（都走 POST /api/forum/reports）。同一人對同一目標重複檢舉，後端回 201 不視為錯誤
// （規格 §10），因此成功訊息一律是「已收到檢舉」。

import 'package:flutter/material.dart';

import '../../../services/forum_service.dart';
import '../../../shared/widgets/report_sheet.dart';

Future<void> showForumReportSheet(
  BuildContext context, {
  required String targetType,
  required Object targetId,
}) => showReportSheet(
  context,
  title: '檢舉',
  description: '請說明檢舉的原因，管理員會再確認。',
  hintText: '例如：廣告、人身攻擊、不實資訊',
  submitLabel: '送出檢舉',
  successMessage: '已收到檢舉',
  maxLength: ForumService.reasonMax,
  onSubmit: (reason) => ForumService.report(
    targetType: targetType,
    targetId: targetId,
    reason: reason,
  ),
);
