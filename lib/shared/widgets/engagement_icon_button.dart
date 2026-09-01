// 四模組（影音/文章/活動/論壇）共用的按讚／收藏／留言數圖示按鈕。
// 原本四處各自複製一份幾乎相同的「圖示 + 選填數字」小元件，行為一致（點擊
// 觸發樂觀更新，樂觀更新與失敗還原邏輯留在各自呼叫端），這裡只抽出純 UI。
//
// 精簡模式下加大觸控熱區，避免長者手指誤觸鄰近按鈕（沿用論壇原本的作法）。
import 'package:flutter/material.dart';

import '../../core/constants/app_typography.dart';

class EngagementIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool seniorMode;

  /// null = 不顯示數字（例如收藏按鈕）。
  final int? count;

  const EngagementIconButton({
    super.key,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.seniorMode,
    this.count,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Padding(
      padding: EdgeInsets.symmetric(vertical: seniorMode ? 12 : 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: seniorMode ? 30 : 18, color: color),
          if (count != null) ...[
            const SizedBox(width: 5),
            Text(
              '$count',
              style: TextStyle(
                fontSize: seniorMode ? AppTypography.subtitle : 12,
                color: color,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
