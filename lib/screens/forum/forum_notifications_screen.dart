// 通知中心。只有「有人回覆你的貼文／留言」兩種類型（後端 forum_notifications.type）。

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../models/forum_models.dart';
import '../../services/forum_service.dart';
import 'forum_detail_screen.dart';
import 'widgets/forum_post_card.dart' show forumRelativeTime;

class ForumNotificationsScreen extends StatefulWidget {
  const ForumNotificationsScreen({super.key});

  @override
  State<ForumNotificationsScreen> createState() =>
      _ForumNotificationsScreenState();
}

class _ForumNotificationsScreenState extends State<ForumNotificationsScreen> {
  final _scrollController = ScrollController();
  final List<ForumNotification> _items = [];
  int? _nextCursor;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) _loadMore();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await ForumService.notifications();
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(page.items);
        _nextCursor = page.nextCursor;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    final cursor = _nextCursor;
    if (_loadingMore || cursor == null) return;
    setState(() => _loadingMore = true);
    try {
      final page = await ForumService.notifications(cursor: cursor);
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _nextCursor = page.nextCursor;
        _loadingMore = false;
      });
    } on ApiException {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  Future<void> _markAllRead() async {
    try {
      await ForumService.markRead();
      if (!mounted) return;
      setState(() {
        for (var i = 0; i < _items.length; i++) {
          final item = _items[i];
          _items[i] = ForumNotification(
            id: item.id,
            type: item.type,
            postId: item.postId,
            commentId: item.commentId,
            postTitle: item.postTitle,
            isRead: true,
            createdAt: item.createdAt,
            actor: item.actor,
          );
        }
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _open(ForumNotification item) async {
    final postId = item.postId;
    if (!item.isRead) {
      // 標記失敗不該擋住導頁，紅點下次進來會再對齊。
      ForumService.markRead(ids: [item.id]).catchError((_) {});
    }
    if (postId == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ForumDetailScreen(postId: postId)),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.creamLight,
        appBar: AppBar(
          backgroundColor: AppColors.creamLight,
          elevation: 0,
          foregroundColor: AppColors.ink,
          title: Text(
            '通知',
            style: GoogleFonts.notoSerifTc(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          actions: [
            TextButton(
              onPressed: _items.isEmpty ? null : _markAllRead,
              child: const Text(
                '全部已讀',
                style: TextStyle(color: AppColors.primary),
              ),
            ),
          ],
        ),
        body: _buildBody(),
      );

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    final error = _error;
    if (error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(error, style: const TextStyle(color: AppColors.inkSoft)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('重試')),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Text(
          '還沒有新的回覆',
          style: GoogleFonts.notoSerifTc(color: AppColors.fog),
        ),
      );
    }
    return ListView.separated(
      controller: _scrollController,
      itemCount: _items.length + (_loadingMore ? 1 : 0),
      separatorBuilder: (_, _) =>
          const Divider(height: 1, color: AppColors.creamDeep),
      itemBuilder: (_, i) {
        if (i >= _items.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
            ),
          );
        }
        final item = _items[i];
        final action =
            item.type == 'reply_post' ? '回覆了你的貼文' : '回覆了你的留言';
        return ListTile(
          tileColor: item.isRead ? null : AppColors.cream,
          onTap: () => _open(item),
          title: Text(
            '${item.actor.displayName} $action',
            style: GoogleFonts.notoSerifTc(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          subtitle: Text(
            '${item.postTitle ?? '（貼文已刪除）'} · '
            '${forumRelativeTime(item.createdAt)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: AppColors.fog),
          ),
        );
      },
    );
  }
}
