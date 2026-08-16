import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../models/shop_item.dart';
import '../../models/user_model.dart';
import '../../services/shop_service.dart';
import '../../services/user_service.dart';
import '../../shared/widgets/shop_item_card.dart';
import '../../shared/widgets/truku_painters.dart';
import '../shop/shop_screen.dart';

/// 統一查看已擁有頭像／頭像框的背包頁，並可在此直接配戴。
/// 取代原本散落在個人資料頁的頭像/頭像框選擇區塊。
class BackpackScreen extends StatefulWidget {
  const BackpackScreen({super.key});

  @override
  State<BackpackScreen> createState() => _BackpackScreenState();
}

const int _catAll = 0;
const int _catAvatar = 1;
const int _catFrame = 2;

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

class _BackpackScreenState extends State<BackpackScreen> {
  int _selectedCategory = _catAll;
  final List<String> _categories = ['全部', '頭像 Lukus', '頭像框'];

  UserModel? _user;
  bool _loading = true;
  List<ShopItem>? _serverItems;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final user = await UserService.fetchMe();
      final items = await ShopService.fetchShopItems();
      if (!mounted) return;
      setState(() {
        _user = user;
        _serverItems = items;
        _loading = false;
      });
    } catch (e) {
      // 讀取失敗時維持空清單，只顯示基本介面，不讓整頁崩潰。
      debugPrint('BackpackScreen._load failed: $e');
      if (!mounted) return;
      setState(() => _loading = false);
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
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      debugPrint('BackpackScreen._equipItem failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('配戴失敗，請稍後再試')),
      );
    }
  }

  /// 恢復顯示預設（登入帳號）頭貼，對應 _user?.avatarId == null 的狀態。
  Future<void> _setDefaultAvatar() async {
    try {
      final updated = await ShopService.clearAvatar();
      if (!mounted) return;
      setState(() => _user = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已恢復預設頭貼')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      debugPrint('BackpackScreen._setDefaultAvatar failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('配戴失敗，請稍後再試')),
      );
    }
  }

  /// 取消配戴頭像框，對應 _user?.frameId == null 的狀態。
  Future<void> _clearFrame() async {
    try {
      final updated = await ShopService.clearFrame();
      if (!mounted) return;
      setState(() => _user = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已取消配戴頭像框')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      debugPrint('BackpackScreen._clearFrame failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('配戴失敗，請稍後再試')),
      );
    }
  }

  Future<void> _openShop() async {
    await Navigator.of(context).push(
      MaterialPageRoute<UserModel?>(builder: (_) => const ShopScreen()),
    );
    if (!mounted) return;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.creamLight,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final ownedItems = (_serverItems ?? const <ShopItem>[]).where((i) => i.isOwned).toList();
    final showAvatars = _selectedCategory == _catAll || _selectedCategory == _catAvatar;
    final showFrames = _selectedCategory == _catAll || _selectedCategory == _catFrame;
    final avatarList = ownedItems.where((i) => i.type == 'avatar').toList();
    final frameList = ownedItems.where((i) => i.type == 'frame').toList();

    return Scaffold(
      backgroundColor: AppColors.creamLight,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHero(context)),
          SliverToBoxAdapter(child: _buildCategories()),
          if (showAvatars) SliverToBoxAdapter(child: _buildAvatarSection(avatarList)),
          if (showFrames) SliverToBoxAdapter(child: _buildFrameSection(frameList)),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.creamLight.withValues(alpha: 0.15),
                    ),
                    child: const Icon(Icons.chevron_left, color: AppColors.creamLight, size: 18),
                  ),
                ),
                Text(
                  'PATAS · 我的背包',
                  style: GoogleFonts.crimsonPro(
                    fontStyle: FontStyle.italic,
                    fontSize: 12,
                    color: AppColors.gold,
                    letterSpacing: 4,
                  ),
                ),
                GestureDetector(
                  onTap: _openShop,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.creamLight.withValues(alpha: 0.15),
                    ),
                    child: const Icon(Icons.storefront_outlined, color: AppColors.creamLight, size: 16),
                  ),
                ),
              ],
            ),
          ),
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

  /// 頭像分類固定在第一格顯示「預設頭貼」（對應 avatarId == null，顯示登入帳號頭像），
  /// 讓使用者在沒配戴任何內建頭像時，背包裡仍能看到目前實際生效的狀態並可切回它。
  Widget _buildAvatarSection(List<ShopItem> items) {
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
            'lukus · 共 ${items.length + 1} 款',
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
            children: [
              _buildDefaultAvatarCard(),
              ...items.map((item) => _buildItemCard(item)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatarCard() {
    final equipped = _user?.avatarId == null;
    return ShopItemCard(
      name: '預設頭貼',
      price: 0,
      isGold: false,
      icon: Icons.person,
      owned: true,
      imageUrl: _user?.avatarUrl,
      showPrice: false,
      actionLabel: equipped ? '已配戴' : '設為預設',
      onAction: equipped ? null : _setDefaultAvatar,
    );
  }

  /// 頭像框分類固定在第一格顯示「不配戴」（對應 frameId == null，維持純頭像圓形無框），
  /// 讓使用者在沒配戴任何頭像框時，背包裡仍能看到目前實際生效的狀態並可切回它。
  Widget _buildFrameSection(List<ShopItem> items) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '頭像框',
            style: GoogleFonts.notoSerifTc(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink, letterSpacing: 1),
          ),
          const SizedBox(height: 2),
          Text(
            'rangi · 共 ${items.length + 1} 款',
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
            children: [
              _buildDefaultFrameCard(),
              ...items.map((item) => _buildItemCard(item)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultFrameCard() {
    final equipped = _user?.frameId == null;
    return ShopItemCard(
      name: '不配戴',
      price: 0,
      isGold: false,
      icon: Icons.circle_outlined,
      owned: true,
      showPrice: false,
      actionLabel: equipped ? '已配戴' : '設為預設',
      onAction: equipped ? null : _clearFrame,
    );
  }

  Widget _buildItemCard(ShopItem item) {
    final isGold = item.rarity == 'gold';
    final rarityColor = _rarityColors[item.rarity];
    final equipped = item.type == 'frame' ? _user?.frameId == item.id : _user?.avatarId == item.id;

    return ShopItemCard(
      name: item.name,
      subtitle: item.rarity != null ? _rarityLabels[item.rarity] ?? item.rarity! : null,
      price: item.price,
      isGold: isGold,
      rarityColor: rarityColor,
      owned: true,
      imageUrl: item.imageUrl,
      icon: item.type == 'frame' ? Icons.circle_outlined : Icons.face_rounded,
      showPrice: false,
      actionLabel: equipped ? '已配戴' : '配戴',
      onAction: equipped ? null : () => _equipItem(item),
    );
  }
}
