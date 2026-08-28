import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../shared/widgets/truku_painters.dart';
import '../../models/event_model.dart';
import '../../services/event_service.dart';
import '../../services/senior_mode_controller.dart';
import 'event_bookmarks_screen.dart';
import 'event_compose_screen.dart';
import 'event_detail_screen.dart';
import 'event_notifications_screen.dart';
import 'event_search_screen.dart';

/// 活動列表 —— 真資料版（GET /api/events）。
/// 發起活動返回後自動刷新；下拉可重新整理。需登入（未登入 API 會 401 導回登入）。
class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  // 前兩顆對應後端 scope（全部=all、近期=upcoming，會重新打 API）；
  // 其餘為分類篩選（對應發起活動表單的分類清單），在目前已載入的 scope 資料上做前端篩選。
  static const _filters = ['全部', '近期', '族語', '走讀', '工藝', '線上', '音樂', '其他'];
  int _filterIndex = 0;
  String _scope = 'all';

  bool _loading = true;
  String? _error;
  List<EventSummary> _events = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final events = await EventService.fetchEvents(scope: _scope);
      if (!mounted) return;
      setState(() {
        _events = events;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _onFilterTap(int i) {
    final filter = _filters[i];
    if (filter == '全部' || filter == '近期') {
      setState(() {
        _filterIndex = i;
        _scope = filter == '全部' ? 'all' : 'upcoming';
      });
      _load();
    } else {
      setState(() => _filterIndex = i);
    }
  }

  List<EventSummary> get _filteredEvents {
    final filter = _filters[_filterIndex];
    if (filter == '全部' || filter == '近期') return _events;
    return _events.where((e) => e.category == filter).toList();
  }

  // 依分類配色（呼應發起活動表單的分類清單），純視覺區隔用。
  Color _categoryColor(String? category) {
    switch (category) {
      case '走讀':
      case '線上':
        return AppColors.moss;
      case '工藝':
        return AppColors.goldDeep;
      case '族語':
      case '音樂':
        return AppColors.primary;
      default:
        return AppColors.inkSoft;
    }
  }

  // ── 日期/時間格式（後端時間為 UTC，顯示轉本地）────────────────
  static const _months = [
    '1月',
    '2月',
    '3月',
    '4月',
    '5月',
    '6月',
    '7月',
    '8月',
    '9月',
    '10月',
    '11月',
    '12月',
  ];
  static const _weekdays = ['週一', '週二', '週三', '週四', '週五', '週六', '週日'];
  String _mon(DateTime d) => _months[d.month - 1];
  String _day(DateTime d) => d.day.toString().padLeft(2, '0');
  String _wd(DateTime d) => _weekdays[d.weekday - 1];
  String _time(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  String _statusLabel(EventSummary e) {
    if (e.isJoined) return '已報名';
    if (e.displayStatus == 'ended') return '已結束';
    if (e.displayStatus == 'cancelled') return '已取消';
    if (e.isFull) return '已額滿';
    if (e.registrationOpen) return '報名中';
    return '';
  }

  void _openCompose() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EventComposeScreen()),
    ).then((created) {
      if (created == true) _load(); // 成功發起才刷新列表
    });
  }

  void _openDetail(EventSummary e) {
    // 詳情頁自行以 eventId 打 GET /api/events/:id 取真資料（含發起人姓名、
    // isHost 判斷、報名狀態）。回來後刷新清單，反映報名/退出。
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EventDetailScreen(eventId: e.id)),
    ).then((_) {
      if (mounted) _load();
    });
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
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primary,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(seniorMode)),
            SliverToBoxAdapter(child: _buildFilterChips(seniorMode)),
            ..._buildContentSlivers(seniorMode),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildContentSlivers(bool seniorMode) {
    if (_loading) {
      return [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(top: 80),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          ),
        ),
      ];
    }
    if (_error != null) {
      return [SliverToBoxAdapter(child: _buildError(seniorMode))];
    }
    final events = _filteredEvents;
    if (events.isEmpty) {
      return [SliverToBoxAdapter(child: _buildEmpty(seniorMode))];
    }
    return [
      SliverToBoxAdapter(child: _buildFeaturedCard(events.first, seniorMode)),
      if (events.length > 1) SliverToBoxAdapter(child: _buildDivider()),
      SliverToBoxAdapter(child: _buildList(events, seniorMode)),
    ];
  }

  Widget _buildError(bool seniorMode) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 80, 20, 0),
      child: Column(
        children: [
          Icon(
            Icons.cloud_off,
            size: seniorMode ? 56 : 40,
            color: AppColors.fog,
          ),
          const SizedBox(height: 12),
          Text(
            '載入活動失敗\n$_error',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: seniorMode ? 18 : 13,
              color: AppColors.inkSoft,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _load,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: seniorMode ? 32 : 24,
                vertical: seniorMode ? 16 : 10,
              ),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '重試',
                style: GoogleFonts.notoSerifTc(
                  fontSize: seniorMode ? 18 : 13,
                  color: AppColors.creamLight,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(bool seniorMode) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 90, 20, 0),
      child: Column(
        children: [
          Icon(
            Icons.event_note_outlined,
            size: seniorMode ? 60 : 44,
            color: AppColors.fog,
          ),
          const SizedBox(height: 12),
          Text(
            '目前沒有活動',
            style: GoogleFonts.notoSerifTc(
              fontSize: seniorMode ? 22 : 16,
              color: AppColors.inkSoft,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '點右上角「發起」開一場部落聚會吧',
            style: TextStyle(
              fontSize: seniorMode ? 16 : 12,
              color: AppColors.fog,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool seniorMode) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SMRATUC · 活動',
                  style: GoogleFonts.crimsonPro(
                    fontStyle: FontStyle.italic,
                    fontSize: seniorMode ? 16 : 12,
                    color: AppColors.fog,
                    letterSpacing: 3.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '近期部落聚會',
                  style: GoogleFonts.notoSerifTc(
                    fontSize: seniorMode ? 32 : 26,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
          // 發起是主要動作放上排，三個次要入口收在它下面：
          // 全部擠在同一列時，標題可用的寬度會被壓到換行。
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _composeButton(seniorMode),
              const SizedBox(height: 2),
              _actionIcons(seniorMode),
            ],
          ),
        ],
      ),
    );
  }

  Widget _composeButton(bool seniorMode) => GestureDetector(
    onTap: _openCompose,
    child: Container(
      padding: EdgeInsets.symmetric(
        horizontal: seniorMode ? 20 : 16,
        vertical: seniorMode ? 14 : 10,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.add,
            color: AppColors.creamLight,
            size: seniorMode ? 20 : 14,
          ),
          const SizedBox(width: 6),
          Text(
            '發起',
            style: GoogleFonts.notoSerifTc(
              fontSize: seniorMode ? 18 : 13,
              fontWeight: FontWeight.w600,
              color: AppColors.creamLight,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _actionIcons(bool seniorMode) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        tooltip: '搜尋',
        visualDensity: VisualDensity.compact,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EventSearchScreen()),
        ),
        icon: Icon(
          Icons.search,
          color: AppColors.ink,
          size: seniorMode ? 24 : 20,
        ),
      ),
      IconButton(
        tooltip: '我收藏的活動',
        visualDensity: VisualDensity.compact,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EventBookmarksScreen()),
        ),
        icon: Icon(
          Icons.bookmark_border,
          color: AppColors.ink,
          size: seniorMode ? 24 : 20,
        ),
      ),
      IconButton(
        tooltip: '活動通知',
        visualDensity: VisualDensity.compact,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EventNotificationsScreen()),
        ),
        icon: Icon(
          Icons.notifications_none,
          color: AppColors.ink,
          size: seniorMode ? 24 : 20,
        ),
      ),
    ],
  );

  Widget _buildFilterChips(bool seniorMode) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: SizedBox(
        height: seniorMode ? 48 : 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: _filters.length,
          separatorBuilder: (context, i) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final active = _filterIndex == i;
            return GestureDetector(
              onTap: () => _onFilterTap(i),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: seniorMode ? 18 : 14,
                  vertical: seniorMode ? 12 : 7,
                ),
                decoration: BoxDecoration(
                  color: active ? AppColors.ink : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: active
                      ? null
                      : Border.all(color: AppColors.creamDeep),
                ),
                child: Text(
                  _filters[i],
                  style: TextStyle(
                    fontSize: seniorMode ? 16 : 12,
                    color: active ? AppColors.creamLight : AppColors.inkSoft,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
      child: Row(
        children: [
          const Expanded(child: Divider(color: AppColors.creamDeep)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              '更多活動',
              style: GoogleFonts.crimsonPro(
                fontStyle: FontStyle.italic,
                fontSize: 10,
                color: AppColors.fog,
                letterSpacing: 3.0,
              ),
            ),
          ),
          const Expanded(child: Divider(color: AppColors.creamDeep)),
        ],
      ),
    );
  }

  // ── 精選卡片（深色）──────────────────────────────────────────
  Widget _buildFeaturedCard(EventSummary e, bool seniorMode) {
    final d = e.startsAt.toLocal();
    final label = _statusLabel(e);
    return GestureDetector(
      onTap: () => _openDetail(e),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.ink,
            borderRadius: BorderRadius.circular(18),
          ),
          clipBehavior: Clip.hardEdge,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 120,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryDeep],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                    Opacity(
                      opacity: 0.25,
                      child: CustomPaint(
                        painter: TrukuWeavePainter(opacity: 1, scale: 0.7),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 46,
                      child: CustomPaint(
                        painter: TrukuMountainsPainter(
                          color: AppColors.ink,
                          opacity: 0.9,
                        ),
                      ),
                    ),
                    if (label.isNotEmpty)
                      Positioned(
                        top: 14,
                        left: 14,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.gold,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            label,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.ink,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 2.0,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      top: 14,
                      right: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.ink.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.gold.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _mon(d),
                              style: const TextStyle(
                                fontSize: 9,
                                color: AppColors.gold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              _day(d),
                              style: GoogleFonts.notoSerifTc(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.creamLight,
                                height: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.title,
                      style: GoogleFonts.notoSerifTc(
                        fontSize: seniorMode ? 26 : 19,
                        fontWeight: FontWeight.w600,
                        color: AppColors.creamLight,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        Icon(
                          Icons.access_time,
                          color: AppColors.gold,
                          size: seniorMode ? 18 : 11,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: Text(
                            '${_wd(d)} ${_time(d)}',
                            style: TextStyle(
                              fontSize: seniorMode ? 16 : 11,
                              color: AppColors.creamLight.withValues(
                                alpha: 0.85,
                              ),
                            ),
                          ),
                        ),
                        Icon(
                          Icons.location_on_outlined,
                          color: AppColors.gold,
                          size: seniorMode ? 18 : 11,
                        ),
                        Text(
                          e.location ?? '線上',
                          style: TextStyle(
                            fontSize: seniorMode ? 16 : 11,
                            color: AppColors.creamLight.withValues(
                              alpha: 0.85,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildFeaturedCapacityRow(e, seniorMode),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturedCapacityRow(EventSummary e, bool seniorMode) {
    final max = e.maxParticipants;
    final remaining = max == null
        ? null
        : (max - e.participantCount).clamp(0, max);
    final capacityText = max == null
        ? '${e.participantCount} 人報名 · 不限名額'
        : '${e.participantCount}/$max 人 · 剩 $remaining 個名額';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (max != null)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (e.participantCount / max).clamp(0, 1).toDouble(),
                    minHeight: 6,
                    backgroundColor: AppColors.inkSoft,
                    valueColor: const AlwaysStoppedAnimation(AppColors.gold),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  capacityText,
                  style: TextStyle(
                    fontSize: seniorMode ? 16 : 11,
                    color: AppColors.creamLight.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          )
        else
          Expanded(
            child: Text(
              capacityText,
              style: TextStyle(
                fontSize: seniorMode ? 16 : 11,
                color: AppColors.creamLight.withValues(alpha: 0.7),
              ),
            ),
          ),
        const SizedBox(width: 12),
        _buildCtaButton(e, seniorMode),
      ],
    );
  }

  Widget _buildCtaButton(EventSummary e, bool seniorMode) {
    String text;
    if (e.isJoined) {
      text = '已報名';
    } else if (e.displayStatus == 'ended') {
      text = '已結束';
    } else if (e.displayStatus == 'cancelled') {
      text = '已取消';
    } else if (e.isFull) {
      text = '已額滿';
    } else if (e.registrationOpen) {
      text = '我要參加';
    } else {
      text = '查看';
    }
    return GestureDetector(
      onTap: () => _openDetail(e),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: seniorMode ? 20 : 16,
          vertical: seniorMode ? 13 : 9,
        ),
        decoration: BoxDecoration(
          color: AppColors.gold,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          text,
          style: GoogleFonts.notoSerifTc(
            fontSize: seniorMode ? 17 : 12,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
      ),
    );
  }

  // ── 其餘活動列表 ─────────────────────────────────────────────
  Widget _buildList(List<EventSummary> events, bool seniorMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: events
            .skip(1)
            .map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildListTile(e, seniorMode),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildListTile(EventSummary e, bool seniorMode) {
    final d = e.startsAt.toLocal();
    final color = _categoryColor(e.category);
    final capacityText = e.maxParticipants == null
        ? '${e.participantCount} 人報名'
        : '${e.participantCount}/${e.maxParticipants}';
    return GestureDetector(
      onTap: () => _openDetail(e),
      child: Container(
        padding: EdgeInsets.all(seniorMode ? 16 : 12),
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.creamDeep),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: seniorMode ? 88 : 56,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _mon(d),
                      style: TextStyle(
                        fontSize: seniorMode ? 14 : 9,
                        color: AppColors.gold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      _day(d),
                      style: GoogleFonts.notoSerifTc(
                        fontSize: seniorMode ? 32 : 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.creamLight,
                        height: 1,
                      ),
                    ),
                    Text(
                      _wd(d),
                      style: TextStyle(
                        fontSize: seniorMode ? 14 : 9,
                        color: AppColors.creamLight.withValues(alpha: 0.7),
                        letterSpacing: 1.5,
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
                  if (e.category != null && !seniorMode)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        e.category!,
                        style: TextStyle(
                          fontSize: 9,
                          color: color,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  if (e.category != null && !seniorMode)
                    const SizedBox(height: 3),
                  Text(
                    e.title,
                    style: GoogleFonts.notoSerifTc(
                      fontSize: seniorMode ? 20 : 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${_time(d)} · ${e.location ?? '線上'}',
                    style: TextStyle(
                      fontSize: seniorMode ? 16 : 11,
                      color: AppColors.fog,
                      letterSpacing: 0.8,
                    ),
                  ),
                  SizedBox(height: seniorMode ? 12 : 8),
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: seniorMode ? 18 : 11,
                        color: AppColors.inkSoft,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        capacityText,
                        style: TextStyle(
                          fontSize: seniorMode ? 16 : 11,
                          color: AppColors.inkSoft,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: seniorMode ? 18 : 14,
                          vertical: seniorMode ? 10 : 6,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.primary),
                        ),
                        child: Text(
                          '查看',
                          style: TextStyle(
                            fontSize: seniorMode ? 16 : 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
