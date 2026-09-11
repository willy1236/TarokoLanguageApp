// 收藏／按讚／列表類頁面共用的空狀態版型：圓形底色 + 太魯閣菱形浮水印
// + primary 色 icon + 粗體標題 + 提示文字。原型來自 forum_board_view.dart
// 的 _ForumEmptyState，抽出後供影音/文章/活動/貼文/留言等清單共用。

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import 'truku_widgets.dart';

class TrukuEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String subtitle;
  final bool seniorMode;

  /// 是否自己包一層 [Center] + [SingleChildScrollView]。
  /// 若呼叫端已經有自己的置中/捲動容器（例如空清單時共用外層下拉刷新的
  /// 捲動區域），應傳 false，避免巢狀 Center/ScrollView 造成 layout 問題。
  final bool scrollable;

  const TrukuEmptyState({
    super.key,
    required this.icon,
    required this.message,
    required this.subtitle,
    required this.seniorMode,
    this.scrollable = true,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 76,
          height: 76,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.creamDeep,
                  shape: BoxShape.circle,
                ),
                child: SizedBox.expand(),
              ),
              Positioned(
                right: -6,
                top: -6,
                child: Opacity(
                  opacity: 0.13,
                  child: TrukuDiamond(size: 40, color: AppColors.primary),
                ),
              ),
              Icon(icon, color: AppColors.primary, size: 34),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          message,
          style: GoogleFonts.notoSerifTc(
            fontSize: AppTypography.size(AppTypography.subtitle, seniorMode: seniorMode),
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: seniorMode ? AppTypography.body + AppTypography.seniorStep : null,
            color: AppColors.fog,
          ),
        ),
      ],
    );
    if (!scrollable) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: content,
        ),
      );
    }
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
        child: content,
      ),
    );
  }
}
