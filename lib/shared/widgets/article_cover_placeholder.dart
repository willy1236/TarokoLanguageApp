import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../utils/article_category_style.dart';

/// 文章無封面圖時的預設樣式：依分類套用不同底色漸層與圖示。
class ArticleCoverPlaceholder extends StatelessWidget {
  final String category;

  const ArticleCoverPlaceholder({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final style = ArticleCategoryStyle.of(category);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [style.color, style.colorDeep],
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        style.icon,
        color: AppColors.creamLight.withValues(alpha: 0.85),
      ),
    );
  }
}
