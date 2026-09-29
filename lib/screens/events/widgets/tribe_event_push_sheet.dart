// 「活動通知」頁齒輪打開的推播設定底板：只有部落新活動推播一項。
// 打開才查設定，進頁面本身不多打請求。

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../services/notification_settings_service.dart';
import '../../../services/senior_mode_controller.dart';
import '../../../shared/widgets/async_state_view.dart';

Future<void> showTribeEventPushSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.creamLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => const TribeEventPushSheet(),
    );

class TribeEventPushSheet extends StatefulWidget {
  const TribeEventPushSheet({super.key});

  @override
  State<TribeEventPushSheet> createState() => _TribeEventPushSheetState();
}

class _TribeEventPushSheetState extends State<TribeEventPushSheet> {
  bool? _enabled;
  Object? _loadError;
  bool _saving = false;
  // 底板蓋在頁面上，頁面的 SnackBar 會被擋住，儲存失敗改在底板內提示。
  bool _saveFailed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _enabled = null;
      _loadError = null;
    });
    try {
      final enabled = await NotificationSettingsService.fetchTribeEvents();
      if (mounted) setState(() => _enabled = enabled);
    } catch (e) {
      if (mounted) setState(() => _loadError = e);
    }
  }

  Future<void> _toggle(bool value) async {
    if (_saving) return;
    final previous = _enabled;
    setState(() {
      _enabled = value;
      _saving = true;
      _saveFailed = false;
    });
    try {
      final saved = await NotificationSettingsService.setTribeEvents(value);
      if (mounted) setState(() => _enabled = saved);
    } catch (_) {
      if (mounted) {
        setState(() {
          _enabled = previous;
          _saveFailed = true;
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: seniorModeController,
    builder: (context, _) => _build(seniorModeController.enabled),
  );

  Widget _build(bool seniorMode) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '推播設定',
              style: AppTypography.subtitleStyle(
                seniorMode: seniorMode,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 12),
            _buildContent(seniorMode),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(bool seniorMode) {
    if (_loadError != null) {
      return TrukuErrorView(
        error: _loadError,
        onRetry: _load,
        seniorMode: seniorMode,
      );
    }
    final enabled = _enabled;
    if (enabled == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: TrukuLoadingView(),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '接收「你的部落有新活動」推播',
                    style: AppTypography.bodyLargeStyle(
                      seniorMode: seniorMode,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '活動提醒不受影響',
                    style: AppTypography.captionStyle(
                      seniorMode: seniorMode,
                      color: AppColors.fog,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Switch(
              value: enabled,
              activeThumbColor: AppColors.creamLight,
              activeTrackColor: AppColors.primary,
              onChanged: _toggle,
            ),
          ],
        ),
        if (_saveFailed) ...[
          const SizedBox(height: 8),
          Text(
            '儲存失敗，請稍後再試',
            style: AppTypography.captionStyle(
              seniorMode: seniorMode,
              color: AppColors.dangerDark,
            ),
          ),
        ],
      ],
    );
  }
}
