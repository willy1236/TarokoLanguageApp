// 「我按讚的活動」／「我收藏的活動」清單內容。不含 Scaffold/AppBar，
// 供獨立畫面或 TabBarView 嵌入使用。EventService 回傳 List<EventSummary>
// （無 total/page 包裝），用「這頁筆數 < pageSize」判斷是否還有下一頁。

import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/date_format.dart';
import '../../models/event_model.dart';
import '../../services/event_service.dart';
import '../../services/senior_mode_controller.dart';
import '../../shared/widgets/truku_empty_state.dart';
import 'event_detail_screen.dart';

enum EventListMode { liked, bookmarked }

class EventLikedBookmarkedList extends StatefulWidget {
  final EventListMode mode;
  const EventLikedBookmarkedList({super.key, required this.mode});

  @override
  State<EventLikedBookmarkedList> createState() =>
      _EventLikedBookmarkedListState();
}

class _EventLikedBookmarkedListState extends State<EventLikedBookmarkedList> {
  static const _pageSize = 20;

  final _events = <EventSummary>[];
  final _scrollController = ScrollController();
  int _page = 1;
  bool _hasMore = true;
  bool _loading = true;
  bool _loadingMore = false;
  Object? _error;

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
    if (_loadingMore || !_hasMore) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  Future<List<EventSummary>> _fetch(int page) {
    return widget.mode == EventListMode.liked
        ? EventService.fetchLikedEvents(page: page, pageSize: _pageSize)
        : EventService.fetchBookmarkedEvents(page: page, pageSize: _pageSize);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _fetch(1);
      if (!mounted) return;
      setState(() {
        _events
          ..clear()
          ..addAll(res);
        _page = 1;
        _hasMore = res.length >= _pageSize;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    try {
      final res = await _fetch(_page + 1);
      if (!mounted) return;
      setState(() {
        _events.addAll(res);
        _page += 1;
        _hasMore = res.length >= _pageSize;
      });
    } catch (_) {
      // 翻頁失敗保持原清單，使用者可再滑動觸發重試。
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: seniorModeController,
      builder: (context, _) => _buildBody(seniorModeController.enabled),
    );
  }

  Widget _buildBody(bool seniorMode) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_error != null) {
      return _buildError(_error, seniorMode);
    }
    if (_events.isEmpty) {
      return _buildEmpty(seniorMode);
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _events.length + (_hasMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index >= _events.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
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
          return _EventListItem(
            event: _events[index],
            seniorMode: seniorMode,
          );
        },
      ),
    );
  }

  Widget _buildEmpty(bool seniorMode) {
    final message = widget.mode == EventListMode.liked
        ? '還沒有按讚任何活動'
        : '還沒有收藏任何活動';
    return TrukuEmptyState(
      icon: Icons.event_outlined,
      message: message,
      subtitle: '下拉重新整理，看看有沒有新活動。',
      seniorMode: seniorMode,
    );
  }

  Widget _buildError(Object? error, bool seniorMode) {
    final message = error is ApiException ? error.message : '發生錯誤，請稍後再試';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              color: AppColors.fog,
              size: seniorMode ? 56 : 40,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(
                color: AppColors.inkSoft,
                fontSize: seniorMode ? AppTypography.title : 14,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _load,
              style: seniorMode
                  ? OutlinedButton.styleFrom(
                      minimumSize: const Size(140, 52),
                      textStyle: const TextStyle(
                        fontSize: AppTypography.subtitle,
                      ),
                    )
                  : null,
              child: const Text('重試'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventListItem extends StatelessWidget {
  final EventSummary event;
  final bool seniorMode;
  const _EventListItem({required this.event, required this.seniorMode});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => EventDetailScreen(eventId: event.id)),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.creamDeep),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              event.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.ink,
                fontSize: seniorMode ? AppTypography.title : 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: seniorMode ? 20 : 13,
                  color: AppColors.fog,
                ),
                const SizedBox(width: 4),
                Text(
                  formatDateTime(event.startsAt.toLocal()),
                  style: TextStyle(
                    color: AppColors.inkSoft,
                    fontSize: seniorMode ? AppTypography.subtitle : 11.5,
                  ),
                ),
              ],
            ),
            if (event.location != null && event.location!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: seniorMode ? 20 : 13,
                    color: AppColors.fog,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      event.location!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.inkSoft,
                        fontSize: seniorMode ? AppTypography.subtitle : 11.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  event.isLiked ? Icons.favorite : Icons.favorite_border,
                  size: seniorMode ? 22 : 14,
                  color: event.isLiked ? AppColors.primary : AppColors.fog,
                ),
                const SizedBox(width: 4),
                Text(
                  '${event.likeCount}',
                  style: TextStyle(
                    color: AppColors.fog,
                    fontSize: seniorMode ? AppTypography.subtitle : 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
