// 活動通知：發起人對「我有參加」的活動發出的提醒。介面比照 ForumNotificationsScreen。

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../models/event_model.dart';
import '../../services/event_service.dart';
import '../../services/senior_mode_controller.dart';
import 'event_detail_screen.dart';

String _relativeTime(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return '剛剛';
  if (diff.inMinutes < 60) return '${diff.inMinutes} 分鐘前';
  if (diff.inHours < 24) return '${diff.inHours} 小時前';
  if (diff.inDays < 7) return '${diff.inDays} 天前';
  return '${time.year}/${time.month}/${time.day}';
}

class EventNotificationsScreen extends StatefulWidget {
  const EventNotificationsScreen({super.key});

  @override
  State<EventNotificationsScreen> createState() =>
      _EventNotificationsScreenState();
}

class _EventNotificationsScreenState extends State<EventNotificationsScreen> {
  final _scrollController = ScrollController();
  final List<EventNotification> _items = [];
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
      final page = await EventService.notifications();
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
      final page = await EventService.notifications(cursor: cursor);
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
      await EventService.markNotificationsRead();
      if (!mounted) return;
      setState(() {
        for (var i = 0; i < _items.length; i++) {
          final item = _items[i];
          _items[i] = EventNotification(
            id: item.id,
            eventId: item.eventId,
            eventTitle: item.eventTitle,
            message: item.message,
            sentAt: item.sentAt,
            isRead: true,
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

  Future<void> _open(EventNotification item) async {
    if (!item.isRead) {
      // 標記失敗不該擋住導頁，紅點下次進來會再對齊。
      EventService.markNotificationsRead(ids: [item.id]).catchError((_) {});
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EventDetailScreen(eventId: item.eventId),
      ),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: seniorModeController,
    builder: (context, _) => _buildScaffold(seniorModeController.enabled),
  );

  Widget _buildScaffold(bool seniorMode) => Scaffold(
    backgroundColor: AppColors.creamLight,
    appBar: AppBar(
      backgroundColor: AppColors.creamLight,
      elevation: 0,
      foregroundColor: AppColors.ink,
      title: Text(
        '活動通知',
        style: GoogleFonts.notoSerifTc(
          fontSize: seniorMode ? 22 : 16,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
      ),
      actions: [
        TextButton(
          onPressed: _items.isEmpty ? null : _markAllRead,
          child: Text(
            '全部已讀',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: seniorMode ? 16 : null,
            ),
          ),
        ),
      ],
    ),
    body: _buildBody(seniorMode),
  );

  Widget _buildBody(bool seniorMode) {
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
            Text(
              error,
              style: TextStyle(
                color: AppColors.inkSoft,
                fontSize: seniorMode ? 18 : null,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _load,
              style: seniorMode
                  ? OutlinedButton.styleFrom(minimumSize: const Size(140, 52))
                  : null,
              child: const Text('重試'),
            ),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Text(
          '還沒有收到活動通知',
          style: GoogleFonts.notoSerifTc(
            color: AppColors.fog,
            fontSize: seniorMode ? 18 : null,
          ),
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
        return ListTile(
          tileColor: item.isRead ? null : AppColors.cream,
          onTap: () => _open(item),
          title: Text(
            item.eventTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.notoSerifTc(
              fontSize: seniorMode ? 20 : 14,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          subtitle: Text(
            '${item.message} · ${_relativeTime(item.sentAt)}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: seniorMode ? 16 : 12,
              color: AppColors.fog,
            ),
          ),
        );
      },
    );
  }
}
