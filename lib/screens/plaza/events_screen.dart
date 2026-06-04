import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../shared/widgets/truku_painters.dart';
import 'compose_screen.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  int _filterIndex = 0;

  static const _filters = ['全部', '本月', '族語', '走讀', '工藝', '線上'];

  static const _events = [
    _EventData(
      month: 'JUN', day: '15', dayOfWeek: '週六', title: '青年族語營', loc: '秀林部落',
      time: '09:00 — 17:00', count: 23, max: 30, tag: '族語', host: 'Sayun Lowking',
      desc: '三天兩夜，跟著耆老學族語、織布、聽部落故事。', isPrimary: true, featured: true,
    ),
    _EventData(
      month: 'JUN', day: '22', dayOfWeek: '週六', title: '苧麻採集走讀', loc: '銅門部落',
      time: '06:00 — 12:00', count: 12, max: 20, tag: '走讀', host: 'Bakan Nawi',
      desc: '', isPrimary: false,
    ),
    _EventData(
      month: 'JUL', day: '03', dayOfWeek: '週日', title: '部落歌謠之夜', loc: '富世社區活動中心',
      time: '19:00 — 21:00', count: 41, max: 60, tag: '音樂', host: 'Pisaw baki',
      desc: '', isPrimary: true,
    ),
    _EventData(
      month: 'JUL', day: '12', dayOfWeek: '週六', title: '太魯閣語讀書會', loc: '線上',
      time: '20:00 — 21:30', count: 8, max: 15, tag: '線上', host: 'Yudaw',
      desc: '', isPrimary: false,
    ),
    _EventData(
      month: 'JUL', day: '20', dayOfWeek: '週日', title: '織布工坊體驗', loc: '銅門工藝坊',
      time: '13:00 — 17:00', count: 6, max: 10, tag: '工藝', host: 'Iwan yaki',
      desc: '', isPrimary: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamLight,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(context)),
          SliverToBoxAdapter(child: _buildFilterChips()),
          SliverToBoxAdapter(child: _buildFeaturedCard()),
          SliverToBoxAdapter(child: _buildDivider()),
          SliverToBoxAdapter(child: _buildEventList()),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SMRATUC · 活動',
                  style: GoogleFonts.crimsonPro(
                    fontStyle: FontStyle.italic,
                    fontSize: 12,
                    color: AppColors.fog,
                    letterSpacing: 3.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '近期部落聚會',
                  style: GoogleFonts.notoSerifTc(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ComposeScreen()),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add, color: AppColors.creamLight, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    '發起',
                    style: GoogleFonts.notoSerifTc(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.creamLight,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        itemCount: _filters.length,
        separatorBuilder: (context, i) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final active = _filterIndex == i;
          return GestureDetector(
            onTap: () => setState(() => _filterIndex = i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: active ? AppColors.ink : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: active ? null : Border.all(color: AppColors.creamDeep),
              ),
              child: Text(
                _filters[i],
                style: TextStyle(
                  fontSize: 12,
                  color: active ? AppColors.creamLight : AppColors.inkSoft,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeaturedCard() {
    final e = _events[0];
    return Padding(
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
            // 頂部視覺
            SizedBox(
              height: 130,
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
                    top: 14,
                    left: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.gold,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '編輯精選',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.ink,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2.5,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 14,
                    right: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.ink.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            e.month,
                            style: const TextStyle(
                              fontSize: 8,
                              color: AppColors.gold,
                              letterSpacing: 3.0,
                            ),
                          ),
                          Text(
                            e.day,
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
            // 內容
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.title,
                    style: GoogleFonts.notoSerifTc(
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                      color: AppColors.creamLight,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    e.desc,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.creamLight.withValues(alpha: 0.75),
                      height: 1.5,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.access_time, color: AppColors.gold, size: 11),
                      const SizedBox(width: 4),
                      Text(
                        e.time,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.creamLight.withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Icon(Icons.location_on_outlined, color: AppColors.gold, size: 11),
                      const SizedBox(width: 4),
                      Text(
                        e.loc,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.creamLight.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: e.count / e.max,
                                backgroundColor: Colors.white.withValues(alpha: 0.15),
                                valueColor: const AlwaysStoppedAnimation(AppColors.gold),
                                minHeight: 5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${e.count}/${e.max} 人 · 剩 ${e.max - e.count} 個名額',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.creamLight.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.gold,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Text(
                          '我要參加',
                          style: GoogleFonts.notoSerifTc(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                            letterSpacing: 1.5,
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

  Widget _buildEventList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: _events.skip(1).map((e) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _EventListTile(event: e),
        )).toList(),
      ),
    );
  }
}

// ── 資料模型 ──────────────────────────────────────────────────

class _EventData {
  final String month, day, dayOfWeek, title, loc, time, tag, host, desc;
  final int count, max;
  final bool isPrimary, featured;

  const _EventData({
    required this.month,
    required this.day,
    required this.dayOfWeek,
    required this.title,
    required this.loc,
    required this.time,
    required this.tag,
    required this.host,
    required this.desc,
    required this.count,
    required this.max,
    required this.isPrimary,
    this.featured = false,
  });
}

// ── 活動列表項目 ──────────────────────────────────────────────

class _EventListTile extends StatelessWidget {
  final _EventData event;

  const _EventListTile({required this.event});

  @override
  Widget build(BuildContext context) {
    final isNearlyFull = event.count / event.max > 0.7;
    return Container(
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
            width: 56,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: event.isPrimary ? AppColors.primary : AppColors.moss,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.18,
                      child: CustomPaint(
                        painter: TrukuWeavePainter(opacity: 1, scale: 0.3),
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        event.month,
                        style: const TextStyle(
                          fontSize: 9,
                          color: AppColors.gold,
                          letterSpacing: 2.5,
                        ),
                      ),
                      Text(
                        event.day,
                        style: GoogleFonts.notoSerifTc(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.creamLight,
                          height: 1,
                        ),
                      ),
                      Text(
                        event.dayOfWeek,
                        style: TextStyle(
                          fontSize: 9,
                          color: AppColors.creamLight.withValues(alpha: 0.7),
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        event.tag,
                        style: const TextStyle(
                          fontSize: 9,
                          color: AppColors.primary,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    if (isNearlyFull) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFAA3333).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Text(
                          '即將額滿',
                          style: TextStyle(
                            fontSize: 9,
                            color: Color(0xFFAA3333),
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  event.title,
                  style: GoogleFonts.notoSerifTc(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${event.time} · ${event.loc}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.fog,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person_outline, size: 11, color: AppColors.inkSoft),
                        const SizedBox(width: 4),
                        Text(
                          '${event.count}/${event.max}',
                          style: const TextStyle(fontSize: 11, color: AppColors.inkSoft),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.primary),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        '查看',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.primary,
                          letterSpacing: 1.0,
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
    );
  }
}
