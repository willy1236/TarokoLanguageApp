// 對應 GET /api/shop/avatars 回傳的單一頭像目錄項目
// 規格參考：Truku_backend#1 GET /api/shop/avatars（回傳完整頭像目錄，含 image_url／is_owned）
//
// 跟 lib/core/constants/avatar_catalog.dart 的 AvatarCatalogItem 不同：
// 這個是「後端算好的」項目（is_owned 是伺服器依登入使用者算的，不是前端自己比對
// ownedAvatarIds），image_url 目前後端一律回 NULL（圖檔尚未上傳 GCS），此時前端
// 應 fallback 用本地 assets/images/avatars/ 素材（見 AvatarCatalogItem.assetPath）。

class AvatarShopItem {
  final String id;
  final String name;
  final int price;
  final String rarity; // 'common' | 'rare' | 'gold'
  final String? unlockCondition;
  final String? imageUrl;
  final bool isOwned;

  const AvatarShopItem({
    required this.id,
    required this.name,
    required this.price,
    required this.rarity,
    this.unlockCondition,
    this.imageUrl,
    required this.isOwned,
  });

  factory AvatarShopItem.fromJson(Map<String, dynamic> json) {
    return AvatarShopItem(
      id: json['id'] as String,
      name: json['name'] as String,
      price: json['price'] as int,
      rarity: json['rarity'] as String,
      unlockCondition: json['unlock_condition'] as String?,
      imageUrl: json['image_url'] as String?,
      isOwned: json['is_owned'] as bool? ?? false,
    );
  }
}
