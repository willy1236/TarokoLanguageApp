import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/app_update/app_update_service.dart';
import 'confirm_dialog.dart';

/// 版本更新提示層，放在 MaterialApp.builder、疊在 Navigator 之上。
///
/// 不用 showDialog：啟動流程會 pushReplacement（splash → 登入／條款／首頁），
/// 對話框若是 Navigator 裡的路由會被一起換掉。
class AppUpdatePromptLayer extends StatelessWidget {
  final Widget child;

  const AppUpdatePromptLayer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AvailableUpdate?>(
      valueListenable: AppUpdateService.available,
      child: child,
      builder: (context, update, child) => Stack(
        children: [
          child!,
          if (update != null) ...[
            const ModalBarrier(dismissible: false, color: Colors.black54),
            _AppUpdatePrompt(update: update),
          ],
        ],
      ),
    );
  }
}

class _AppUpdatePrompt extends StatelessWidget {
  final AvailableUpdate update;

  const _AppUpdatePrompt({required this.update});

  Future<void> _openStore(String url) async {
    // 強制更新時不關掉提示：從商店回來還沒更新的話仍然擋著。
    if (!update.required) AppUpdateService.dismiss();
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('AppUpdatePrompt 開啟更新連結失敗：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = update.url;
    if (update.required) {
      return AppDialog(
        title: '需要更新',
        message: url == null
            ? '目前的版本已無法使用，請到 TestFlight 或 App Store 更新到最新版。'
            : '目前的版本已無法使用，請更新到最新版後再繼續。',
        primaryText: url == null ? null : '更新',
        onPrimary: url == null ? null : () => _openStore(url),
      );
    }
    return AppDialog(
      title: '有新版本可用',
      message: '建議更新以獲得最佳體驗。',
      primaryText: '更新',
      onPrimary: () => _openStore(url!),
      secondary: [
        ('略過此版本', () => AppUpdateService.skip(update)),
        ('稍後', AppUpdateService.dismiss),
      ],
    );
  }
}
