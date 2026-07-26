import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../models/event_model.dart';
import '../../services/event_service.dart';
import '../../shared/widgets/truku_widgets.dart';
import 'compose_screen.dart';
import '../events/event_detail_screen.dart';

class PlazaScreen extends StatefulWidget {
  const PlazaScreen({super.key});

  @override
  State<PlazaScreen> createState() => _PlazaScreenState();
}

class _PlazaScreenState extends State<PlazaScreen> {
  bool _eventsLoading = true;
  List<EventSummary> _events = [];

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    try {
      final events = await EventService.fetchEvents(scope: 'upcoming');
      if (!mounted) return;
      setState(() {
        _events = events;
        _eventsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _eventsLoading = false);
    }
  }

  void _openEventDetail(EventSummary e) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EventDetailScreen(eventId: e.id)),
    ).then((_) {
      if (mounted) _loadEvents();
    });
  }

  static const _posts = [
    _PostData(
      name: 'Sayun', sub: '銅門部落 · 3 小時前',
      text: '今天跟 yaki 學了「mhuway」這個詞，原來是「謝謝」也是「祝福」的意思 ✦',
      tag: 'Mhuway', likes: 24, comments: 6,
    ),
    _PostData(
      name: 'Pisaw', sub: '太管處青年志工 · 昨天',
      text: '誰知道立霧溪的族語怎麼念？我聽過長輩說 Yayung Bsngun 但不確定拼法...',
      tag: '求救', likes: 8, comments: 12,
    ),
    _PostData(
      name: 'Bakan', sub: '秀林部落 · 2 天前',
      text: '上週末跟著耆老去採苧麻，第一次看到整片山坡的青色，真的很美。',
      tag: '走讀', likes: 56, comments: 9,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamLight,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(context)),
          SliverToBoxAdapter(child: _buildTabBar()),
          if (!_eventsLoading && _events.isNotEmpty)
            SliverToBoxAdapter(child: _buildMiniEventCards()),
          SliverToBoxAdapter(child: _buildPostsSection()),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ALANG · 廣場',
                  style: GoogleFonts.crimsonPro(
                    fontStyle: FontStyle.italic,
                    fontSize: 12,
                    color: AppColors.fog,
                    letterSpacing: 3.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '族人在這裡',
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
                    '發布',
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

  Widget _buildTabBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.creamDeep)),
      ),
      child: const Row(
        children: [
          _Tab(label: '動態'),
        ],
      ),
    );
  }

  Widget _buildMiniEventCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Text(
            'SMRATUC · 近期活動',
            style: GoogleFonts.crimsonPro(
              fontStyle: FontStyle.italic,
              fontSize: 10,
              color: AppColors.fog,
              letterSpacing: 3.0,
            ),
          ),
        ),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            itemCount: _events.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, i) => _MiniEventCard(
              event: _events[i],
              onTap: () => _openEventDetail(_events[i]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPostsSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PATAS · 族人發文',
            style: GoogleFonts.crimsonPro(
              fontStyle: FontStyle.italic,
              fontSize: 10,
              color: AppColors.fog,
              letterSpacing: 3.0,
            ),
          ),
          const SizedBox(height: 10),
          ...List.generate(
            _posts.length,
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _PostCard(post: _posts[i], index: i),
            ),
          ),
        ],
      ),
    );
  }

}

// ── Tab 元件 ──────────────────────────────────────────────────

class _Tab extends StatelessWidget {
  final String label;

  const _Tab({required this.label});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            label,
            style: GoogleFonts.notoSerifTc(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
              letterSpacing: 1.5,
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(height: 2, color: AppColors.primary),
        ),
      ],
    );
  }
}

// ── 資料模型 ──────────────────────────────────────────────────

class _PostData {
  final String name, sub, text, tag;
  final int likes, comments;

  const _PostData({
    required this.name,
    required this.sub,
    required this.text,
    required this.tag,
    required this.likes,
    required this.comments,
  });
}

// ── 貼文卡片 ─────────────────────────────────────────────────

class _PostCard extends StatelessWidget {
  final _PostData post;
  final int index;

  const _PostCard({required this.post, required this.index});

  @override
  Widget build(BuildContext context) {
    final avatarColor = index % 2 == 0 ? AppColors.primary : AppColors.moss;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.creamDeep),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: avatarColor,
                  border: const Border.fromBorderSide(
                    BorderSide(color: AppColors.gold, width: 1.5),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  post.name[0],
                  style: GoogleFonts.notoSerifTc(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.gold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.name,
                      style: GoogleFonts.notoSerifTc(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                        letterSpacing: 0.6,
                      ),
                    ),
                    Text(
                      post.sub,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.fog,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '#${post.tag}',
                  style: GoogleFonts.crimsonPro(
                    fontStyle: FontStyle.italic,
                    fontSize: 11,
                    color: AppColors.primary,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            post.text,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.inkSoft,
              height: 1.55,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('♡ ${post.likes}', style: const TextStyle(fontSize: 12, color: AppColors.fog)),
              const SizedBox(width: 18),
              Text('💬 ${post.comments}', style: const TextStyle(fontSize: 12, color: AppColors.fog)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── 近期活動小卡 ─────────────────────────────────────────────

class _MiniEventCard extends StatelessWidget {
  final EventSummary event;
  final VoidCallback onTap;

  const _MiniEventCard({required this.event, required this.onTap});

  static const _months = [
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
  ];

  @override
  Widget build(BuildContext context) {
    final d = event.startsAt.toLocal();
    final month = _months[d.month - 1];
    final day = d.day.toString().padLeft(2, '0');
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -16,
              top: -16,
              child: Opacity(
                opacity: 0.13,
                child: TrukuDiamond(size: 80, color: AppColors.gold),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: event.isJoined ? AppColors.primary : AppColors.moss,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            month,
                            style: const TextStyle(
                              fontSize: 8,
                              color: AppColors.gold,
                              letterSpacing: 2.0,
                            ),
                          ),
                          Text(
                            day,
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
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.notoSerifTc(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.creamLight,
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            event.location ?? '線上',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.creamLight.withValues(alpha: 0.65),
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '● ${event.participantCount} 人報名',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.gold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        event.isJoined ? '已報名' : '我要參加',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.gold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

