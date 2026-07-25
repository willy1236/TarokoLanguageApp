import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../models/event_model.dart';
import '../../services/event_service.dart';
import 'event_detail_screen.dart';

/// 我發起的活動總表（GET /api/events/mine）。
///
/// 後端每筆只回：標題 / 開始時間 / effective_status（active｜ended｜cancelled）/
/// 參加人數。點進去看完整內容用 [EventDetailScreen]（fetch by id）。
class MyEventsScreen extends StatefulWidget {
  const MyEventsScreen({super.key});

  @override
  State<MyEventsScreen> createState() => _MyEventsScreenState();
}

class _MyEventsScreenState extends State<MyEventsScreen> {
  bool _loading = true;
  String? _error;
  List<EventSummary> _events = const [];

  static const _months = [
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
  ];

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
      final list = await EventService.fetchMyEvents();
      if (!mounted) return;
      setState(() {
        _events = list;
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

  ({String text, Color color}) _statusChip(EventSummary e) {
    switch (e.displayStatus) {
      case 'cancelled':
        return (text: '已取消', color: AppColors.dangerDark);
      case 'ended':
        return (text: '已結束', color: AppColors.fog);
      default:
        return (text: '進行中', color: AppColors.mossDeep);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamLight,
      appBar: AppBar(
        backgroundColor: AppColors.creamLight,
        foregroundColor: AppColors.ink,
        elevation: 0,
        title: Text('我發起的活動',
            style: GoogleFonts.notoSerifTc(
                fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink)),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primary,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_error != null) {
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 90),
            child: Column(
              children: [
                const Icon(Icons.cloud_off, size: 40, color: AppColors.fog),
                const SizedBox(height: 12),
                Text('載入失敗\n$_error',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: AppColors.inkSoft, height: 1.6)),
                const SizedBox(height: 16),
                Center(child: TextButton(onPressed: _load, child: const Text('重試'))),
              ],
            ),
          ),
        ],
      );
    }
    if (_events.isEmpty) {
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 100),
            child: Column(
              children: [
                const Icon(Icons.event_available_outlined, size: 44, color: AppColors.fog),
                const SizedBox(height: 12),
                Text('你還沒發起過活動',
                    style: GoogleFonts.notoSerifTc(fontSize: 16, color: AppColors.inkSoft)),
              ],
            ),
          ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      itemCount: _events.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _buildTile(_events[i]),
    );
  }

  Widget _buildTile(EventSummary e) {
    final d = e.startsAt.toLocal();
    final chip = _statusChip(e);
    String two(int n) => n.toString().padLeft(2, '0');
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => EventDetailScreen(eventId: e.id)),
        );
        _load(); // 從詳情頁回來（可能剛取消）刷新
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.creamDeep),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 52,
              child: Column(
                children: [
                  Text(_months[d.month - 1],
                      style: const TextStyle(
                          fontSize: 9, color: AppColors.primary, letterSpacing: 2.0)),
                  Text(two(d.day),
                      style: GoogleFonts.notoSerifTc(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                          height: 1.1)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.notoSerifTc(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.person_outline, size: 12, color: AppColors.inkSoft),
                      const SizedBox(width: 4),
                      Text('${e.participantCount} 人參加',
                          style: const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: chip.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(chip.text,
                  style: TextStyle(fontSize: 11, color: chip.color, letterSpacing: 0.5)),
            ),
          ],
        ),
      ),
    );
  }
}
