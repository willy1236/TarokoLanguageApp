// 全 App 共用的返回鈕：無背景的左箭頭，所有畫面統一這個樣式。
//
// 淺色底（cream 系）用預設樣式；疊在深色底或主視覺圖上時傳 onDark: true。
// 長輩模式放大由元件自己讀 seniorModeController，呼叫端不用傳。

import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_icon_size.dart';
import '../../services/senior_mode_controller.dart';

class AppBackButton extends StatelessWidget {
  final bool onDark;

  /// 預設為 Navigator.maybePop；需要攔截（例如離開前確認）時才傳。
  final VoidCallback? onPressed;

  const AppBackButton({super.key, this.onDark = false, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: seniorModeController,
      builder: (context, _) => IconButton(
        onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
        tooltip: '返回',
        iconSize: AppIconSize.action(seniorModeController.enabled),
        icon: Icon(
          Icons.arrow_back,
          color: onDark ? AppColors.creamLight : AppColors.ink,
        ),
      ),
    );
  }
}
