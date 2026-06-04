import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../shared/widgets/truku_painters.dart';
import 'video_waiting_screen.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  int _activeTopicIndex = 0;

  static const _topics = [
    ('日常問候', 'mhuway'),
    ('家人稱謂', 'qbsuran'),
    ('部落故事', 'kari rudan'),
    ('織布技藝', 'tminun'),
    ('山林知識', 'dgiyaq'),
  ];

  static const _rudans = [
    _RudanData('Bakan rudan', '銅門部落', 78, true, 124, ['日常問候', '部落故事'], true),
    _RudanData('Yudaw baki', '秀林部落', 82, true, 89, ['山林知識'], false),
    _RudanData('Iwan yaki', '富世部落', 71, false, 56, ['織布技藝'], true),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamLight,
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            _buildHeroCard(),
            _buildTopics(),
            _buildRudanList(),
            _buildRecentCall(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PGKALA · 互動',
            style: GoogleFonts.crimsonPro(
              fontStyle: FontStyle.italic,
              fontSize: 12,
              color: AppColors.fog,
              letterSpacing: 3.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '面對面，學族語',
            style: GoogleFonts.notoSerifTc(
              fontSize: 26,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            Container(
              color: AppColors.ink,
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // weave background
                  SizedBox(
                    height: 0,
                    child: OverflowBox(
                      maxHeight: double.infinity,
                      alignment: Alignment.topLeft,
                      child: SizedBox(
                        width: MediaQuery.of(context).size.width - 40,
                        height: 220,
                        child: Opacity(
                          opacity: 0.12,
                          child: CustomPaint(
                            painter: TrukuWeavePainter(
                              color: AppColors.gold,
                              opacity: 1.0,
                              scale: 0.7,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Text(
                    '1 ON 1 · KMSAPUH',
                    style: GoogleFonts.crimsonPro(
                      fontStyle: FontStyle.italic,
                      fontSize: 11,
                      color: AppColors.gold,
                      letterSpacing: 3.0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '和耆老一對一\n用族語聊 10 分鐘',
                    style: GoogleFonts.notoSerifTc(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppColors.creamLight,
                      height: 1.3,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '系統會幫你配對線上的 rudan',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.creamLight.withValues(alpha: 0.7),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildAvatarRow(),
                  const SizedBox(height: 16),
                  _buildStartButton(),
                ],
              ),
            ),
            // actual weave overlay
            Positioned.fill(
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0.12,
                  child: CustomPaint(
                    painter: TrukuWeavePainter(
                      color: AppColors.gold,
                      opacity: 1.0,
                      scale: 0.7,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarRow() {
    const initials = ['B', 'Y', 'P', 'S'];
    return Row(
      children: [
        SizedBox(
          width: 32.0 + (initials.length - 1) * 22.0,
          height: 32,
          child: Stack(
            children: List.generate(initials.length, (i) {
              return Positioned(
                left: i * 22.0,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i.isEven ? AppColors.primary : AppColors.moss,
                    border: Border.all(color: AppColors.ink, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initials[i],
                    style: GoogleFonts.notoSerifTc(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.gold,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(width: 10),
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.online,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '4 位 rudan 在線',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.creamLight.withValues(alpha: 0.85),
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStartButton() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const VideoWaitingScreen()),
      ),
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.gold,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CustomPaint(
              size: const Size(16, 16),
              painter: _VideoIconPainter(AppColors.ink),
            ),
            const SizedBox(width: 8),
            Text(
              '開始配對',
              style: GoogleFonts.notoSerifTc(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
                letterSpacing: 2.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopics() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '想聊什麼主題？',
            style: GoogleFonts.notoSerifTc(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(_topics.length, (i) {
              final active = i == _activeTopicIndex;
              return GestureDetector(
                onTap: () => setState(() => _activeTopicIndex = i),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: active ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: active
                        ? null
                        : Border.all(color: AppColors.creamDeep),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _topics[i].$1,
                        style: TextStyle(
                          fontSize: 12,
                          color: active ? AppColors.creamLight : AppColors.inkSoft,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '· ${_topics[i].$2}',
                        style: GoogleFonts.crimsonPro(
                          fontStyle: FontStyle.italic,
                          fontSize: 10,
                          color: (active ? AppColors.creamLight : AppColors.inkSoft)
                              .withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildRudanList() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '線上 rudan',
                style: GoogleFonts.notoSerifTc(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                  letterSpacing: 1.5,
                ),
              ),
              Text(
                '查看全部 →',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.primary,
                  letterSpacing: 2.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...List.generate(_rudans.length, (i) {
            return Padding(
              padding: EdgeInsets.only(bottom: i < _rudans.length - 1 ? 10 : 0),
              child: _RudanTile(data: _rudans[i], isAlt: !_rudans[i].isPrimary),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRecentCall() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '最近通話',
            style: GoogleFonts.notoSerifTc(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.cream,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.creamDeep),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.moss,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'P',
                    style: GoogleFonts.notoSerifTc(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.gold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pisaw baki',
                        style: GoogleFonts.notoSerifTc(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '昨天 · 12 分 28 秒 · 學了 8 個新詞',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.fog,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '再聊 →',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.primary,
                    letterSpacing: 2.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 耆老列表項目 ──────────────────────────────────────────────────────────────

class _RudanData {
  final String name;
  final String tribe;
  final int age;
  final bool online;
  final int calls;
  final List<String> themes;
  final bool isPrimary;

  const _RudanData(
    this.name,
    this.tribe,
    this.age,
    this.online,
    this.calls,
    this.themes,
    this.isPrimary,
  );
}

class _RudanTile extends StatelessWidget {
  final _RudanData data;
  final bool isAlt;

  const _RudanTile({required this.data, required this.isAlt});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.creamDeep),
      ),
      child: Row(
        children: [
          // Avatar with online dot
          SizedBox(
            width: 52,
            height: 52,
            child: Stack(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isAlt ? AppColors.moss : AppColors.primary,
                    border: Border.all(color: AppColors.gold, width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    data.name[0],
                    style: GoogleFonts.notoSerifTc(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.gold,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: data.online ? AppColors.online : AppColors.fog,
                      border: Border.all(color: AppColors.cream, width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.name,
                  style: GoogleFonts.notoSerifTc(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '${data.tribe} · ${data.age} 歲 · 已通話 ${data.calls} 次',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.fog,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 4,
                  children: data.themes.map((t) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        t,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.primary,
                          letterSpacing: 1.2,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Call/Reserve button
          GestureDetector(
            onTap: data.online
                ? () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const VideoWaitingScreen()),
                    )
                : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: data.online ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(18),
                border: data.online
                    ? null
                    : Border.all(color: AppColors.creamDeep),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (data.online) ...[
                    CustomPaint(
                      size: const Size(11, 11),
                      painter: _VideoIconPainter(AppColors.creamLight),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    data.online ? '通話' : '預約',
                    style: TextStyle(
                      fontSize: 11,
                      color: data.online ? AppColors.creamLight : AppColors.fog,
                      letterSpacing: 2.0,
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
}

// ─── 視訊 icon (M15 5 L20 3 V21 L15 19 H4 V5 Z) ───────────────────────────

class _VideoIconPainter extends CustomPainter {
  final Color color;
  const _VideoIconPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 15 / 24, h * 5 / 24)
      ..lineTo(w * 20 / 24, h * 3 / 24)
      ..lineTo(w * 20 / 24, h * 21 / 24)
      ..lineTo(w * 15 / 24, h * 19 / 24)
      ..lineTo(w * 15 / 24, h * 19 / 24)
      ..lineTo(w * 4 / 24, h * 19 / 24)
      ..lineTo(w * 4 / 24, h * 5 / 24)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_VideoIconPainter old) => old.color != color;
}
