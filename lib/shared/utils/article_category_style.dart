import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../models/article_models.dart';

/// 文章分類對應的封面圖底色與圖示，供無封面圖時的預設樣式使用。
class ArticleCategoryStyle {
  final Color color;
  final Color colorDeep;
  final IconData icon;

  const ArticleCategoryStyle(this.color, this.colorDeep, this.icon);

  static ArticleCategoryStyle of(String category) {
    switch (category) {
      case ArticleCategory.tribalIntro:
        return const ArticleCategoryStyle(
          AppColors.primary,
          AppColors.primaryDeep,
          Icons.holiday_village_outlined,
        );
      case ArticleCategory.cultural:
        return const ArticleCategoryStyle(
          AppColors.moss,
          AppColors.mossDeep,
          Icons.auto_stories_outlined,
        );
      case ArticleCategory.event:
        return const ArticleCategoryStyle(
          AppColors.gold,
          AppColors.goldDeep,
          Icons.celebration_outlined,
        );
      case ArticleCategory.education:
        return const ArticleCategoryStyle(
          AppColors.blueLight,
          AppColors.blue,
          Icons.school_outlined,
        );
      default:
        return const ArticleCategoryStyle(
          AppColors.fog,
          AppColors.ink,
          Icons.article_outlined,
        );
    }
  }
}
