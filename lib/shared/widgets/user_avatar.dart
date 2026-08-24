import 'package:flutter/material.dart';
import '../../models/shop_item.dart';

// 使用者頭像渲染邏輯（與個人資料頁一致，見 頭像商店.md §5）：
// 已配戴內建頭像（avatarId）優先，對照商店目錄取得 image_url；否則退回原始
// 大頭貼（avatarUrl）；兩者皆無或載入失敗則顯示預設 Icons.person。
class UserAvatar extends StatelessWidget {
  final String? avatarId;
  final String? avatarUrl;
  final Map<String, ShopItem> itemCatalogById;
  final double size;
  final Color fallbackIconColor;

  const UserAvatar({
    super.key,
    this.avatarId,
    this.avatarUrl,
    this.itemCatalogById = const {},
    required this.size,
    required this.fallbackIconColor,
  });

  @override
  Widget build(BuildContext context) {
    final fallbackIcon = Icon(
      Icons.person,
      size: size * 0.65,
      color: fallbackIconColor,
    );

    if (avatarId != null) {
      final imageUrl = itemCatalogById[avatarId]?.imageUrl;
      if (imageUrl != null) {
        return Image.network(
          imageUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => fallbackIcon,
        );
      }
      return fallbackIcon;
    }

    if (avatarUrl != null) {
      return Image.network(
        avatarUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallbackIcon,
      );
    }

    return fallbackIcon;
  }
}
