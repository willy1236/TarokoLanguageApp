// 文章內文的 Markdown 渲染（深色底）。文章詳情頁與管理員後台的文章預覽共用，
// 預覽才會和使用者實際看到的一模一樣。

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';

class ArticleMarkdown extends StatelessWidget {
  final String data;
  final bool seniorMode;

  const ArticleMarkdown({
    super.key,
    required this.data,
    this.seniorMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      data: data,
      styleSheet: MarkdownStyleSheet(
        p: TextStyle(
          color: AppColors.mist,
          fontSize: AppTypography.size(
            AppTypography.body,
            seniorMode: seniorMode,
          ),
          height: 1.6,
        ),
        h1: TextStyle(
          color: AppColors.creamLight,
          fontSize: AppTypography.size(
            AppTypography.title,
            seniorMode: seniorMode,
          ),
          fontWeight: FontWeight.w600,
        ),
        h2: TextStyle(
          color: AppColors.creamLight,
          fontSize: AppTypography.size(
            AppTypography.subtitle,
            seniorMode: seniorMode,
          ),
          fontWeight: FontWeight.w600,
        ),
        h3: TextStyle(
          color: AppColors.creamLight,
          fontSize: AppTypography.size(
            AppTypography.bodyLarge,
            seniorMode: seniorMode,
          ),
          fontWeight: FontWeight.w600,
        ),
        strong: TextStyle(
          color: AppColors.creamLight,
          fontWeight: FontWeight.w600,
        ),
        a: TextStyle(color: AppColors.gold),
        blockquote: TextStyle(color: AppColors.fog),
        blockquoteDecoration: BoxDecoration(
          color: AppColors.midnightSoft,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
