import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_radius.dart';
import '../../core/constants/app_typography.dart';

/// App 統一的對話框外觀：深色卡片、主要按鈕實心放上方，次要按鈕排在下方一列。
///
/// 只負責畫面，不負責推出；一般用 [showConfirmDialog]，版本更新提示則直接
/// 疊在 Navigator 之上（見 app_update_prompt.dart）。
class AppDialog extends StatelessWidget {
  final String? title;
  final String message;

  /// 主要按鈕。兩者皆為 null 時不顯示，給沒有可執行動作、只能照訊息處理的情況。
  final String? primaryText;
  final VoidCallback? onPrimary;

  /// 次要按鈕（文字, 動作），依序由左到右排在主要按鈕下方。
  final List<(String, VoidCallback)> secondary;

  const AppDialog({
    super.key,
    this.title,
    required this.message,
    this.primaryText,
    this.onPrimary,
    this.secondary = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Material(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (title != null) ...[
                    Text(
                      title!,
                      style: AppTypography.titleStyle(
                        color: AppColors.creamLight,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Flexible(
                    child: SingleChildScrollView(
                      child: Text(
                        message,
                        style: AppTypography.bodyStyle(color: AppColors.mist),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (primaryText case final text?)
                    FilledButton(
                      onPressed: onPrimary,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.creamLight,
                      ),
                      child: Text(text),
                    ),
                  if (secondary.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        for (final (text, onTap) in secondary)
                          Expanded(
                            child: TextButton(
                              onPressed: onTap,
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.cream,
                              ),
                              child: Text(text),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// （可省略的）標題 + 訊息 + 確認/取消兩顆按鈕的對話框，回傳 `true`＝已確認、`false`＝取消或關閉。
Future<bool> showConfirmDialog(
  BuildContext context, {
  String? title,
  required String message,
  String confirmText = '確認',
  String cancelText = '取消',
  bool barrierDismissible = true,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (ctx) => AppDialog(
      title: title,
      message: message,
      primaryText: confirmText,
      onPrimary: () => Navigator.pop(ctx, true),
      secondary: [(cancelText, () => Navigator.pop(ctx, false))],
    ),
  );
  return result ?? false;
}
