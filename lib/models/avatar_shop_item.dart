// 對應 GET /api/shop/avatars 回傳的單一頭像目錄項目
// 規格參考：Truku_backend#1 GET /api/shop/avatars（回傳完整頭像目錄，含 image_url／is_owned）
//
// image_url 目前後端一律回 NULL（圖檔尚未上傳 GCS）。前端**不做本地素材 fallback**，
// image_url 為 null 時直接顯示預設圖示，誠實反映現況，不用假圖片掩蓋。

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
