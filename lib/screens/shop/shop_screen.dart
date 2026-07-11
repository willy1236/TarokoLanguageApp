import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/avatar_catalog.dart';
import '../../models/user_model.dart';
import '../../services/shop_service.dart';
import '../../shared/widgets/truku_painters.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

/// 分類 chip 索引常數，讓 `_selectedCategory` 的比對有名字可讀。
const int _catAll = 0;
const int _catColored = 1;
const int _catGold = 2;
const int _catFeatured = 3;
const int _catOwned = 4;
const int _catAvatar = 5;

class _ShopScreenState extends State<ShopScreen> {
  int _selectedCategory = _catAll;
  final List<String> _categories = [
    '全部',
    '彩徽 Btasil',
    '金徽 GOLD',
    '限定',
    '已擁有',
    '頭像 Lukus',
  ];

  UserModel? _user;
  bool _loadingUser = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final user = await ShopService.fetchMe();
      if (!mounted) return;
      setState(() {
        _user = user;
        _loadingUser = false;
      });
    } catch (_) {
      // 讀取失敗時退回空白/預設 UserModel，避免整個商店頁面崩潰。
      if (!mounted) return;
      setState(() {
        _user = const UserModel(uid: '');
        _loadingUser = false;
      });
    }
  }

  Future<void> _purchaseAvatar(AvatarCatalogItem item) async {
    try {
      final updated = await ShopService.purchaseAvatar(item.id);
      if (!mounted) return;
      setState(() {
        _user = updated.ownedAvatarIds.contains(item.id)
            ? updated
            : updated.copyWith(
                ownedAvatarIds: [...updated.ownedAvatarIds, item.id],
              );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('兌換成功')),
      );
    } on ShopFeatureUnavailableException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('功能尚未開放')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('兌換失敗，請稍後再試')),
      );
    }
  }

  Future<void> _equipAvatar(AvatarCatalogItem item) async {
    try {
      final updated = await ShopService.equipAvatar(item.id);
      if (!mounted) return;
      setState(() {
        _user = updated.avatarId == item.id
            ? updated
            : updated.copyWith(avatarId: item.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已配戴')),
      );
    } on ShopFeatureUnavailableException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('功能尚未開放')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('配戴失敗，請稍後再試')),
      );
    }
  }

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
  Widget build(BuildContext context) {
    if (_loadingUser) {
      return const Scaffold(
        backgroundColor: AppColors.creamLight,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final user = _user ?? const UserModel(uid: '');
    final showFeatured = _selectedCategory == _catAll || _selectedCategory == _catFeatured;
    final showColored = _selectedCategory == _catAll || _selectedCategory == _catColored || _selectedCategory == _catOwned;
    final showGold = _selectedCategory == _catAll || _selectedCategory == _catGold || _selectedCategory == _catOwned;
    final showAvatars = _selectedCategory == _catAll || _selectedCategory == _catAvatar || _selectedCategory == _catOwned;

    final onlyOwned = _selectedCategory == _catOwned;
    final coloredList = onlyOwned ? _colored.where((b) => b.owned).toList() : _colored;
    final goldList = onlyOwned ? _gold.where((b) => b.owned).toList() : _gold;
    final avatarList = onlyOwned
        ? kAvatarCatalog.where((a) => user.ownedAvatarIds.contains(a.id)).toList()
        : kAvatarCatalog;

    return Scaffold(
      backgroundColor: AppColors.creamLight,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHero(context, user)),
          SliverToBoxAdapter(child: _buildCategories()),
          if (showFeatured) SliverToBoxAdapter(child: _buildFeaturedSection()),
          if (showColored && coloredList.isNotEmpty)
            SliverToBoxAdapter(child: _buildBadgeSection('彩徽', 'btasil · 共 20 款', coloredList, false)),
          if (showGold && goldList.isNotEmpty)
            SliverToBoxAdapter(child: _buildBadgeSection('金徽', 'rsuhug · 稀有款式', goldList, true)),
          if (showAvatars && avatarList.isNotEmpty)
            SliverToBoxAdapter(child: _buildAvatarSection(avatarList, user)),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildHero(BuildContext context, UserModel user) {
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
                              '${user.coins}',
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
    return Container(
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
            children: badges.map((b) => _buildBadgeCard(b, isGold)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeCard(_Badge badge, bool isGold) {
    return _ShopItemCard(
      name: badge.name,
      subtitle: badge.truku,
      price: badge.price,
      isGold: isGold,
      owned: badge.owned,
      lockedText: badge.locked,
      icon: Icons.face_rounded,
    );
  }

  Widget _buildAvatarSection(List<AvatarCatalogItem> avatars, UserModel user) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '頭像 Lukus',
            style: GoogleFonts.notoSerifTc(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink, letterSpacing: 1),
          ),
          const SizedBox(height: 2),
          Text(
            'lukus · 共 ${kAvatarCatalog.length} 款',
            style: GoogleFonts.crimsonPro(fontStyle: FontStyle.italic, fontSize: 10, color: AppColors.fog, letterSpacing: 2),
          ),
          const SizedBox(height: 10),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.72,
            children: avatars.map((a) => _buildAvatarCard(a, user)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarCard(AvatarCatalogItem item, UserModel user) {
    final isGold = item.rarity == 'gold';
    final owned = user.ownedAvatarIds.contains(item.id);
    final locked = !owned && item.unlockCondition != null ? item.unlockCondition : null;

    String? actionLabel;
    VoidCallback? onAction;
    if (owned) {
      actionLabel = '配戴';
      onAction = () => _equipAvatar(item);
    } else if (locked == null) {
      // 兌換按鈕永遠顯示（只要未擁有且未鎖定），不因 coins < price 而隱藏。
      // 目前真實後端不回傳 coins 欄位（預設為 0），若以 canAfford 當作顯示條件，
      // 按鈕會永遠不出現，導致整個兌換流程在正式環境中不可測試/不可觸及。
      // 點擊後仍會走正常兌換流程，未實作端點時會顯示「功能尚未開放」。
      actionLabel = '兌換';
      onAction = () => _purchaseAvatar(item);
    }

    return _ShopItemCard(
      name: item.name,
      subtitle: item.rarity.toUpperCase(),
      price: item.price,
      isGold: isGold,
      owned: owned,
      lockedText: locked,
      assetPath: item.assetPath,
      icon: Icons.face_rounded,
      actionLabel: actionLabel,
      onAction: onAction,
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

/// 共用卡片：徽章與頭像兩種商品都用這個 widget 呈現 owned / locked / price 三種視覺狀態，
/// 避免重複的圓形圖示 + 名稱 + 價格排版程式碼。
///
/// - [owned] 為 true：右上角顯示「已擁有」標籤；若提供 [actionLabel]（例如「配戴」）則額外顯示按鈕。
/// - [lockedText] 非 null：整張卡片降低透明度、右上角顯示鎖頭圖示、底部顯示解鎖條件文字，不可互動。
/// - 其餘情況（未擁有且未鎖定）：顯示價格；若提供 [actionLabel]（例如「兌換」）則顯示按鈕。
class _ShopItemCard extends StatelessWidget {
  final String name;
  final String subtitle;
  final int price;
  final bool isGold;
  final bool owned;
  final String? lockedText;
  final String? assetPath;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _ShopItemCard({
    required this.name,
    required this.subtitle,
    required this.price,
    required this.isGold,
    required this.icon,
    this.owned = false,
    this.lockedText,
    this.assetPath,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: lockedText != null ? 0.55 : 1.0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isGold ? const Color(0xFF2A1A15) : AppColors.cream,
          border: Border.all(color: isGold ? AppColors.gold.withValues(alpha: 0.31) : AppColors.creamDeep),
        ),
        child: Stack(
          children: [
            if (owned)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: const Color(0xFF5BC97D)),
                  child: Text('已擁有', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: AppColors.ink, letterSpacing: 1)),
                ),
              ),
            if (lockedText != null)
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
                    child: ClipOval(child: _buildAvatarImage()),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  name,
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
                      '$price',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isGold ? AppColors.gold : AppColors.primary,
                      ),
                    ),
                  ],
                ),
                if (lockedText != null) ...[
                  const SizedBox(height: 4),
                  Text(lockedText!, textAlign: TextAlign.center, style: TextStyle(fontSize: 9, color: AppColors.fog, letterSpacing: 0.5)),
                ],
                if (lockedText == null && actionLabel != null) ...[
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: onAction,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: AppColors.gold,
                      ),
                      child: Text(
                        actionLabel!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.ink),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarImage() {
    if (assetPath == null) {
      return Icon(icon, size: 44, color: isGold ? AppColors.gold : AppColors.fog);
    }
    return Image.asset(
      assetPath!,
      width: 64,
      height: 64,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Icon(icon, size: 44, color: isGold ? AppColors.gold : AppColors.fog),
    );
  }
}
