// 活動搜尋：關鍵字／時間區間／部落，三者皆選填、可任意組合。
// range 篩「未來 N 內即將舉辦」，跟 videos/articles 篩「最近發布」語意相反。
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../models/event_model.dart';
import '../../models/tribe_model.dart';
import '../../services/event_service.dart';
import '../../shared/search_range.dart';
import '../../shared/widgets/tribe_picker_sheet.dart';
import 'event_detail_screen.dart';

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
  int _page = 1;
  bool _mayHaveMore = true;
  List<EventSummary> _events = [];
  bool _searched = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      _q = _controller.text.trim();
      _searched = true;
      _loading = true;
      _error = null;
      _page = 1;
    });
    try {
      final results = await EventService.searchEvents(
        q: _q,
        range: _range,
        tribeId: _tribe?.id,
        page: 1,
      );
      if (!mounted) return;
      setState(() {
        _events = results;
        _mayHaveMore = results.isNotEmpty;
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

  Future<void> _loadMore() async {
    if (_loadingMore || !_mayHaveMore) return;
    setState(() => _loadingMore = true);
    try {
      final results = await EventService.searchEvents(
        q: _q,
        range: _range,
        tribeId: _tribe?.id,
        page: _page + 1,
      );
      if (!mounted) return;
      setState(() {
        _events = [..._events, ...results];
        _page += 1;
        _mayHaveMore = results.isNotEmpty;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _pickTribe() async {
    final tribe = await showModalBottomSheet<Tribe>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const TribePickerSheet(),
    );
    if (tribe == null) return;
    setState(() => _tribe = tribe.id == kClearTribeId ? null : tribe);
    _search();
  }

  void _setRange(String? range) {
    setState(() => _range = _range == range ? null : range);
    _search();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamLight,
      appBar: AppBar(
        backgroundColor: AppColors.creamLight,
        elevation: 0,
        foregroundColor: AppColors.ink,
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _search(),
          decoration: const InputDecoration(
            hintText: '搜尋活動',
            border: InputBorder.none,
          ),
        ),
        actions: [
          IconButton(onPressed: _search, icon: const Icon(Icons.search)),
        ],
      ),
      body: Column(
        children: [
          _filterRow(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(_error!, style: const TextStyle(color: AppColors.fog)),
            ),
          if (!_searched && _error == null)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Text(
                '輸入關鍵字或選擇篩選條件開始搜尋',
                style: GoogleFonts.notoSerifTc(color: AppColors.fog),
              ),
            ),
          if (_searched) Expanded(child: _resultList()),
        ],
      ),
    );
  }

  Widget _filterRow() {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final r in SearchRange.values) _rangeChip(r),
          const SizedBox(width: 4),
          _tribeChip(),
        ],
      ),
    );
  }

  Widget _rangeChip(String range) {
    final selected = _range == range;
    return Padding(
      padding: const EdgeInsets.only(right: 8, top: 6, bottom: 6),
      child: ChoiceChip(
        label: Text(SearchRange.label(range)),
        selected: selected,
        showCheckmark: false,
        backgroundColor: AppColors.cream,
        selectedColor: AppColors.primary.withValues(alpha: 0.16),
        labelStyle: TextStyle(
          fontSize: 12,
          color: selected ? AppColors.primary : AppColors.inkSoft,
        ),
        side: BorderSide(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.45)
              : AppColors.creamDeep,
        ),
        onSelected: (_) => _setRange(range),
      ),
    );
  }

  Widget _tribeChip() {
    final selected = _tribe != null;
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 6),
      child: ActionChip(
        avatar: Icon(
          Icons.place_outlined,
          size: 16,
          color: selected ? AppColors.primary : AppColors.inkSoft,
        ),
        label: Text(_tribe?.name ?? '部落'),
        backgroundColor: AppColors.cream,
        labelStyle: TextStyle(
          fontSize: 12,
          color: selected ? AppColors.primary : AppColors.inkSoft,
        ),
        side: BorderSide(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.45)
              : AppColors.creamDeep,
        ),
        onPressed: _pickTribe,
      ),
    );
  }

  Widget _resultList() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_events.isEmpty) {
      return Center(
        child: Text('找不到符合的活動', style: TextStyle(color: AppColors.fog)),
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.extentAfter < 200) _loadMore();
        return false;
      },
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _events.length + (_mayHaveMore ? 1 : 0),
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
          return _EventResultTile(event: _events[i]);
        },
      ),
    );
  }
}

class _EventResultTile extends StatelessWidget {
  final EventSummary event;
  const _EventResultTile({required this.event});

  @override
  Widget build(BuildContext context) {
    final d = event.startsAt.toLocal();
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => EventDetailScreen(eventId: event.id)),
      ),
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
              width: 48,
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
                      style: const TextStyle(fontSize: 9, color: AppColors.gold),
                    ),
                    Text(
                      '${d.day}',
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
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: GoogleFonts.notoSerifTc(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${event.location ?? '線上'} · ${event.participantCount} 人報名',
                    style: const TextStyle(fontSize: 11, color: AppColors.fog),
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
