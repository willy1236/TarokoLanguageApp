// 全站共用的「載入中／錯誤／空狀態」三段式。原本各畫面各自手刻，文案、
// 間距、長輩模式放大與未登入判斷都略有出入；集中後畫面只需提供資料與重試。
// 空狀態沿用 truku_empty_state.dart 的 TrukuEmptyState。

import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/network/api_client.dart';

/// 置中的品牌色轉圈。[topPadding] 給放在捲動區頂端（例如 sliver 內）時使用，
/// 不給則直接置中。
class TrukuLoadingView extends StatelessWidget {
  final double? topPadding;

  const TrukuLoadingView({super.key, this.topPadding});

  @override
  Widget build(BuildContext context) {
    const spinner = CircularProgressIndicator(color: AppColors.primary);
    final top = topPadding;
    if (top == null) return const Center(child: spinner);
    return Padding(
      padding: EdgeInsets.only(top: top),
      child: const Center(child: spinner),
    );
  }
}

/// 載入失敗畫面：icon + 訊息 + 重試。
///
/// 訊息規則：未登入（401）一律顯示「請先登入」；否則 [message] 優先，
/// 其次 [ApiException.message]，最後 [fallback]。[onRetry] 為 null 時不顯示
/// 重試按鈕（例如錯誤不會因重試而改變，像是已完成分級測驗）。
class TrukuErrorView extends StatelessWidget {
  final Object? error;
  final VoidCallback? onRetry;
  final bool seniorMode;
  final String? message;
  final String fallback;

  /// 放在捲動區頂端時給上方留白；null 時自行置中。
  final double? topPadding;

  const TrukuErrorView({
    super.key,
    this.error,
    this.onRetry,
    this.seniorMode = false,
    this.message,
    this.fallback = '載入失敗，請稍後再試',
    this.topPadding,
  });

  @override
  Widget build(BuildContext context) {
    final unauthorized = isAuthError(error);
    final text = unauthorized
        ? '請先登入'
        : message ?? apiErrorMessage(error, fallback: fallback);
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          unauthorized ? Icons.lock_outline : Icons.cloud_off_outlined,
          size: seniorMode ? 56 : 40,
          color: AppColors.fog,
        ),
        const SizedBox(height: 12),
        Text(
          text,
          textAlign: TextAlign.center,
          style: AppTypography.bodyLargeStyle(
            seniorMode: seniorMode,
            color: AppColors.inkSoft,
          ),
        ),
        if (onRetry != null) ...[
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              minimumSize: seniorMode ? const Size(140, 52) : null,
              textStyle: seniorMode
                  ? const TextStyle(fontSize: AppTypography.subtitle)
                  : null,
            ),
            child: const Text('重試'),
          ),
        ],
      ],
    );
    final top = topPadding;
    if (top != null) {
      return Padding(
        padding: EdgeInsets.fromLTRB(24, top, 24, 24),
        child: content,
      );
    }
    return Center(
      child: Padding(padding: const EdgeInsets.all(24), child: content),
    );
  }
}

/// FutureBuilder 的四態封裝：載入中 → [TrukuLoadingView]；失敗 →
/// [TrukuErrorView]；[isEmpty] 為真且有 [empty] → 空狀態；其餘 → [builder]。
class AsyncStateView<T> extends StatelessWidget {
  final Future<T> future;
  final Widget Function(BuildContext context, T data) builder;
  final bool Function(T data)? isEmpty;
  final Widget? empty;
  final VoidCallback? onRetry;
  final bool seniorMode;
  final String errorFallback;
  final double? topPadding;

  const AsyncStateView({
    super.key,
    required this.future,
    required this.builder,
    this.isEmpty,
    this.empty,
    this.onRetry,
    this.seniorMode = false,
    this.errorFallback = '載入失敗，請稍後再試',
    this.topPadding,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return TrukuLoadingView(topPadding: topPadding);
        }
        if (snap.hasError) {
          return TrukuErrorView(
            error: snap.error,
            onRetry: onRetry,
            seniorMode: seniorMode,
            fallback: errorFallback,
            topPadding: topPadding,
          );
        }
        final data = snap.data as T;
        final emptyView = empty;
        if (emptyView != null && (isEmpty?.call(data) ?? false)) {
          return emptyView;
        }
        return builder(context, data);
      },
    );
  }
}
