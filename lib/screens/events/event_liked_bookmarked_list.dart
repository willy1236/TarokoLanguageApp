// 「我按讚的活動」／「我收藏的活動」清單內容。不含 Scaffold/AppBar，
// 供獨立畫面或 TabBarView 嵌入使用。分頁、下拉重整、封面過期重取都交給 PagedEventList。

import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/utils/date_format.dart';
import '../../models/event_model.dart';
import '../../services/event_service.dart';
import '../../services/senior_mode_controller.dart';
import '../../shared/widgets/truku_empty_state.dart';
import 'event_detail_screen.dart';
import 'widgets/event_cover.dart';
import 'widgets/paged_event_list.dart';

enum EventListMode { liked, bookmarked }

class EventLikedBookmarkedList extends StatelessWidget {
  final EventListMode mode;
  const EventLikedBookmarkedList({super.key, required this.mode});

  Future<EventPage> _fetch(String? cursor) {
    return mode == EventListMode.liked
        ? EventService.fetchLikedEvents(cursor: cursor)
        : EventService.fetchBookmarkedEvents(cursor: cursor);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: seniorModeController,
      builder: (context, _) {
        final seniorMode = seniorModeController.enabled;
        return PagedEventList(
          seniorMode: seniorMode,
          loadPage: _fetch,
          emptyState: TrukuEmptyState(
            icon: Icons.event_outlined,
            message: mode == EventListMode.liked ? '還沒有按讚任何活動' : '還沒有收藏任何活動',
            subtitle: '下拉重新整理，看看有沒有新活動。',
            seniorMode: seniorMode,
            scrollable: false,
          ),
          itemBuilder: (event, reload) => _EventListItem(
            event: event,
            seniorMode: seniorMode,
            // 在詳情頁取消收藏/按讚後返回，清單要重新整理，否則仍看得到
            // 已經取消的項目。
            onReturn: reload,
          ),
        );
      },
    );
  }
}

class _EventListItem extends StatelessWidget {
  final EventSummary event;
  final bool seniorMode;

  /// 從詳情頁返回時呼叫，讓清單重新整理。
  final VoidCallback onReturn;

  const _EventListItem({
    required this.event,
    required this.seniorMode,
    required this.onReturn,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        await Navigator.push(context, EventDetailScreen.route(event.id));
        onReturn();
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.creamDeep),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildInfo()),
            EventCoverThumb(url: event.coverImageUrl, seniorMode: seniorMode),
          ],
        ),
      ),
    );
  }

  Widget _buildInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          event.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.ink,
            fontSize: AppTypography.size(
              AppTypography.body,
              seniorMode: seniorMode,
            ),
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
                fontSize: AppTypography.size(
                  AppTypography.caption,
                  seniorMode: seniorMode,
                ),
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
                    fontSize: AppTypography.size(
                      AppTypography.caption,
                      seniorMode: seniorMode,
                    ),
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
                fontSize: AppTypography.size(
                  AppTypography.caption,
                  seniorMode: seniorMode,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
