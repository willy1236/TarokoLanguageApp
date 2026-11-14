import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../models/shop_item.dart';
import '../../models/user_model.dart';
import 'filter_pill.dart';

/// 商店與背包共用的稀有度、分類 chip 與配戴動作。兩頁原本各自複製一份，
/// 改稀有度或錯誤文案時容易只改到其中一邊。

/// 六色稀有度 → 顯示色與中文標籤；頭像框固定 rarity=null，不落在此表內。
const Map<String, Color> rarityColors = {
  'red': AppColors.rose,
  'orange': AppColors.orangeLight,
  'yellow': AppColors.amber,
  'green': AppColors.greenLight,
  'blue': AppColors.blue,
  'gold': AppColors.gold,
};

const Map<String, String> rarityLabels = {
  'red': '紅',
  'orange': '橙',
  'yellow': '黃',
  'green': '綠',
  'blue': '藍',
  'gold': '金',
};

/// 卡片副標：稀有度中文標籤，查不到就顯示原始值；無稀有度回 null。
String? raritySubtitle(ShopItem item) {
  final rarity = item.rarity;
  if (rarity == null) return null;
  return rarityLabels[rarity] ?? rarity;
}

/// 執行一個會回傳最新 UserModel 的商店動作（配戴、取消配戴…），
/// 統一處理成功/後端錯誤/其他錯誤的 SnackBar。失敗回 null。
/// 呼叫端負責在成功時 setState，以及自己的防重入旗標。
Future<UserModel?> runShopAction(
  BuildContext context, {
  required Future<UserModel> Function() action,
  required String successMessage,
  String failureMessage = '配戴失敗，請稍後再試',
  required String logTag,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final updated = await action();
    if (context.mounted) {
      messenger.showSnackBar(SnackBar(content: Text(successMessage)));
    }
    return updated;
  } on ApiException catch (e) {
    if (context.mounted) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  } catch (e) {
    debugPrint('$logTag failed: $e');
    if (context.mounted) {
      messenger.showSnackBar(SnackBar(content: Text(failureMessage)));
    }
  }
  return null;
}

/// 商店/背包頂部的橫向分類 chip 列。
class ShopCategoryChips extends StatelessWidget {
  const ShopCategoryChips({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 8),
      child: FilterPillRow(
        labels: labels,
        selectedIndex: selected,
        onSelected: onSelected,
      ),
    );
  }
}
