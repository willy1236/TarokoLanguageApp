import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../shared/widgets/truku_painters.dart';

class CultureScreen extends StatefulWidget {
  const CultureScreen({super.key});

  @override
  State<CultureScreen> createState() => _CultureScreenState();
}

class _CultureScreenState extends State<CultureScreen> {
  int _tabIndex = 0; // 0=影音, 1=文章
  int _chipIndex = 0;

  static const _chips = ['全部', '口述歷史', '織布傳統', '祭儀', '部落音樂', '美食'];

  static const _videos = [
    _VideoItem('苧麻怎麼種', 'Yudaw', '6:20', '織布', true),
    _VideoItem('溪流命名史', 'Pisaw', '8:14', '地景', false),
    _VideoItem('小米播種祭', 'Sayun', '15:02', '祭儀', true),
    _VideoItem('老人家的歌', 'Bakan', '4:36', '音樂', false),
  ];

  static const _articles = [
    _ArticleItem('走過立霧溪——一條河的族語名字', 'Pisaw', '5 分鐘', '486', '地景', true),
    _ArticleItem('Gaya 不是規矩，是呼吸的方式', 'Yudaw', '12 分鐘', '892', '文化', false),
    _ArticleItem('阿公教我打獵那天說的話', 'Watan', '7 分鐘', '634', '口述', true),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.midnight,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHero()),
          SliverToBoxAdapter(child: _buildTabBar()),
          SliverToBoxAdapter(child: _buildChips()),
          SliverToBoxAdapter(child: _buildSectionHeader('最新影片', 'patas hngak · 共 24 部')),
          SliverToBoxAdapter(child: _buildVideoGrid()),
          SliverToBoxAdapter(child: _buildSectionHeader('族人寫的文章', 'patas kari · 共 18 篇')),
          SliverToBoxAdapter(child: _buildFeaturedArticle()),
          SliverToBoxAdapter(child: _buildArticleList()),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }

  // ── Hero ──────────────────────────────────────────────────────────────────

  Widget _buildHero() {
    return SizedBox(
      height: 360,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 漸層底色
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.mossDeep, AppColors.midnight],
              ),
            ),
          ),
          // 條紋占位
          CustomPaint(painter: _StripePainter()),
          // 織紋
          CustomPaint(
            painter: TrukuWeavePainter(
              color: AppColors.gold,
              opacity: 0.25,
              scale: 1.0,
            ),
          ),
          // 漸層遮罩
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.5, 1.0],
                colors: [Colors.transparent, Colors.transparent, AppColors.midnight],
              ),
            ),
          ),
          // 頂部 nav
          Positioned(
            top: 60,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'LNGLUNGAN',
                  style: GoogleFonts.crimsonPro(
                    fontStyle: FontStyle.italic,
                    fontSize: 13,
                    color: AppColors.gold,
                    letterSpacing: 4.0,
                  ),
                ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.4),
                    border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
                  ),
                  child: const Center(
                    child: _SearchIcon(),
                  ),
                ),
              ],
            ),
          ),
          // Hero info
          Positioned(
            bottom: 24,
            left: 20,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '本週精選 · GAYA',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    color: AppColors.gold,
                    letterSpacing: 4.0,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '紋面的故事——\n祖母的最後一道線',
                  style: GoogleFonts.notoSerifTc(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    color: AppColors.creamLight,
                    letterSpacing: 1.0,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '口述 · Bakan Nawi　|　12 分鐘',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.creamLight.withValues(alpha: 0.7),
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 14),
                _PlayButton(label: '立即觀看'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab Bar ───────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    final tabs = [
      ('影音', 'patas hngak'),
      ('文章', 'patas kari'),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.cream.withValues(alpha: 0.09), width: 1),
        ),
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final active = _tabIndex == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _tabIndex = i),
              behavior: HitTestBehavior.opaque,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      children: [
                        Text(
                          tabs[i].$1,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.notoSerifTc(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: active ? AppColors.gold : AppColors.fog,
                            letterSpacing: 2.0,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tabs[i].$2,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.crimsonPro(
                            fontStyle: FontStyle.italic,
                            fontSize: 10,
                            color: active
                                ? AppColors.cream.withValues(alpha: 0.7)
                                : AppColors.fog.withValues(alpha: 0.5),
                            letterSpacing: 2.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (active)
                    Positioned(
                      bottom: -1,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: FractionallySizedBox(
                          widthFactor: 0.6,
                          child: Container(height: 2, color: AppColors.gold),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Category Chips ────────────────────────────────────────────────────────

  Widget _buildChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: List.generate(_chips.length, (i) {
          final active = _chipIndex == i;
          return Padding(
            padding: EdgeInsets.only(right: i < _chips.length - 1 ? 8 : 0),
            child: GestureDetector(
              onTap: () => setState(() => _chipIndex = i),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: active ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: active
                      ? null
                      : Border.all(color: AppColors.cream.withValues(alpha: 0.19)),
                ),
                child: Text(
                  _chips[i],
                  style: TextStyle(
                    fontSize: 13,
                    color: active ? AppColors.creamLight : AppColors.cream,
                    letterSpacing: 2.0,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Section Header ────────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title, String sub) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.notoSerifTc(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.cream,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sub,
                style: GoogleFonts.crimsonPro(
                  fontStyle: FontStyle.italic,
                  fontSize: 10,
                  color: AppColors.fog,
                  letterSpacing: 3.6,
                ),
              ),
            ],
          ),
          Text(
            '查看全部 →',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.gold,
              letterSpacing: 2.4,
            ),
          ),
        ],
      ),
    );
  }

  // ── Video Grid ────────────────────────────────────────────────────────────

  Widget _buildVideoGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.78,
        children: _videos.map((v) => _VideoCard(item: v)).toList(),
      ),
    );
  }

  // ── Featured Article ──────────────────────────────────────────────────────

  Widget _buildFeaturedArticle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.midnightSoft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cream.withValues(alpha: 0.06)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 圖片區
            SizedBox(
              height: 120,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.primary, AppColors.primaryDeep],
                      ),
                    ),
                  ),
                  CustomPaint(
                    painter: TrukuWeavePainter(
                      color: AppColors.gold,
                      opacity: 0.25,
                      scale: 0.7,
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.gold,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '編輯精選',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.ink,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2.8,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 14,
                    left: 16,
                    right: 16,
                    child: Text(
                      '苧麻記事——\n祖母教我織布的那年夏天',
                      style: GoogleFonts.notoSerifTc(
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                        color: AppColors.creamLight,
                        letterSpacing: 1.0,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 作者列
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [AppColors.moss, AppColors.mossDeep],
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'S',
                        style: GoogleFonts.notoSerifTc(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.gold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sayun Lowking',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.cream,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '8 分鐘 · 1.2k 閱讀 · 3 天前',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.fog,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const _ArrowIcon(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Article List ──────────────────────────────────────────────────────────

  Widget _buildArticleList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: _articles
            .map((a) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ArticleCard(item: a),
                ))
            .toList(),
      ),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _PlayButton extends StatelessWidget {
  final String label;
  const _PlayButton({required this.label});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.gold,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _PlayIcon(size: 12, color: AppColors.ink),
            const SizedBox(width: 10),
            Text(
              label,
              style: GoogleFonts.notoSerifTc(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
                letterSpacing: 2.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoCard extends StatelessWidget {
  final _VideoItem item;
  const _VideoCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.midnightSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cream.withValues(alpha: 0.06)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 100,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: item.primaryTheme
                          ? [AppColors.primary, AppColors.primaryDeep]
                          : [AppColors.moss, AppColors.mossDeep],
                    ),
                  ),
                ),
                CustomPaint(
                  painter: TrukuWeavePainter(
                    color: AppColors.gold,
                    opacity: 0.3,
                    scale: 0.5,
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      item.tag,
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.gold,
                        letterSpacing: 2.4,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      item.duration,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        color: AppColors.creamLight,
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.5),
                      border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
                    ),
                    child: const Center(
                      child: _PlayIcon(size: 12, color: AppColors.gold),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: GoogleFonts.notoSerifTc(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.creamLight,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '@${item.author}',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.fog,
                    letterSpacing: 1.2,
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

class _ArticleCard extends StatelessWidget {
  final _ArticleItem item;
  const _ArticleCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.midnightSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cream.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: item.primaryTheme
                    ? [AppColors.moss, AppColors.mossDeep]
                    : [
                        AppColors.primary.withValues(alpha: 0.25),
                        AppColors.ink
                      ],
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(64, 64),
                  painter: TrukuWeavePainter(
                    color: AppColors.gold,
                    opacity: 0.4,
                    scale: 0.4,
                  ),
                ),
                Text(
                  '文',
                  style: GoogleFonts.notoSerifTc(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: AppColors.gold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    item.category,
                    style: TextStyle(
                      fontSize: 9,
                      color: AppColors.gold,
                      letterSpacing: 2.8,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.title,
                  style: GoogleFonts.notoSerifTc(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.creamLight,
                    letterSpacing: 0.5,
                    height: 1.35,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '@${item.author} · ${item.readTime} · ${item.views} 閱讀',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.fog,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const _ArrowIcon(),
        ],
      ),
    );
  }
}

// ─── Data Models ──────────────────────────────────────────────────────────────

class _VideoItem {
  final String title, author, duration, tag;
  final bool primaryTheme;
  const _VideoItem(this.title, this.author, this.duration, this.tag, this.primaryTheme);
}

class _ArticleItem {
  final String title, author, readTime, views, category;
  final bool primaryTheme;
  const _ArticleItem(this.title, this.author, this.readTime, this.views, this.category, this.primaryTheme);
}

// ─── Painters / Icons ─────────────────────────────────────────────────────────

class _StripePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.mossDeep.withValues(alpha: 0.6)
      ..strokeWidth = 0;

    const stripeWidth = 24.0;
    const gapWidth = 4.0;
    const period = stripeWidth + gapWidth;

    final path = Path();
    for (double x = -size.height; x < size.width + size.height; x += period) {
      path.addPolygon([
        Offset(x, 0),
        Offset(x + stripeWidth, 0),
        Offset(x + stripeWidth - size.height, size.height),
        Offset(x - size.height, size.height),
      ], true);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PlayIcon extends StatelessWidget {
  final double size;
  final Color color;
  const _PlayIcon({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _PlayIconPainter(color: color),
    );
  }
}

class _PlayIconPainter extends CustomPainter {
  final Color color;
  const _PlayIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SearchIcon extends StatelessWidget {
  const _SearchIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(16, 16),
      painter: _SearchIconPainter(),
    );
  }
}

class _SearchIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    // circle
    canvas.drawCircle(
      Offset(size.width * 0.46, size.height * 0.46),
      size.width * 0.29,
      paint,
    );
    // line
    final r = size.width * 0.29;
    final cx = size.width * 0.46;
    final cy = size.height * 0.46;
    final angle = math.pi * 0.75;
    final x1 = cx + r * math.cos(angle);
    final y1 = cy + r * math.sin(angle);
    canvas.drawLine(
      Offset(x1, y1),
      Offset(size.width * 0.88, size.height * 0.88),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ArrowIcon extends StatelessWidget {
  const _ArrowIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(16, 16),
      painter: _ArrowIconPainter(),
    );
  }
}

class _ArrowIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.fog
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(size.width * 0.2, size.height * 0.5)
      ..lineTo(size.width * 0.8, size.height * 0.5)
      ..moveTo(size.width * 0.53, size.height * 0.25)
      ..lineTo(size.width * 0.8, size.height * 0.5)
      ..lineTo(size.width * 0.53, size.height * 0.75);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
