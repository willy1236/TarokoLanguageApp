import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../services/event_service.dart';
import '../../services/fcm_service.dart';
import '../../services/senior_mode_controller.dart';
import '../../shared/widgets/app_back_button.dart';
import '../../shared/widgets/truku_empty_state.dart';
import 'event_detail_screen.dart';
import 'widgets/event_status_tile.dart';
import 'widgets/paged_event_list.dart';

/// 我參加的活動（GET /api/events/joined，含自己發起的）。活動開始後就不在活動
/// 列表裡，使用者從這裡找回自己報名的活動。
///   進行中：即將開始與進行中，開始時間升冪
///   結束：已結束與已取消，開始時間降冪
class JoinedEventsScreen extends StatefulWidget {
  const JoinedEventsScreen({super.key});

  @override
  State<JoinedEventsScreen> createState() => _JoinedEventsScreenState();
}

class _ReloadSignal extends ChangeNotifier {
  void fire() => notifyListeners();
}

class _JoinedEventsScreenState extends State<JoinedEventsScreen> {
  final _reloadSignal = _ReloadSignal();

  @override
  void initState() {
    super.initState();
    FcmService.addEventDeletedListener(_onEventDeleted);
  }

  @override
  void dispose() {
    FcmService.removeEventDeletedListener(_onEventDeleted);
    _reloadSignal.dispose();
    super.dispose();
  }

  /// 報名的活動被發起人刪除：兩個分頁都重載，該活動就會消失。
  void _onEventDeleted(int? eventId) {
    if (mounted) _reloadSignal.fire();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: seniorModeController,
      builder: (context, _) => _buildScaffold(seniorModeController.enabled),
    );
  }

  Widget _buildScaffold(bool seniorMode) {
    final tabStyle = AppTypography.bodyLargeStyle(seniorMode: seniorMode);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.creamLight,
        appBar: AppBar(
          leading: const AppBackButton(),
          backgroundColor: AppColors.creamLight,
          foregroundColor: AppColors.ink,
          elevation: 0,
          title: Text(
            '我參加的活動',
            style: AppTypography.serif(
              fontSize: AppTypography.size(
                AppTypography.subtitle,
                seniorMode: seniorMode,
              ),
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          bottom: TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.inkSoft,
            indicatorColor: AppColors.primary,
            labelStyle: tabStyle,
            unselectedLabelStyle: tabStyle,
            tabs: const [
              Tab(text: '進行中'),
              Tab(text: '結束'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _JoinedEventsTab(
              tab: 'active',
              seniorMode: seniorMode,
              emptyMessage: '目前沒有即將開始或進行中的活動',
              reloadSignal: _reloadSignal,
            ),
            _JoinedEventsTab(
              tab: 'ended',
              seniorMode: seniorMode,
              emptyMessage: '還沒有已結束的活動',
              reloadSignal: _reloadSignal,
            ),
          ],
        ),
      ),
    );
  }
}

class _JoinedEventsTab extends StatelessWidget {
  final String tab;
  final bool seniorMode;
  final String emptyMessage;
  final Listenable reloadSignal;

  const _JoinedEventsTab({
    required this.tab,
    required this.seniorMode,
    required this.emptyMessage,
    required this.reloadSignal,
  });

  @override
  Widget build(BuildContext context) {
    return PagedEventList(
      seniorMode: seniorMode,
      reloadSignal: reloadSignal,
      loadPage: (cursor) =>
          EventService.fetchJoinedEvents(tab: tab, cursor: cursor),
      emptyState: TrukuEmptyState(
        icon: Icons.event_outlined,
        message: emptyMessage,
        subtitle: '報名的活動會出現在這裡。',
        seniorMode: seniorMode,
        scrollable: false,
      ),
      itemBuilder: (event, reload) => EventStatusTile(
        event: event,
        seniorMode: seniorMode,
        upcomingLabel: '即將開始',
        showHostBadge: event.isHost,
        onTap: () async {
          final changed = await Navigator.push<bool>(
            context,
            EventDetailScreen.route<bool>(event.id),
          );
          // 在詳情頁退出、取消或編輯過才重載；沒動就留在原本捲到的位置。
          if (changed == true) reload();
        },
      ),
    );
  }
}
