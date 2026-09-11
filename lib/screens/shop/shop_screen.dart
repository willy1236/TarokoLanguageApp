import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../models/shop_item.dart';
import '../../models/user_model.dart';
import '../../services/shop_service.dart';
import '../../services/user_service.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../../shared/widgets/millet_coin_icon.dart';
import '../../shared/widgets/shop_item_card.dart';
import '../../shared/widgets/shop_shared.dart';
import '../../shared/widgets/truku_painters.dart';
import '../millet/millet_ledger_screen.dart';
import '../../core/constants/app_typography.dart';

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

class _ShopScreenState extends State<ShopScreen> {
  int _selectedCategory = _catAll;
  final List<String> _categories = ['全部', '頭像 Lukus', '頭像框', '已擁有'];

  UserModel? _user;
  bool _loadingUser = true;

  // 後端 GET /api/shop/items 的合併目錄（頭像＋頭像框，含 image_url／is_owned）；
  // null 代表尚未取得或取得失敗，此時不顯示商品區塊，只顯示商店其餘的基本介面
  // （餘額卡），避免顯示跟後端擁有狀態對不上的假資料。
  List<ShopItem>? _serverItems;

  /// 正在送出兌換／配戴請求的商品 id：await 期間 disable 該張卡片的按鈕，
  /// 避免連點造成重複扣點。
  final Set<String> _busyItemIds = {};

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadItems();
  }

  Future<void> _loadUser() async {
    try {
      final user = await UserService.fetchMe();
      if (!mounted) return;
      setState(() {
        _user = user;
        _loadingUser = false;
      });
    } catch (e) {
      // 讀取失敗時退回空白/預設 UserModel，避免整個商店頁面崩潰。
      debugPrint('ShopScreen._loadUser failed: $e');
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
    } catch (e) {
      // 取得失敗（含離線）：維持 null，商品區塊不顯示，不影響商店頁面其他部分。
      debugPrint('ShopScreen._loadItems failed: $e');
    }
  }

  Future<void> _confirmAndPurchase(ShopItem item) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '兌換確認',
      message: '確定要花 ${item.price} 小米兌換「${item.name}」嗎？',
      confirmText: '兌換',
    );
    if (!confirmed) return;
    await _purchaseItem(item);
  }

  Future<void> _purchaseItem(ShopItem item) async {
    if (_busyItemIds.contains(item.id)) return;
    setState(() => _busyItemIds.add(item.id));
    try {
      final updated = await ShopService.purchaseItem(item.id);
      if (!mounted) return;
      setState(() {
        final owned = item.type == 'frame'
            ? updated.ownedFrameIds.contains(item.id)
            : updated.ownedAvatarIds.contains(item.id);
        _user = owned
            ? updated
            : item.type == 'frame'
                ? updated.copyWith(
                    ownedFrameIds: [...updated.ownedFrameIds, item.id],
                  )
                : updated.copyWith(
                    ownedAvatarIds: [...updated.ownedAvatarIds, item.id],
                  );
        // 卡片的「已擁有／可兌換」與「已擁有」分頁都看 ShopItem.isOwned，
        // 不同步這裡的話買完仍顯示「兌換」且可以再點一次。
        _markOwnedLocally(item.id);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('兌換成功')));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      debugPrint('ShopScreen._purchaseItem failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('兌換失敗，請稍後再試')));
    } finally {
      if (mounted) setState(() => _busyItemIds.remove(item.id));
    }
  }

  /// 把目錄中該商品標記為已擁有。必須在 setState 內呼叫。
  void _markOwnedLocally(String itemId) {
    final items = _serverItems;
    if (items == null) return;
    _serverItems = [
      for (final i in items) i.id == itemId ? i.copyWith(isOwned: true) : i,
    ];
  }

  Future<void> _equipItem(ShopItem item) async {
    if (_busyItemIds.contains(item.id)) return;
    setState(() => _busyItemIds.add(item.id));
    final updated = await runShopAction(
      context,
      action: () => item.type == 'frame'
          ? ShopService.equipFrame(item.id)
          : ShopService.equipAvatar(item.id),
      successMessage: '已配戴',
      logTag: 'ShopScreen._equipItem',
    );
    if (!mounted) return;
    setState(() {
      if (updated != null) _user = updated;
      _busyItemIds.remove(item.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingUser) {
      return const Scaffold(
        backgroundColor: AppColors.creamLight,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final user =
        _user ?? UserModel(uid: 0, email: '', createdAt: DateTime.now());
    final showAvatars =
        _selectedCategory == _catAll ||
        _selectedCategory == _catAvatar ||
        _selectedCategory == _catOwned;
    final showFrames =
        _selectedCategory == _catAll ||
        _selectedCategory == _catFrame ||
        _selectedCategory == _catOwned;

    final onlyOwned = _selectedCategory == _catOwned;
    // 沒有本地 fallback：_serverItems 為 null（尚未取得或取得失敗）時直接是空清單，
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
            SliverToBoxAdapter(
              child: _buildItemSection(
                '頭像 Lukus',
                'lukus · 共 ${avatarList.length} 款',
                avatarList,
              ),
            ),
          if (showFrames && frameList.isNotEmpty)
            SliverToBoxAdapter(
              child: _buildItemSection(
                '頭像框',
                'rangi · 共 ${frameList.length} 款',
                frameList,
              ),
            ),
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
              child: CustomPaint(
                painter: TrukuWeavePainter(
                  color: AppColors.gold,
                  opacity: 1.0,
                  scale: 0.7,
                ),
              ),
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
                      child: const Icon(
                        Icons.chevron_left,
                        color: AppColors.creamLight,
                        size: 18,
                      ),
                    ),
                    Text(
                      'SAPAH SMPUNG · 小米商店',
                      style: AppTypography.latin(
                        fontStyle: FontStyle.italic,
                        fontSize: AppTypography.caption,
                        color: AppColors.gold,
                        letterSpacing: 4,
                      ),
                    ),
                    _circleBtn(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MilletLedgerScreen(),
                        ),
                      ),
                      child: const Icon(
                        Icons.access_time_rounded,
                        color: AppColors.creamLight,
                        size: 16,
                      ),
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
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.31),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 64,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppColors.gold.withValues(alpha: 0.25),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: const MilletCoinIcon(size: 42),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'BURAW · 我的小米',
                              style: AppTypography.latin(
                                fontStyle: FontStyle.italic,
                                fontSize: AppTypography.caption,
                                color: AppColors.gold,
                                letterSpacing: 3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${user.millet}',
                              style: AppTypography.serif(
                                fontSize: AppTypography.display30,
                                fontWeight: FontWeight.w700,
                                color: AppColors.creamLight,
                                letterSpacing: 1,
                                height: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
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

  Widget _buildCategories() {
    return ShopCategoryChips(
      labels: _categories,
      selected: _selectedCategory,
      onSelected: (i) => setState(() => _selectedCategory = i),
    );
  }

  Widget _buildItemSection(
    String title,
    String subtitle,
    List<ShopItem> items,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.serif(
              fontSize: AppTypography.bodyLarge,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: AppTypography.latin(
              fontStyle: FontStyle.italic,
              fontSize: AppTypography.micro,
              color: AppColors.fog,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 10),
          ShopItemGrid(
            children: items.map((item) => _buildItemCard(item)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(ShopItem item) {
    final isGold = item.rarity == 'gold';
    final rarityColor = rarityColors[item.rarity];
    final owned = item.isOwned;
    final locked = !owned && item.unlockCondition != null
        ? item.unlockCondition
        : null;
    final equipped = item.type == 'frame'
        ? _user?.frameId == item.id
        : _user?.avatarId == item.id;

    final busy = _busyItemIds.contains(item.id);

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
      subtitle: raritySubtitle(item),
      price: item.price,
      isGold: isGold,
      rarityColor: rarityColor,
      owned: owned,
      lockedText: locked,
      imageUrl: item.imageUrl,
      icon: item.type == 'frame' ? Icons.circle_outlined : Icons.face_rounded,
      actionLabel: busy ? '處理中…' : actionLabel,
      onAction: busy ? null : onAction,
    );
  }
}
