import 'package:flutter/material.dart';

import '../../core/constants/app_typography.dart';

/// 清單底部「下一頁載入失敗」的重試鈕，搭配 CursorPager.retryLoadMore。
class LoadMoreRetry extends StatelessWidget {
  final VoidCallback onRetry;
  final Color color;
  final bool seniorMode;

  const LoadMoreRetry({
    super.key,
    required this.onRetry,
    required this.color,
    required this.seniorMode,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: onRetry,
        child: Text(
          '載入失敗，點此重試',
          style: AppTypography.bodyLargeStyle(
            seniorMode: seniorMode,
            color: color,
          ),
        ),
      ),
    );
  }
}
