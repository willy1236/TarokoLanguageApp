import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';

/// 共用道具卡片：頭像與頭像框在商店頁、背包頁都用這個 widget 呈現
/// owned / locked / 未擁有可兌換 三種視覺狀態，避免重複的圓形圖示 + 名稱 + 價格排版程式碼。
///
/// - [owned] 為 true：圖片畫在最上層（不會被標籤蓋住），右上角顯示「已擁有」標籤，
///   圖片外圈套用持有感的綠色邊框；若提供 [actionLabel]（例如「配戴」）則額外顯示按鈕。
/// - [lockedText] 非 null：整張卡片降低透明度、右上角顯示鎖頭圖示、底部顯示解鎖條件文字，不可互動。
/// - 未擁有（含鎖定與可兌換兩種情況）：圖片維持原色（避免灰階讓真實圖案看不清楚），
///   改用外圈綠框（僅已擁有）＋卡片邊框顏色差異來區隔，不只靠右上角標籤文字。
/// - [showPrice] 為 false 時不顯示價格列（背包頁只列出已擁有道具，不需要價格）。
/// - [rarityColor] 非 null 時（頭像才有）依六色稀有度上色副標；頭像框無此欄位。
class ShopItemCard extends StatelessWidget {
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
  final bool showPrice;

  const ShopItemCard({
    super.key,
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
    this.showPrice = true,
  });

  static const Color _ownedColor = Color(0xFF5BC97D);

  @override
  Widget build(BuildContext context) {
    final accentColor = rarityColor ?? AppColors.primary;
    final borderColor = owned
        ? _ownedColor.withValues(alpha: 0.7)
        : (isGold
            ? AppColors.gold.withValues(alpha: 0.31)
            : AppColors.creamDeep);

    return Opacity(
      opacity: lockedText != null ? 0.55 : 1.0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isGold ? const Color(0xFF2A1A15) : AppColors.cream,
          border: Border.all(color: borderColor, width: owned ? 1.5 : 1),
        ),
        child: Stack(
          children: [
            // 圖片／名稱／價格內容排最前面，讓後面的 owned／locked 標籤畫在上層，不被蓋住。
            Column(
              children: [
                Center(
                  child: Container(
                    width: 64,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isGold
                          ? AppColors.gold.withValues(alpha: 0.1)
                          : AppColors.creamDeep,
                      border: owned
                          ? Border.all(color: _ownedColor, width: 2)
                          : null,
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
                    style: TextStyle(
                      fontSize: 9,
                      color: isGold ? AppColors.gold : accentColor,
                      letterSpacing: 1,
                    ),
                  ),
                ],
                if (showPrice) ...[
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
                ],
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
            if (owned)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: _ownedColor),
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
