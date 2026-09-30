// 有效禁言列表：對象（暱稱與好友碼）、範圍、到期時間、來源，可提前解除。

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/utils/date_format.dart';
import '../../core/network/api_client.dart';
import '../../models/admin_models.dart';
import '../../models/page_info.dart';
import '../../services/admin_service.dart';
import '../../shared/widgets/confirm_dialog.dart';
import 'admin_error.dart';
import 'widgets/admin_widgets.dart';

class AdminMutesScreen extends StatelessWidget {
  const AdminMutesScreen({super.key});

  @override
  Widget build(BuildContext context) => AdminStatusListScreen<AdminMute>(
    title: '禁言',
    statuses: const [(label: '有效禁言', value: 'active')],
    emptyMessage: '目前沒有有效的禁言',
    fetch: (_, _) async =>
        (items: await AdminService.fetchMutes(), pageInfo: PageInfo.end),
    itemBuilder: (context, mute, senior, reload) =>
        _MuteCard(mute: mute, seniorMode: senior, reload: reload),
  );
}

class _MuteCard extends StatelessWidget {
  final AdminMute mute;
  final bool seniorMode;
  final Future<void> Function() reload;

  const _MuteCard({
    required this.mute,
    required this.seniorMode,
    required this.reload,
  });

  Future<void> _lift(BuildContext context) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '解除禁言？',
      message: '「${mute.nickname}」的禁言會立刻解除，尚未到期時會通知對方。',
      confirmText: '解除',
    );
    if (!confirmed || !context.mounted) return;
    try {
      await AdminService.liftMute(mute.id);
      showAdminMessage('已解除禁言');
      await reload();
    } catch (e) {
      if (!context.mounted) return;
      if (handleAdminError(context, e)) return;
      // 已經被別人解除或已不存在：以伺服器最新狀態為準。
      if (e is ApiException && e.statusCode == 404) await reload();
    }
  }

  @override
  Widget build(BuildContext context) => AdminCard(
    seniorMode: seniorMode,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                mute.nickname.isEmpty ? '使用者 ${mute.uid}' : mute.nickname,
                style: AppTypography.titleStyle(
                  seniorMode: seniorMode,
                  color: AppColors.ink,
                ),
              ),
            ),
            AdminBadge(adminMuteScopeLabel(mute.scope), seniorMode: seniorMode),
          ],
        ),
        if (mute.friendCode != null && mute.friendCode!.isNotEmpty)
          AdminInfoRow('好友碼', mute.friendCode!, seniorMode: seniorMode),
        AdminInfoRow(
          '來源',
          adminMuteReasonLabel(mute.reason),
          seniorMode: seniorMode,
        ),
        if (mute.muteUntil != null)
          AdminInfoRow(
            '到期時間',
            formatDateTime(mute.muteUntil!),
            seniorMode: seniorMode,
          ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => _lift(context),
            child: const Text('解除'),
          ),
        ),
      ],
    ),
  );
}
