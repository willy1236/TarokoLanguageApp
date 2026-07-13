import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../shared/widgets/truku_painters.dart';
import '../../services/shop_service.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  int _selectedCategory = 0;
  int _millet = 0;
  final List<String> _categories = ['全部', '彩徽 Btasil', '金徽 GOLD', '限定', '已擁有'];

  final List<_Badge> _featured = const [
    _Badge(name: '金徽·愛心', truku: 'Lukus Lhang', price: 280, rare: 'GOLD', isGold: true),
    _Badge(name: '青徽·愛戀', truku: 'Lukus Btasil', price: 120, rare: 'NEW', isGold: false),
  ];

  final List<_Badge> _colored = const [
    _Badge(name: '紅徽', truku: 'Lhang', price: 80),
    _Badge(name: '橙徽·歡', truku: 'Mqaras', price: 100, owned: true),
    _Badge(name: '黃徽·眨', truku: 'Mqita', price: 100),
    _Badge(name: '綠徽·笑', truku: 'Mngangah', price: 120),
    _Badge(name: '橙徽·靦', truku: 'Mqaras', price: 100),
    _Badge(name: '綠徽·星', truku: 'Bituq', price: 150),
    _Badge(name: '紅徽·食', truku: 'Mkan', price: 80),
    _Badge(name: '青徽·拳', truku: 'Mtgjiyax', price: 150),
  ];

  final List<_Badge> _gold = const [
    _Badge(name: '金徽·靜', truku: 'Smbabuy', price: 220, isGold: true),
    _Badge(name: '金徽·喜', truku: 'Mqaras', price: 220, isGold: true),
    _Badge(name: '金徽·泣', truku: 'Lmingis', price: 200, isGold: true, locked: '完成 5 單元解鎖'),
    _Badge(name: '金徽·笑', truku: 'Mngangah', price: 260, isGold: true),
    _Badge(name: '金徽·食', truku: 'Mkan', price: 200, isGold: true),
  ];

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    try {
      final millet = await ShopService.fetchBalance();
      if (mounted) setState(() => _millet = millet);
    } catch (_) {
      // The exchange request will display a user-facing error if it also fails.
    }
  }

  String? _productNameFor(_Badge badge) {
    switch (badge.truku) {
      case 'Lukus Lhang': return '金徽·愛心';
      case 'Lukus Btasil': return '青徽·愛戀';
      case 'Lhang': return '紅徽';
      case 'Mngangah' when badge.price == 120: return '綠徽·笑';
      case 'Smbabuy': return '金徽·靜';
      case 'Mqaras': return badge.isGold ? '金徽·喜' : null;
      default: return null;
    }
  }

  Future<void> _exchange(_Badge badge) async {
    final productName = _productNameFor(badge);
    if (productName == null) return;
    try {
      final millet = await ShopService.exchange(productName: productName, cost: badge.price);
      if (!mounted) return;
      setState(() => _millet = millet);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('兌換成功')));
    } on ApiException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('兌換失敗，請稍後再試')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamLight,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHero(context)),
          SliverToBoxAdapter(child: _buildCategories()),
          SliverToBoxAdapter(child: _buildFeaturedSection()),
          SliverToBoxAdapter(child: _buildBadgeSection('彩徽', 'btasil · 共 20 款', _colored, false)),
          SliverToBoxAdapter(child: _buildBadgeSection('金徽', 'rsuhug · 稀有款式', _gold, true)),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDeep],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.15,
              child: CustomPaint(painter: TrukuWeavePainter(color: AppColors.gold, opacity: 1.0, scale: 0.7)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 24),
            child: Column(
              children: [
                // 頂部列
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _circleBtn(
                      onTap: () => Navigator.of(context).pop(),
                      child: const Icon(Icons.chevron_left, color: AppColors.creamLight, size: 18),
                    ),
                    Text(
                      'SAPAH SMPUNG · 小米商店',
                      style: GoogleFonts.crimsonPro(
                        fontStyle: FontStyle.italic,
                        fontSize: 12,
                        color: AppColors.gold,
                        letterSpacing: 4,
                      ),
                    ),
                    _circleBtn(
                      child: const Icon(Icons.access_time_rounded, color: AppColors.creamLight, size: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                // 餘額卡
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.ink.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.gold.withValues(alpha: 0.31)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [AppColors.gold.withValues(alpha: 0.25), Colors.transparent],
                          ),
                        ),
                        child: const Icon(Icons.grain, size: 42, color: AppColors.gold),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'BURAW · 我的小米',
                              style: GoogleFonts.crimsonPro(
                                fontStyle: FontStyle.italic,
                                fontSize: 11,
                                color: AppColors.gold,
                                letterSpacing: 3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$_millet',
                              style: GoogleFonts.notoSerifTc(
                                fontSize: 30,
                                fontWeight: FontWeight.w700,
                                color: AppColors.creamLight,
                                letterSpacing: 1,
                                height: 1,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color: const Color(0xFF5BC97D).withValues(alpha: 0.15),
                                border: Border.all(color: const Color(0xFF5BC97D).withValues(alpha: 0.5)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.arrow_upward_rounded, size: 9, color: Color(0xFF7FE49A)),
                                  const SizedBox(width: 3),
                                  Text('今日 +20', style: TextStyle(fontSize: 10, color: const Color(0xFF7FE49A), letterSpacing: 1)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.gold),
                        ),
                        child: Text(
                          '賺取小米',
                          style: GoogleFonts.notoSerifTc(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.gold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // 賺取提示
                Row(
                  children: [
                    _earnChip('每日登入 +10'),
                    const SizedBox(width: 8),
                    _earnChip('完成單元 +10'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleBtn({VoidCallback? onTap, required Widget child}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.creamLight.withValues(alpha: 0.15),
        ),
        child: Center(child: child),
      ),
    );
  }

  Widget _earnChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: AppColors.creamLight.withValues(alpha: 0.08),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('●', style: TextStyle(color: AppColors.gold, fontSize: 8)),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 11, color: AppColors.creamLight.withValues(alpha: 0.85))),
        ],
      ),
    );
  }

  Widget _buildCategories() {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
        itemCount: _categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final active = i == _selectedCategory;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: active ? AppColors.ink : Colors.transparent,
                border: active ? null : Border.all(color: AppColors.creamDeep),
              ),
              child: Text(
                _categories[i],
                style: TextStyle(
                  fontSize: 12,
                  color: active ? AppColors.creamLight : AppColors.inkSoft,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  letterSpacing: 1,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeaturedSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('精選', style: GoogleFonts.notoSerifTc(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink, letterSpacing: 1)),
              Text('mkmali · 限時推薦', style: GoogleFonts.crimsonPro(fontStyle: FontStyle.italic, fontSize: 10, color: AppColors.fog, letterSpacing: 2)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: _featured.map((b) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: b == _featured.first ? 5 : 0, left: b == _featured.last ? 5 : 0),
                  child: _buildFeaturedCard(b),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedCard(_Badge badge) {
    return GestureDetector(
      onTap: () => _exchange(badge),
      child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: badge.isGold
              ? [const Color(0xFF2A1A15), AppColors.primaryDeep]
              : [AppColors.moss, AppColors.mossDeep],
        ),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.31)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.13,
              child: CustomPaint(painter: TrukuWeavePainter(color: AppColors.gold, opacity: 1.0, scale: 0.5)),
            ),
          ),
          if (badge.rare != null)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: badge.rare == 'GOLD' ? AppColors.gold : const Color(0xFF5BC97D),
                ),
                child: Text(badge.rare!, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.ink, letterSpacing: 2)),
              ),
            ),
          Column(
            children: [
              const SizedBox(height: 8),
              Center(
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.gold.withValues(alpha: 0.15),
                  ),
                  child: Icon(Icons.face_rounded, size: 60, color: badge.isGold ? AppColors.gold : AppColors.creamLight.withValues(alpha: 0.7)),
                ),
              ),
              const SizedBox(height: 10),
              Text(badge.name, style: GoogleFonts.notoSerifTc(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.creamLight, letterSpacing: 0.5)),
              const SizedBox(height: 1),
              Text(badge.truku, style: GoogleFonts.crimsonPro(fontStyle: FontStyle.italic, fontSize: 10, color: AppColors.gold, letterSpacing: 1.5)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), color: AppColors.gold),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.grain, size: 16, color: AppColors.ink),
                    const SizedBox(width: 4),
                    Text('${badge.price}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildBadgeSection(String title, String subtitle, List<_Badge> badges, bool isGold) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title, style: GoogleFonts.notoSerifTc(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink, letterSpacing: 1)),
                      if (isGold) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(3), color: AppColors.gold),
                          child: Text('GOLD', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.ink, letterSpacing: 2)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: GoogleFonts.crimsonPro(fontStyle: FontStyle.italic, fontSize: 10, color: AppColors.fog, letterSpacing: 2)),
                ],
              ),
              Text('查看全部 →', style: TextStyle(fontSize: 11, color: AppColors.primary, letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 10),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.72,
            children: badges
                .where((badge) => _productNameFor(badge) != null)
                .map((badge) => _buildBadgeCard(badge, isGold))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeCard(_Badge badge, bool isGold) {
    return GestureDetector(
      onTap: () => _exchange(badge),
      child: Opacity(
      opacity: badge.locked != null ? 0.55 : 1.0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isGold ? const Color(0xFF2A1A15) : AppColors.cream,
          border: Border.all(color: isGold ? AppColors.gold.withValues(alpha: 0.31) : AppColors.creamDeep),
        ),
        child: Stack(
          children: [
            if (badge.owned)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: const Color(0xFF5BC97D)),
                  child: Text('已擁有', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: AppColors.ink, letterSpacing: 1)),
                ),
              ),
            if (badge.locked != null)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withValues(alpha: 0.5)),
                  child: Icon(Icons.lock_outline_rounded, size: 10, color: AppColors.gold),
                ),
              ),
            Column(
              children: [
                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isGold ? AppColors.gold.withValues(alpha: 0.1) : AppColors.creamDeep,
                    ),
                    child: Icon(
                      Icons.face_rounded,
                      size: 44,
                      color: isGold ? AppColors.gold : AppColors.fog,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  badge.name,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.notoSerifTc(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isGold ? AppColors.creamLight : AppColors.ink,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.grain, size: 13, color: isGold ? AppColors.gold : AppColors.primary),
                    const SizedBox(width: 2),
                    Text(
                      '${badge.price}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isGold ? AppColors.gold : AppColors.primary,
                      ),
                    ),
                  ],
                ),
                if (badge.locked != null) ...[
                  const SizedBox(height: 4),
                  Text(badge.locked!, textAlign: TextAlign.center, style: TextStyle(fontSize: 9, color: AppColors.fog, letterSpacing: 0.5)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
    );
  }
}

class _Badge {
  final String name;
  final String truku;
  final int price;
  final String? rare;
  final bool isGold;
  final bool owned;
  final String? locked;

  const _Badge({
    required this.name,
    required this.truku,
    required this.price,
    this.rare,
    this.isGold = false,
    this.owned = false,
    this.locked,
  });
}
