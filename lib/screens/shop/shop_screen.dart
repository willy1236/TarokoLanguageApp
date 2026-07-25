import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../models/shop_item.dart';
import '../../models/user_model.dart';
import '../../services/shop_service.dart';
import '../../shared/widgets/shop_item_card.dart';
import '../../shared/widgets/truku_painters.dart';
import '../millet/millet_ledger_screen.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

/// 分類 chip 索引常數，讓 `_selectedCategory` 的比對有名字可讀。
const int _catAll = 0;
const int _catAvatar = 1;
const int _catFrame = 2;
const int _catOwned = 3;

/// 六色稀有度 → 顯示色與中文標籤；頭像框固定 rarity=null，不落在此表內。
const Map<String, Color> _rarityColors = {
  'red': AppColors.rose,
  'orange': AppColors.orangeLight,
  'yellow': AppColors.amber,
  'green': AppColors.greenLight,
  'blue': AppColors.blue,
  'gold': AppColors.gold,
};

const Map<String, String> _rarityLabels = {
  'red': '紅',
  'orange': '橙',
  'yellow': '黃',
  'green': '綠',
  'blue': '藍',
  'gold': '金',
};

class _ShopScreenState extends State<ShopScreen> {
  int _selectedCategory = _catAll;
  final List<String> _categories = ['全部', '頭像 Lukus', '頭像框', '已擁有'];

  UserModel? _user;
  bool _loadingUser = true;

  // 後端 GET /api/shop/items 的合併目錄（頭像＋頭像框，含 image_url／is_owned）；
  // null 代表尚未取得或功能尚未開放，此時不顯示商品區塊，只顯示商店其餘的基本介面
  // （餘額卡），避免顯示跟後端擁有狀態對不上的假資料。
  List<ShopItem>? _serverItems;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadItems();
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
        _user = UserModel(uid: 0, email: '', createdAt: DateTime.now());
        _loadingUser = false;
      });
    }
  }

  Future<void> _loadItems() async {
    try {
      final items = await ShopService.fetchShopItems();
      if (!mounted) return;
      setState(() => _serverItems = items);
    } catch (_) {
      // 功能尚未開放或發生錯誤：維持 null，商品區塊不顯示，不影響商店頁面其他部分。
    }
  }

  Future<void> _confirmAndPurchase(ShopItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('兌換確認'),
        content: Text('確定要花 ${item.price} 小米兌換「${item.name}」嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('兌換'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _purchaseItem(item);
  }

  Future<void> _purchaseItem(ShopItem item) async {
    try {
      final updated = await ShopService.purchaseItem(item.id);
      if (!mounted) return;
      setState(() {
        final owned = item.type == 'frame'
            ? updated.ownedFrameIds.contains(item.id)
            : updated.ownedAvatarIds.contains(item.id);
        if (owned) {
          _user = updated;
          return;
        }
        _user = item.type == 'frame'
            ? updated.copyWith(
                ownedFrameIds: [...updated.ownedFrameIds, item.id],
              )
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
    } on ShopApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('兌換失敗，請稍後再試')),
      );
    }
  }

  Future<void> _equipItem(ShopItem item) async {
    try {
      final updated = item.type == 'frame'
          ? await ShopService.equipFrame(item.id)
          : await ShopService.equipAvatar(item.id);
      if (!mounted) return;
      setState(() => _user = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已配戴')),
      );
    } on ShopFeatureUnavailableException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('功能尚未開放')),
      );
    } on ShopApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('配戴失敗，請稍後再試')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingUser) {
      return const Scaffold(
        backgroundColor: AppColors.creamLight,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final user = _user ?? UserModel(uid: 0, email: '', createdAt: DateTime.now());
    final showAvatars = _selectedCategory == _catAll || _selectedCategory == _catAvatar || _selectedCategory == _catOwned;
    final showFrames = _selectedCategory == _catAll || _selectedCategory == _catFrame || _selectedCategory == _catOwned;

    final onlyOwned = _selectedCategory == _catOwned;
    // 沒有本地 fallback：_serverItems 為 null（尚未取得或功能未開放）時直接是空清單，
    // 下面 isNotEmpty 判斷會讓對應區塊不顯示。
    final allItems = _serverItems ?? const <ShopItem>[];
    var avatarList = allItems.where((i) => i.type == 'avatar').toList();
    var frameList = allItems.where((i) => i.type == 'frame').toList();
    if (onlyOwned) {
      avatarList = avatarList.where((i) => i.isOwned).toList();
      frameList = frameList.where((i) => i.isOwned).toList();
    }

    return Scaffold(
      backgroundColor: AppColors.creamLight,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHero(context, user)),
          SliverToBoxAdapter(child: _buildCategories()),
          if (showAvatars && avatarList.isNotEmpty)
            SliverToBoxAdapter(child: _buildItemSection('頭像 Lukus', 'lukus · 共 ${avatarList.length} 款', avatarList)),
          if (showFrames && frameList.isNotEmpty)
            SliverToBoxAdapter(child: _buildItemSection('頭像框', 'rangi · 共 ${frameList.length} 款', frameList)),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildHero(BuildContext context, UserModel user) {
    return Container(
      clipBehavior: Clip.hardEdge,
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
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const MilletLedgerScreen()),
                      ),
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
                        height: 52,
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
                              '${user.millet}',
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
                                  Text('每日簽到 +50', style: TextStyle(fontSize: 10, color: const Color(0xFF7FE49A), letterSpacing: 1)),
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
                    _earnChip('每日簽到 +50'),
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
      height: 64,
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

  Widget _buildItemSection(String title, String subtitle, List<ShopItem> items) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.notoSerifTc(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink, letterSpacing: 1),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.crimsonPro(fontStyle: FontStyle.italic, fontSize: 10, color: AppColors.fog, letterSpacing: 2),
          ),
          const SizedBox(height: 10),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.66,
            children: items.map((item) => _buildItemCard(item)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(ShopItem item) {
    final isGold = item.rarity == 'gold';
    final rarityColor = _rarityColors[item.rarity];
    final owned = item.isOwned;
    final locked = !owned && item.unlockCondition != null ? item.unlockCondition : null;
    final equipped = item.type == 'frame' ? _user?.frameId == item.id : _user?.avatarId == item.id;

    String? actionLabel;
    VoidCallback? onAction;
    if (owned && equipped) {
      actionLabel = '已配戴';
      onAction = null;
    } else if (owned) {
      actionLabel = '配戴';
      onAction = () => _equipItem(item);
    } else if (locked == null) {
      // 兌換按鈕永遠顯示（只要未擁有且未鎖定），不因 millet < price 而隱藏，
      // 讓兌換流程在餘額不足時仍可觸及、顯示 INSUFFICIENT_BALANCE 提示。
      actionLabel = '兌換';
      onAction = () => _confirmAndPurchase(item);
    }

    return ShopItemCard(
      name: item.name,
      subtitle: item.rarity != null ? _rarityLabels[item.rarity] ?? item.rarity! : null,
      price: item.price,
      isGold: isGold,
      rarityColor: rarityColor,
      owned: owned,
      lockedText: locked,
      imageUrl: item.imageUrl,
      icon: item.type == 'frame' ? Icons.circle_outlined : Icons.face_rounded,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }
}
