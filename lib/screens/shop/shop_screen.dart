import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../models/shop_item.dart';
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
            childAspectRatio: 0.72,
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

    String? actionLabel;
    VoidCallback? onAction;
    if (owned) {
      actionLabel = '配戴';
      onAction = () => _equipItem(item);
    } else if (locked == null) {
      // 兌換按鈕永遠顯示（只要未擁有且未鎖定），不因 millet < price 而隱藏，
      // 讓兌換流程在餘額不足時仍可觸及、顯示 INSUFFICIENT_BALANCE 提示。
      actionLabel = '兌換';
      onAction = () => _purchaseItem(item);
    }

    return _ShopItemCard(
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

/// 共用卡片：頭像與頭像框兩種商品都用這個 widget 呈現 owned / locked / price 三種視覺狀態，
/// 避免重複的圓形圖示 + 名稱 + 價格排版程式碼。
///
/// - [owned] 為 true：右上角顯示「已擁有」標籤；若提供 [actionLabel]（例如「配戴」）則額外顯示按鈕。
/// - [lockedText] 非 null：整張卡片降低透明度、右上角顯示鎖頭圖示、底部顯示解鎖條件文字，不可互動。
/// - 其餘情況（未擁有且未鎖定）：顯示價格；若提供 [actionLabel]（例如「兌換」）則顯示按鈕。
/// - [rarityColor] 非 null 時（頭像才有）依六色稀有度上色價格與副標；頭像框無此欄位。
class _ShopItemCard extends StatelessWidget {
  final String name;
  final String? subtitle;
  final int price;
  final bool isGold;
  final Color? rarityColor;
  final bool owned;
  final String? lockedText;
  final String? imageUrl;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _ShopItemCard({
    required this.name,
    required this.price,
    required this.isGold,
    required this.icon,
    this.subtitle,
    this.rarityColor,
    this.owned = false,
    this.lockedText,
    this.imageUrl,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = rarityColor ?? AppColors.primary;
    return Opacity(
      opacity: lockedText != null ? 0.55 : 1.0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isGold ? const Color(0xFF2A1A15) : AppColors.cream,
          border: Border.all(color: isGold ? AppColors.gold.withValues(alpha: 0.31) : accentColor.withValues(alpha: 0.35)),
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
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isGold ? AppColors.gold.withValues(alpha: 0.1) : AppColors.creamDeep,
                    ),
                    child: ClipOval(child: _buildItemImage()),
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
                if (subtitle != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    subtitle!,
                    style: TextStyle(fontSize: 9, color: isGold ? AppColors.gold : accentColor, letterSpacing: 1),
                  ),
                ],
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

  // image_url 理論上一律有值（真實 GCS 網址）；errorBuilder 只是網路載入失敗時的
  // 防禦性 fallback，不是本地素材 fallback。
  Widget _buildItemImage() {
    if (imageUrl == null) {
      return Icon(icon, size: 44, color: isGold ? AppColors.gold : AppColors.fog);
    }
    return Image.network(
      imageUrl!,
      width: 64,
      height: 52,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Icon(icon, size: 44, color: isGold ? AppColors.gold : AppColors.fog),
    );
  }
}
