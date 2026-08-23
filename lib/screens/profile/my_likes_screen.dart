// 「我按讚的內容」彙總頁：影音／文章／活動／貼文／留言 五個分頁。

import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../culture/video_liked_bookmarked_list.dart';
import '../culture/article_liked_bookmarked_list.dart';
import '../events/event_liked_bookmarked_list.dart';
import '../forum/forum_liked_posts_list.dart';
import '../forum/forum_liked_comments_list.dart';

class MyLikesScreen extends StatelessWidget {
  const MyLikesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: AppColors.creamLight,
        appBar: AppBar(
          backgroundColor: AppColors.creamLight,
          foregroundColor: AppColors.ink,
          elevation: 0,
          title: const Text('我按讚的內容'),
          bottom: const TabBar(
            isScrollable: true,
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
