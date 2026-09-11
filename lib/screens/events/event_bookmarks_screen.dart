// 我收藏的活動。重複使用 EventLikedBookmarkedList：分頁、空狀態、錯誤重試都現成。

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import 'event_liked_bookmarked_list.dart';
import '../../core/constants/app_typography.dart';

class EventBookmarksScreen extends StatelessWidget {
  const EventBookmarksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamLight,
      appBar: AppBar(
        backgroundColor: AppColors.creamLight,
        elevation: 0,
        foregroundColor: AppColors.ink,
        title: Text(
          '我收藏的活動',
          style: AppTypography.titleStyle(color: AppColors.ink),
        ),
      ),
      body: const EventLikedBookmarkedList(mode: EventListMode.bookmarked),
    );
  }
}
