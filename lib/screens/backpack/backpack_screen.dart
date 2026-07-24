import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../models/shop_item.dart';
import '../../models/user_model.dart';
import '../../services/shop_service.dart';
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
      final user = await ShopService.fetchMe();
      final items = await ShopService.fetchShopItems();
      if (!mounted) return;
      setState(() {
        _user = user;
        _serverItems = items;
        _loading = false;
      });
    } catch (_) {
      // 讀取失敗時維持空清單，只顯示基本介面，不讓整頁崩潰。
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
    final isEmpty = avatarList.isEmpty && frameList.isEmpty;

    return Scaffold(
      backgroundColor: AppColors.creamLight,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHero(context)),
          SliverToBoxAdapter(child: _buildCategories()),
          if (isEmpty)
            SliverToBoxAdapter(child: _buildEmptyState())
          else ...[
            if (showAvatars && avatarList.isNotEmpty)
              SliverToBoxAdapter(child: _buildItemSection('頭像 Lukus', 'lukus · 共 ${avatarList.length} 款', avatarList)),
            if (showFrames && frameList.isNotEmpty)
              SliverToBoxAdapter(child: _buildItemSection('頭像框', 'rangi · 共 ${frameList.length} 款', frameList)),
          ],
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

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 0),
      child: Column(
        children: [
          Icon(Icons.inventory_2_outlined, size: 40, color: AppColors.fog),
          const SizedBox(height: 12),
          Text(
            '尚未擁有任何頭像或頭像框',
            style: TextStyle(fontSize: 13, color: AppColors.fog, letterSpacing: 0.5),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _openShop,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                '前往商店兌換',
                style: GoogleFonts.notoSerifTc(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.creamLight,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
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
