// 申訴：依待處理、已成立、已駁回切換；待處理的可「接受」（撤銷處置）或「駁回」，
// 都要填給申訴人看的回覆。規格：Truku_backend 說明文件/API/收件匣與申訴.md §4。
//
// 處理的人不能是當事人（SELF_INVOLVED），也不能是這個案件的開案者或複審者
// （SAME_ADMIN）：這兩種都直接顯示後端 message，申訴留在列表給別位管理員。

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/date_format.dart';
import '../../models/admin_models.dart';
import '../../models/page_info.dart';
import '../../services/admin_service.dart';
import 'admin_cases_screen.dart';
import 'admin_error.dart';
import 'widgets/admin_reason_dialog.dart';
import 'widgets/admin_widgets.dart';

const _replyMax = 1000;

const _statuses = <AdminStatusOption>[
  (label: '待處理', value: 'pending'),
  (label: '已成立', value: 'accepted'),
  (label: '已駁回', value: 'rejected'),
];

String adminAppealStatusLabel(String status) => switch (status) {
  'pending' => '待處理',
  'accepted' => '已成立',
  'rejected' => '已駁回',
  _ => status,
};

class AdminAppealsScreen extends StatelessWidget {
  const AdminAppealsScreen({super.key});

  @override
  Widget build(BuildContext context) => AdminStatusListScreen<AdminAppeal>(
    title: '申訴',
    statuses: _statuses,
    emptyMessage: '這個狀態目前沒有申訴',
    fetch: (status, _) async => (
      items: await AdminService.fetchAppeals(status: status),
      pageInfo: PageInfo.end,
    ),
    // 以申訴 id 當 key：處理完一筆、下一筆補到同一個位置時不沿用上一筆的狀態。
    itemBuilder: (context, appeal, senior, reload) => _AppealCard(
      key: ValueKey(appeal.id),
      appeal: appeal,
      seniorMode: senior,
      reload: reload,
    ),
  );
}

class _AppealCard extends StatefulWidget {
  final AdminAppeal appeal;
  final bool seniorMode;
  final Future<void> Function() reload;

  const _AppealCard({
    super.key,
    required this.appeal,
    required this.seniorMode,
    required this.reload,
  });

  @override
  State<_AppealCard> createState() => _AppealCardState();
}

class _AppealCardState extends State<_AppealCard> {
  bool _busy = false;

  Future<void> _resolve(String decision) async {
    final appeal = widget.appeal;
    final accepting = decision == 'accept';
    final name = appeal.offender.nickname.isEmpty
        ? '這位使用者'
        : '「${appeal.offender.nickname}」';
    final input = await promptAdminReason(
      context,
      title: accepting ? '接受申訴' : '駁回申訴',
      description: accepting
          ? '接受後會撤銷處置：恢復內容；已確認的違規會退回次數、解除這次造成的禁言，'
                '退回後低於門檻的會解除停權。回覆會顯示給申訴人。'
          : '駁回後維持原處置。回覆會顯示給申訴人。',
      confirmMessage: accepting ? '確定接受$name的申訴並撤銷處置？' : '確定駁回$name的申訴？',
      confirmText: accepting ? '接受' : '駁回',
      maxLength: _replyMax,
      label: '給申訴人的回覆',
    );
    if (input == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final result = await AdminService.resolveAppeal(
        appeal.id,
        decision,
        input.reason,
      );
      if (!mounted) return;
      if (accepting) {
        await showAdminInfoDialog(
          context,
          title: '已接受申訴',
          message: [
            '處置已撤銷。',
            result.strikeReverted ? '違規次數已退回。' : '沒有退回違規次數。',
            result.unlocked ? '已解除停權。' : '沒有解除停權。',
          ].join('\n'),
        );
      } else {
        showAdminMessage('已駁回申訴');
      }
      await widget.reload();
      if (mounted) setState(() => _busy = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      if (handleAdminError(context, e)) return;
      // 已經被別人處理掉：以伺服器最新狀態為準。
      if (e is ApiException &&
          (e.code == 'APPEAL_ALREADY_HANDLED' ||
              e.code == 'APPEAL_NOT_FOUND')) {
        await widget.reload();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.appeal;
    final c = a.appealCase;
    final senior = widget.seniorMode;
    return AdminCard(
      seniorMode: senior,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AdminBadge(
                adminTargetTypeLabel(c.targetType),
                seniorMode: senior,
              ),
              const SizedBox(width: 8),
              AdminBadge(
                adminAppealStatusLabel(a.status),
                color: AppColors.moss,
                seniorMode: senior,
              ),
              const Spacer(),
              if (a.createdAt != null)
                Text(
                  formatDateTime(a.createdAt!),
                  style: AppTypography.captionStyle(
                    seniorMode: senior,
                    color: AppColors.fog,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            a.reason,
            style: AppTypography.bodyLargeStyle(
              seniorMode: senior,
              color: AppColors.ink,
            ),
          ),
          AdminInfoRow(
            '當事人',
            '${a.offender.nickname.isEmpty ? '（未設定暱稱）' : a.offender.nickname}'
                '${a.offender.friendCode.isEmpty ? '' : '（${a.offender.friendCode}）'}',
            seniorMode: senior,
          ),
          AdminInfoRow(
            '案件',
            '編號 ${c.id}・${adminCaseSourceLabel(c.source)}・'
                '${adminCaseStatusLabel(c.status)}',
            seniorMode: senior,
          ),
          AdminInfoRow('案件原始理由', c.reason, seniorMode: senior),
          // 通話、自動禁言案件後端不給內容預覽。
          if (a.hasPreview)
            AdminCasePreviewView(adminCase: c, seniorMode: senior),
          if (a.status == 'pending')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _busy ? null : () => _resolve('reject'),
                    child: const Text('駁回'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _busy ? null : () => _resolve('accept'),
                    child: const Text('接受'),
                  ),
                ],
              ),
            )
          else ...[
            const SizedBox(height: 8),
            AdminInfoRow('處理人', a.handledByNickname ?? '—', seniorMode: senior),
            if (a.handledAt != null)
              AdminInfoRow(
                '處理時間',
                formatDateTime(a.handledAt!),
                seniorMode: senior,
              ),
            AdminInfoRow('回覆', a.reply ?? '—', seniorMode: senior),
          ],
        ],
      ),
    );
  }
}
