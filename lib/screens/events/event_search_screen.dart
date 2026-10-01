// 活動搜尋：關鍵字／時間區間／部落，三者皆選填、可任意組合。
// range 篩「未來 N 內即將舉辦」，跟 videos/articles 篩「最近發布」語意相反。
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../models/event_model.dart';
import '../../models/page_info.dart';
import '../../models/tribe_model.dart';
import '../../services/event_service.dart';
import '../../services/senior_mode_controller.dart';
import '../../services/search_assist_service.dart';
import '../../shared/widgets/module_search_bar.dart';
import '../../shared/widgets/search_suggestions.dart';
import 'event_detail_screen.dart';
import 'widgets/event_cover.dart';

class EventSearchScreen extends StatefulWidget {
  const EventSearchScreen({super.key});

  @override
  State<EventSearchScreen> createState() => _EventSearchScreenState();
}

class _EventSearchScreenState extends State<EventSearchScreen> {
  final _controller = TextEditingController();
  String? _q;
  String? _range;
  Tribe? _tribe;

  bool _loading = false;
  bool _loadingMore = false;
  String? _error;
  String? _cursor;
  List<EventSummary> _events = [];
  bool _searched = false;

  /// 請求世代：每次新查詢遞增，回應套用前比對。快速切換篩選時，較晚送出但
  /// 先回應的舊查詢不能覆蓋新結果。
  int _reqGen = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final gen = ++_reqGen;
    setState(() {
      _q = _controller.text.trim();
      _searched = true;
      _loading = true;
      _loadingMore = false; // 飛行中的分頁請求已過期，不能再 append 進新清單
      _error = null;
      _cursor = null;
    });
    try {
      final result = await EventService.searchEvents(
        q: _q,
        range: _range,
        tribeId: _tribe?.id,
      );
      if (!mounted || gen != _reqGen) return;
      setState(() {
        _events = result.events;
        _cursor = result.pageInfo.nextCursor;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || gen != _reqGen) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  /// 封面網址過期：用上次送出的條件安靜地重查第一頁換新網址，不閃載入畫面；
  /// 失敗就保留原結果。不讀輸入框——使用者可能改了字還沒送出。
  Future<void> _refreshCovers() async {
    if (_loading) return;
    final gen = ++_reqGen; // 進行中的載入更多屬於舊結果，丟棄
    try {
      final result = await EventService.searchEvents(
        q: _q,
        range: _range,
        tribeId: _tribe?.id,
      );
      if (!mounted || gen != _reqGen) return;
      setState(() {
        _events = result.events;
        _cursor = result.pageInfo.nextCursor;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted && gen == _reqGen) setState(() => _loadingMore = false);
    }
  }

  Future<void> _loadMore() async {
    final cursor = _cursor;
    if (_loadingMore || cursor == null) return;
    final gen = _reqGen;
    setState(() => _loadingMore = true);
    try {
      final result = await EventService.searchEvents(
        q: _q,
        range: _range,
        tribeId: _tribe?.id,
        cursor: cursor,
      );
      if (!mounted || gen != _reqGen) return;
      setState(() {
        _events = appendUnique(_events, result.events, (e) => e.id);
        _cursor = result.pageInfo.nextCursor;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted && gen == _reqGen) setState(() => _loadingMore = false);
    }
  }

  void _onTribeSelected(Tribe? tribe) {
    setState(() => _tribe = tribe);
    _search();
  }

  void _setRange(String? range) {
    setState(() => _range = range);
    _search();
  }

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
      appBar: ModuleSearchAppBar(
        controller: _controller,
        hint: '搜尋活動',
        onSubmit: _search,
        palette: SearchBarPalette.light,
        seniorMode: seniorMode,
        titleFontSize: AppTypography.bodyLarge + AppTypography.seniorStep,
      ),
      body: Column(
        children: [
          ModuleSearchFilterRow(
            range: _range,
            onRangeSelected: _setRange,
            tribe: _tribe,
            onTribeSelected: _onTribeSelected,
            palette: SearchBarPalette.light,
            seniorMode: seniorMode,
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                _error!,
                style: TextStyle(
                  color: AppColors.fog,
                  fontSize: seniorMode
                      ? AppTypography.bodyLarge + AppTypography.seniorStep
                      : null,
                ),
              ),
            ),
          if (!_searched && _error == null)
            SearchSuggestions(
              module: SearchModule.events,
              palette: SearchBarPalette.light,
              seniorMode: seniorMode,
              placeholder: '輸入關鍵字或選擇篩選條件開始搜尋',
              onSelected: (q) {
                _controller.text = q;
                _search();
              },
            ),
          // 包在載入、空結果判斷外面，重新整理時冷卻狀態才不會跟著清掉。
          if (_searched)
            Expanded(
              child: EventCoverRefresher(
                onRefresh: _refreshCovers,
                child: _resultList(seniorMode),
              ),
            ),
        ],
      ),
    );
  }

  Widget _resultList(bool seniorMode) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_events.isEmpty) {
      return Center(
        child: Text(
          '找不到符合的活動',
          style: TextStyle(
            color: AppColors.fog,
            fontSize: seniorMode
                ? AppTypography.bodyLarge + AppTypography.seniorStep
                : null,
          ),
        ),
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.extentAfter < 200) _loadMore();
        return false;
      },
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _events.length + (_cursor != null ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          if (i >= _events.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            );
          }
          return _EventResultTile(event: _events[i], seniorMode: seniorMode);
        },
      ),
    );
  }
}

class _EventResultTile extends StatelessWidget {
  final EventSummary event;
  final bool seniorMode;
  const _EventResultTile({required this.event, required this.seniorMode});

  @override
  Widget build(BuildContext context) {
    final d = event.startsAt.toLocal();
    return GestureDetector(
      onTap: () => Navigator.push(context, EventDetailScreen.route(event.id)),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.creamDeep),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: seniorMode ? 76 : 48,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${d.month}月',
                      style: TextStyle(
                        fontSize: AppTypography.size(
                          AppTypography.micro,
                          seniorMode: seniorMode,
                        ),
                        color: AppColors.gold,
                      ),
                    ),
                    Text(
                      '${d.day}',
                      style: AppTypography.serif(
                        fontSize: AppTypography.size(
                          AppTypography.subtitle,
                          seniorMode: seniorMode,
                        ),
                        fontWeight: FontWeight.w700,
                        color: AppColors.creamLight,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: AppTypography.serif(
                      fontSize: AppTypography.size(
                        AppTypography.body,
                        seniorMode: seniorMode,
                      ),
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${event.location ?? '線上'} · ${event.participantCount} 人報名',
                    style: TextStyle(
                      fontSize: AppTypography.size(
                        AppTypography.caption,
                        seniorMode: seniorMode,
                      ),
                      color: AppColors.fog,
                    ),
                  ),
                ],
              ),
            ),
            EventCoverThumb(url: event.coverImageUrl, seniorMode: seniorMode),
          ],
        ),
      ),
    );
  }
}
