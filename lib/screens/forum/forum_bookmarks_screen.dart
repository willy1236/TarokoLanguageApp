// 我的收藏。重複使用 ForumBoardView：分頁、空狀態、錯誤重試、樂觀更新都現成。
//
// 後端端點由使用者另行補上（規格 §9）。端點上線前這頁會顯示錯誤與重試，
// 屬開發期間的預期狀態。

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../services/forum_service.dart';
import 'forum_board_view.dart';
import 'forum_detail_screen.dart';

class ForumBookmarksScreen extends StatefulWidget {
  const ForumBookmarksScreen({super.key});

  @override
  State<ForumBookmarksScreen> createState() => _ForumBookmarksScreenState();
}

class _ForumBookmarksScreenState extends State<ForumBookmarksScreen> {
  final _viewKey = GlobalKey<ForumBoardViewState>();

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.creamLight,
        appBar: AppBar(
          backgroundColor: AppColors.creamLight,
          elevation: 0,
          foregroundColor: AppColors.ink,
          title: Text(
            '我的收藏',
            style: GoogleFonts.notoSerifTc(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
        ),
        body: ForumBoardView(
          key: _viewKey,
          emptyMessage: '還沒有收藏任何貼文',
          // 收藏頁沒有「比某 id 新」的語意，下拉刷新一律整份重載。
          prependOnRefresh: false,
          loadPage: ({cursor, after}) => ForumService.bookmarks(cursor: cursor),
          toggleLike: ForumService.likePost,
          toggleBookmark: (postId, {required add}) async {
            final result = await ForumService.bookmarkPost(postId, add: add);
            // 取消收藏後這筆就不屬於本頁，直接移除比留著一個空心書籤誠實。
            if (!result) _viewKey.currentState?.removePost(postId);
            return result;
          },
          onOpenPost: (post) => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ForumDetailScreen(postId: post.id),
            ),
          ),
        ),
      );
}
