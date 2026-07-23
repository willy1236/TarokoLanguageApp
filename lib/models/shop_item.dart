// 對應 GET /api/shop/items 回傳的單一頭像／頭像框目錄項目
// 規格參考：Truku_backend 說明文件/API/頭像商店.md v2.0
//
// 頭像與頭像框合併同一張目錄，用 type 區分；image_url 為真實 GCS 網址。

class ShopItem {
  final String id;
  final String type; // 'avatar' | 'frame'
  final String name;
  final int price;
  final String? rarity; // 'red'|'orange'|'yellow'|'green'|'blue'|'gold'；頭像框固定 null
  final String? unlockCondition;
  final String? imageUrl;
  final bool isOwned;

  const ShopItem({
    required this.id,
    required this.type,
    required this.name,
    required this.price,
    this.rarity,
    this.unlockCondition,
    this.imageUrl,
    required this.isOwned,
  });

  factory ShopItem.fromJson(Map<String, dynamic> json) {
    return ShopItem(
      id: json['id'] as String,
      type: json['type'] as String,
      name: json['name'] as String,
      price: json['price'] as int,
      rarity: json['rarity'] as String?,
      unlockCondition: json['unlock_condition'] as String?,
      imageUrl: json['image_url'] as String?,
      isOwned: json['is_owned'] as bool? ?? false,
    );
  }
}
