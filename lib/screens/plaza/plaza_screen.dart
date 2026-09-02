import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../shared/widgets/truku_painters.dart';
import '../../shared/widgets/truku_widgets.dart';
import 'compose_screen.dart';

class PlazaScreen extends StatefulWidget {
  const PlazaScreen({super.key});

  @override
  State<PlazaScreen> createState() => _PlazaScreenState();
}

class _PlazaScreenState extends State<PlazaScreen> {
  int _tabIndex = 0;

  static const _posts = [
    _PostData(
      name: 'Lawa',
      sub: '富世部落 · 18 分鐘前',
      text: '剛讀到資料才知道，布洛灣在太魯閣語裡有「追蹤獵物的地方」的意思。下次去走步道時想帶著這個故事一起看。',
      tag: '文化筆記',
      likes: 37,
      comments: 8,
    ),
    _PostData(
      name: 'Sayun',
      sub: '銅門部落 · 2 小時前',
      text: '今晚的族語練習，我們用三句話介紹自己的部落。大家平常都怎麼跟家裡的長輩開話題呢？',
      tag: '族語練習',
      likes: 21,
      comments: 14,
    ),
    _PostData(
      name: 'Bakan',
      sub: '秀林鄉青年志工 · 昨天',
      text: '上週走讀聽到耆老說，以前山裡的路不只是往返的路，也連著部落、獵場和彼此的照應。想把這段話記下來。',
      tag: '走讀',
      likes: 68,
      comments: 11,
    ),
    _PostData(
      name: 'Mona',
      sub: '萬榮部落 · 昨天',
      text: '分享今天整理的織布練習照片：先把材料備好，再慢慢學圖紋。每一步都比想像中需要耐心。',
      tag: '工藝日常',
      likes: 43,
      comments: 7,
    ),
  ];

  static const _miniEvents = [
    _MiniEventData(
      month: 'SEP',
      day: '12',
      title: '布洛灣文化走讀',
      loc: '布洛灣臺地',
      count: 18,
      isPrimary: true,
    ),
    _MiniEventData(
      month: 'SEP',
      day: '20',
      title: '太魯閣語家庭練習夜',
      loc: '富世社區',
      count: 14,
      isPrimary: false,
    ),
    _MiniEventData(
      month: 'OCT',
      day: '03',
      title: '部落歌謠分享會',
      loc: '秀林鄉',
      count: 32,
      isPrimary: true,
    ),
  ];

  static const _events = [
    _EventData(
      month: 'SEP',
      day: '12',
      dayOfWeek: '週六',
      title: '布洛灣文化走讀',
      loc: '布洛灣臺地',
      time: '09:00 — 12:00',
      count: 18,
      max: 25,
      tag: '走讀',
      host: 'Alang 走讀團隊',
      desc: '從布洛灣臺地出發，認識地景、部落記憶與太魯閣族文化故事。',
      isPrimary: true,
      featured: true,
    ),
    _EventData(
      month: 'SEP',
      day: '20',
      dayOfWeek: '週日',
      title: '太魯閣語家庭練習夜',
      loc: '富世社區活動中心',
      time: '19:00 — 20:30',
      count: 14,
      max: 20,
      tag: '族語',
      host: 'Sayun',
      desc: '以日常問候、家人稱謂與自我介紹為主題的輕量練習。',
      isPrimary: false,
    ),
    _EventData(
      month: 'OCT',
      day: '03',
      dayOfWeek: '週六',
      title: '部落歌謠分享會',
      loc: '秀林鄉文化廣場',
      time: '18:30 — 20:30',
      count: 32,
      max: 45,
      tag: '音樂',
      host: 'Bakan',
      desc: '一起聽歌、學唱與分享歌謠記憶，歡迎親子同行。',
      isPrimary: true,
    ),
    _EventData(
      month: 'OCT',
      day: '10',
      dayOfWeek: '週六',
      title: '立霧溪故事線上讀書會',
      loc: 'Google Meet',
      time: '20:00 — 21:00',
      count: 11,
      max: 30,
      tag: '線上',
      host: 'Pisaw',
      desc: '從立霧溪流域的人文故事出發，聊聊我們想保存的部落記憶。',
      isPrimary: false,
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
          if (_tabIndex == 0) ...[
            SliverToBoxAdapter(child: _buildMiniEventCards()),
            SliverToBoxAdapter(child: _buildPostsSection()),
          ] else ...[
            SliverToBoxAdapter(child: _buildEventsSection()),
          ],
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
      child: Row(
        children: [
          _Tab(
            label: '動態',
            active: _tabIndex == 0,
            onTap: () => setState(() => _tabIndex = 0),
          ),
          const SizedBox(width: 24),
          _Tab(
            label: '活動',
            active: _tabIndex == 1,
            onTap: () => setState(() => _tabIndex = 1),
          ),
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
            itemCount: _miniEvents.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, i) => _MiniEventCard(event: _miniEvents[i]),
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

  Widget _buildEventsSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        children: [
          _FeaturedEventCard(event: _events[0]),
          const SizedBox(height: 14),
          Row(
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
          const SizedBox(height: 10),
          ..._events
              .skip(1)
              .map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _EventListTile(event: e),
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
  final bool active;
  final VoidCallback onTap;

  const _Tab({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              label,
              style: GoogleFonts.notoSerifTc(
                fontSize: 14,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                color: active ? AppColors.primary : AppColors.fog,
                letterSpacing: 1.5,
              ),
            ),
          ),
          if (active)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(height: 2, color: AppColors.primary),
            ),
        ],
      ),
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

class _MiniEventData {
  final String month, day, title, loc;
  final int count;
  final bool isPrimary;

  const _MiniEventData({
    required this.month,
    required this.day,
    required this.title,
    required this.loc,
    required this.count,
    required this.isPrimary,
  });
}

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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
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
              Text(
                '♡ ${post.likes}',
                style: const TextStyle(fontSize: 12, color: AppColors.fog),
              ),
              const SizedBox(width: 18),
              Text(
                '💬 ${post.comments}',
                style: const TextStyle(fontSize: 12, color: AppColors.fog),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── 近期活動小卡 ─────────────────────────────────────────────

class _MiniEventCard extends StatelessWidget {
  final _MiniEventData event;

  const _MiniEventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    return Container(
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
                      color: event.isPrimary
                          ? AppColors.primary
                          : AppColors.moss,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          event.month,
                          style: const TextStyle(
                            fontSize: 8,
                            color: AppColors.gold,
                            letterSpacing: 2.0,
                          ),
                        ),
                        Text(
                          event.day,
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
                          style: GoogleFonts.notoSerifTc(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.creamLight,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          event.loc,
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
                    '● ${event.count} 人報名',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.gold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.5),
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      '我要參加',
                      style: TextStyle(
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
    );
  }
}

// ── 精選活動大卡 ─────────────────────────────────────────────

class _FeaturedEventCard extends StatelessWidget {
  final _EventData event;

  const _FeaturedEventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
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
                          event.month,
                          style: const TextStyle(
                            fontSize: 8,
                            color: AppColors.gold,
                            letterSpacing: 3.0,
                          ),
                        ),
                        Text(
                          event.day,
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
                  event.title,
                  style: GoogleFonts.notoSerifTc(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                    color: AppColors.creamLight,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  event.desc,
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
                    const Icon(
                      Icons.access_time,
                      color: AppColors.gold,
                      size: 11,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      event.time,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.creamLight.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Icon(
                      Icons.location_on_outlined,
                      color: AppColors.gold,
                      size: 11,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      event.loc,
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
                              value: event.count / event.max,
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.15,
                              ),
                              valueColor: const AlwaysStoppedAnimation(
                                AppColors.gold,
                              ),
                              minHeight: 5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${event.count}/${event.max} 人 · 剩 ${event.max - event.count} 個名額',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.creamLight.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
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
    );
  }
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFAA3333,
                          ).withValues(alpha: 0.08),
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
                        const Icon(
                          Icons.person_outline,
                          size: 11,
                          color: AppColors.inkSoft,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${event.count}/${event.max}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.inkSoft,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
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
