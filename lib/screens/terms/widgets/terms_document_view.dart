// 一份條款的顯示：標題、版本、Markdown 全文。條款同意畫面與管理員後台的
// 「發布條款」預覽共用，預覽才會和使用者實際看到的一模一樣。

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';

class TermsDocumentView extends StatelessWidget {
  final String title;
  final int version;
  final String contentMd;

  /// 標題已在別處（Tab 標籤）顯示過時傳 false。
  final bool showTitle;

  const TermsDocumentView({
    super.key,
    required this.title,
    required this.version,
    required this.contentMd,
    this.showTitle = true,
  });

  /// [title] 已在 Tab 標籤或上方顯示過一次，若 [contentMd] 開頭是重複的同名
  /// 標題行則去掉，避免畫面看到兩次「織語者 服務條款」。
  static String stripLeadingTitle(String contentMd, String title) {
    final lines = contentMd.split('\n');
    if (lines.isEmpty) return contentMd;
    final firstLine = lines.first.replaceFirst(RegExp(r'^#+\s*'), '').trim();
    if (firstLine != title.trim()) return contentMd;
    return lines.skip(1).join('\n').trimLeft();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle) ...[
          Text(
            title,
            style: AppTypography.serif(
              fontSize: AppTypography.subtitle,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
        ],
        Text(
          '第 $version 版',
          style: TextStyle(
            fontSize: AppTypography.caption,
            color: AppColors.fog,
          ),
        ),
        const SizedBox(height: 12),
        MarkdownBody(
          data: stripLeadingTitle(contentMd, title),
          styleSheet: MarkdownStyleSheet(
            p: TextStyle(
              fontSize: AppTypography.body,
              height: 1.6,
              color: AppColors.ink.withValues(alpha: 0.85),
            ),
            h1: AppTypography.serif(
              fontSize: AppTypography.subtitle,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
            h1Padding: const EdgeInsets.only(top: 16, bottom: 4),
            h2: AppTypography.titleStyle(color: AppColors.ink),
            h2Padding: const EdgeInsets.only(top: 16, bottom: 4),
            h3: AppTypography.titleStyle(color: AppColors.ink),
            strong: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
            // 預設 blockquote 底色跟著 dark theme 變深，粗體的 ink 字會看不到。
            blockquote: TextStyle(
              fontSize: AppTypography.body,
              height: 1.6,
              color: AppColors.ink.withValues(alpha: 0.85),
            ),
            blockquotePadding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
            blockquoteDecoration: BoxDecoration(
              color: AppColors.creamDeep,
              border: const Border(
                left: BorderSide(color: AppColors.gold, width: 4),
              ),
            ),
            listBullet: TextStyle(
              fontSize: AppTypography.body,
              color: AppColors.ink.withValues(alpha: 0.85),
            ),
          ),
        ),
      ],
    );
  }
}
