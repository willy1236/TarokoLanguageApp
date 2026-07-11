/// 頭像目錄資料模型與常數清單 — 對應 assets/images/avatars/ 內的素材檔案。
///
/// 命名慣例：`avatar_general_NN.png`（NN 為 01~40 兩位數編號）。
class AvatarCatalogItem {
  const AvatarCatalogItem({
    required this.id,
    required this.assetPath,
    required this.name,
    required this.price,
    required this.rarity,
    this.unlockCondition,
  });

  /// 對應檔名（不含副檔名），例如 `avatar_general_01`。
  final String id;

  /// 圖片資源路徑，例如 `assets/images/avatars/avatar_general_01.png`。
  final String assetPath;

  /// 顯示用名稱。
  final String name;

  /// 小米幣價格。
  final int price;

  /// 稀有度，例如 `common` / `rare` / `gold`。
  final String rarity;

  /// 解鎖條件描述，null 表示無條件解鎖（可直接購買/使用）。
  final String? unlockCondition;
}

/// 產生單一頭像目錄項目，依編號套用預設的稀有度／價格／解鎖條件。
AvatarCatalogItem _buildAvatar(int index) {
  final id = 'avatar_general_${index.toString().padLeft(2, '0')}';
  const goldIndexes = {10, 20, 30, 40};
  const rareIndexes = {5, 15, 25, 35};

  String rarity;
  int price;
  String? unlockCondition;

  if (goldIndexes.contains(index)) {
    rarity = 'gold';
    price = 500;
    unlockCondition = '完成每日任務累積 30 天';
  } else if (rareIndexes.contains(index)) {
    rarity = 'rare';
    price = 200;
    unlockCondition = null;
  } else {
    rarity = 'common';
    price = 50;
    unlockCondition = null;
  }

  return AvatarCatalogItem(
    id: id,
    assetPath: 'assets/images/avatars/$id.png',
    name: '頭像 $index',
    price: price,
    rarity: rarity,
    unlockCondition: unlockCondition,
  );
}

/// 全部 40 張頭像的目錄常數清單。
final List<AvatarCatalogItem> kAvatarCatalog = List<AvatarCatalogItem>.unmodifiable(
  List<AvatarCatalogItem>.generate(40, (i) => _buildAvatar(i + 1)),
);
