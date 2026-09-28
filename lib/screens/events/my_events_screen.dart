import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../services/event_service.dart';
import '../../services/senior_mode_controller.dart';
import 'event_detail_screen.dart';
import 'widgets/event_status_tile.dart';
import 'widgets/paged_event_list.dart';
import '../../shared/widgets/truku_empty_state.dart';
import '../../core/constants/app_typography.dart';
import '../../shared/widgets/app_back_button.dart';

/// 我發起的活動總表（GET /api/events/mine）。
///
/// 後端每筆只回：標題 / 開始時間 / effective_status（active｜ended｜cancelled）/
/// 參加人數。點進去看完整內容用 [EventDetailScreen]（fetch by id）。
class MyEventsScreen extends StatelessWidget {
  const MyEventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: seniorModeController,
      builder: (context, _) => _buildScaffold(seniorModeController.enabled),
    );
  }

  Widget _buildScaffold(bool seniorMode) {
    return Scaffold(
      backgroundColor: AppColors.creamLight,
      appBar: AppBar(
        leading: const AppBackButton(),
        backgroundColor: AppColors.creamLight,
        foregroundColor: AppColors.ink,
        elevation: 0,
        title: Text(
          '我發起的活動',
          style: AppTypography.serif(
            fontSize: AppTypography.size(
              AppTypography.subtitle,
              seniorMode: seniorMode,
            ),
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
      ),
      body: PagedEventList(
        seniorMode: seniorMode,
        loadPage: (cursor) => EventService.fetchMyEvents(cursor: cursor),
        emptyState: TrukuEmptyState(
          icon: Icons.event_outlined,
          message: '你還沒發起過活動',
          subtitle: '下拉重新整理，或到活動頁發起第一場活動。',
          seniorMode: seniorMode,
          scrollable: false,
        ),
        itemBuilder: (event, reload) => Builder(
          builder: (context) => EventStatusTile(
            event: event,
            seniorMode: seniorMode,
            onTap: () async {
              await Navigator.push(context, EventDetailScreen.route(event.id));
              reload(); // 從詳情頁回來（可能剛取消）刷新
            },
          ),
        ),
      ),
    );
  }
}
