// 「我的收藏」彙總頁：影音／文章／活動／廣場 四個分頁。
// 廣場分頁重用 ForumBoardView（與 forum_bookmarks_screen.dart 同一套邏輯），
// 讓使用者不必再另外去 Plaza 才能看到貼文收藏。

import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../culture/video_liked_bookmarked_list.dart';
import '../culture/article_liked_bookmarked_list.dart';
import '../events/event_liked_bookmarked_list.dart';
import '../forum/forum_board_view.dart';
import '../forum/forum_detail_screen.dart';
import '../../services/forum_service.dart';

class MyBookmarksScreen extends StatefulWidget {
  const MyBookmarksScreen({super.key});

  @override
  State<MyBookmarksScreen> createState() => _MyBookmarksScreenState();
}

class _MyBookmarksScreenState extends State<MyBookmarksScreen> {
  final _forumViewKey = GlobalKey<ForumBoardViewState>();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: AppColors.creamLight,
        appBar: AppBar(
          backgroundColor: AppColors.creamLight,
          foregroundColor: AppColors.ink,
          elevation: 0,
          title: const Text('我的收藏'),
          bottom: const TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.fog,
            indicatorColor: AppColors.primary,
            tabs: [
              Tab(text: '影音'),
              Tab(text: '文章'),
              Tab(text: '活動'),
              Tab(text: '廣場'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            const VideoLikedBookmarkedList(mode: VideoListMode.bookmarked),
            const ArticleLikedBookmarkedList(mode: ArticleListMode.bookmarked),
            const EventLikedBookmarkedList(mode: EventListMode.bookmarked),
            ForumBoardView(
              key: _forumViewKey,
              emptyMessage: '還沒有收藏任何貼文',
              prependOnRefresh: false,
              loadPage: ({cursor, after}) =>
                  ForumService.bookmarks(cursor: cursor),
              toggleLike: ForumService.likePost,
              toggleBookmark: (postId, {required add}) async {
                final result = await ForumService.bookmarkPost(
                  postId,
                  add: add,
                );
                if (!result) _forumViewKey.currentState?.removePost(postId);
                return result;
              },
              onOpenPost: (post) async {
                final result = await Navigator.push<ForumDetailResult>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ForumDetailScreen(
                      postId: post.id,
                      onPostChanged: (p) =>
                          _forumViewKey.currentState?.replacePost(p),
                    ),
                  ),
                );
                if (result == null) return;
                if (result.deleted) {
                  _forumViewKey.currentState?.removePost(post.id);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
