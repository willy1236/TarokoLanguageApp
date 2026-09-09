// 首頁用的精簡模式快速切換 icon。用縮放＋淡入淡出讓切換更生動，
// 不需另外進個人資料頁就能開關（狀態仍共用同一個 seniorModeController）。
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../services/senior_mode_controller.dart';

class SeniorModeToggleIcon extends StatelessWidget {
  const SeniorModeToggleIcon({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: seniorModeController,
    builder: (context, _) {
      final enabled = seniorModeController.enabled;
      return Semantics(
        button: true,
        label: '切換精簡模式',
        child: Tooltip(
          message: '切換精簡模式',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              final next = !enabled;
              seniorModeController.setEnabled(next);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(next ? '已開啟精簡模式' : '已關閉精簡模式'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: enabled
                    ? AppColors.gold.withValues(alpha: 0.25)
                    : AppColors.fog.withValues(alpha: 0.15),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: animation,
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: Icon(
                  enabled ? Icons.accessibility_new_rounded : Icons.grid_view_rounded,
                  key: ValueKey(enabled),
                  size: 22,
                  color: enabled ? AppColors.gold : AppColors.fog,
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
