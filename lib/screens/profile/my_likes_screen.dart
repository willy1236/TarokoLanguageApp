// 「我按讚的內容」彙總頁：影音／文章／活動／貼文／留言 五個分頁。

import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../services/senior_mode_controller.dart';
import '../culture/video_liked_bookmarked_list.dart';
import '../culture/article_liked_bookmarked_list.dart';
import '../events/event_liked_bookmarked_list.dart';
import '../forum/forum_liked_posts_list.dart';
import '../forum/forum_liked_comments_list.dart';
import '../../shared/widgets/app_back_button.dart';

class MyLikesScreen extends StatelessWidget {
  const MyLikesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: seniorModeController,
      builder: (context, _) => _buildScaffold(seniorModeController.enabled),
    );
  }

  Widget _buildScaffold(bool seniorMode) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: AppColors.creamLight,
        appBar: AppBar(
          leading: const AppBackButton(),
          backgroundColor: AppColors.creamLight,
          foregroundColor: AppColors.ink,
          elevation: 0,
          title: Text(
            '我按讚的內容',
            style: AppTypography.serif(
              fontSize: AppTypography.size(AppTypography.subtitle, seniorMode: seniorMode),
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          bottom: const TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.fog,
            indicatorColor: AppColors.primary,
            tabs: [
              Tab(text: '影音'),
              Tab(text: '文章'),
              Tab(text: '活動'),
              Tab(text: '貼文'),
              Tab(text: '留言'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            VideoLikedBookmarkedList(mode: VideoListMode.liked),
            ArticleLikedBookmarkedList(mode: ArticleListMode.liked),
            EventLikedBookmarkedList(mode: EventListMode.liked),
            ForumLikedPostsList(),
            ForumLikedCommentsList(),
          ],
        ),
      ),
    );
  }
}
