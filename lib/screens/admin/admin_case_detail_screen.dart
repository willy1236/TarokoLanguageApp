// 違規案件詳情：二審「確認違規」「撤銷」，可附 500 字內備註。
// 由檢舉開案的案件並列「檢舉當時」與「目前」的內容；下拉重新整理會重抓這個案件
// （頭像複本是限時網址，過期要靠這個拿新的）。
//
// 二審必須是開案以外的另一位管理員：SAME_ADMIN、SELF_INVOLVED 顯示後端 message、
// 案件留在列表；CASE_ALREADY_REVIEWED 顯示 message 並回列表重抓。

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/date_format.dart';
import '../../models/admin_models.dart';
import '../../services/admin_service.dart';
import '../../shared/utils/utf16_length_limit.dart';
import '../../shared/widgets/confirm_dialog.dart';
import 'admin_cases_screen.dart';
import 'admin_error.dart';
import 'widgets/admin_reason_dialog.dart';
import 'widgets/admin_widgets.dart';

const _noteMax = 500;

class AdminCaseDetailScreen extends StatefulWidget {
  final AdminCase adminCase;

  const AdminCaseDetailScreen({super.key, required this.adminCase});

  @override
  State<AdminCaseDetailScreen> createState() => _AdminCaseDetailScreenState();
}

class _AdminCaseDetailScreenState extends State<AdminCaseDetailScreen> {
  final _note = TextEditingController();
  bool _busy = false;

  late AdminCase _case = widget.adminCase;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit(String decision) async {
    if (!withinUtf16Limit(context, _note.text, _noteMax, label: '備註')) return;
    final confirming = decision == 'confirm';
    final confirmed = await showConfirmDialog(
      context,
      title: confirming ? '確認違規？' : '撤銷這個案件？',
      message: confirming
          ? '確認後才會記違規：第 1 次禁言 14 天、第 2 次 30 天、第 3 次鎖帳號。'
          : '撤銷會恢復被隱藏的內容，並且不記違規。',
      confirmText: confirming ? '確認違規' : '撤銷',
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      final result = await AdminService.reviewCase(
        _case.id,
        decision,
        note: _note.text,
      );
      if (!mounted) return;
      await showAdminInfoDialog(
        context,
        title: confirming ? '已確認違規' : '已撤銷',
        message: _resultMessage(confirming, result),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      if (handleAdminError(context, e)) return;
      if (e is ApiException && e.code == 'CASE_ALREADY_REVIEWED') {
        Navigator.of(context).pop(true);
      }
    }
  }

  /// 後端沒有查單一案件的端點：沿同一個狀態的列表找回這個案件換成新的；
  /// 已不在這個狀態（被其他管理員處理了）就提示並回列表重抓。
  Future<void> _refresh() async {
    try {
      final result = await findInAdminPages(
        (cursor) =>
            AdminService.fetchCases(status: _case.status, cursor: cursor),
        (fresh) => fresh.id == _case.id,
      );
      if (!mounted) return;
      final found = result.found;
      if (found != null) {
        setState(() => _case = found);
      } else if (result.gone) {
        showAdminMessage('這筆已被其他管理員處理');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) handleAdminError(context, e);
    }
  }

  /// 被處置者已被鎖帳號時，誤判救援：解鎖並推播通知當事人。
  Future<void> _unlock() async {
    final input = await promptAdminReason(
      context,
      title: '解鎖帳號',
      description: '解除鎖定後，對方會收到「帳號已恢復」的通知；違規次數退回門檻以下，再犯即重鎖。',
      confirmMessage: '確定解鎖「${_case.offenderNickname}」的帳號？',
      confirmText: '解鎖',
      required: false,
    );
    if (input == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await AdminService.unlockUser(_case.offenderUid, note: input.reason);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _case = _case.withOffenderStatus('active');
      });
      showAdminMessage('已解鎖帳號');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      if (handleAdminError(context, e)) return;
      // 已不是鎖定狀態（別人先解了）：回列表以最新狀態為準。
      if (e is ApiException && e.code == 'NOT_LOCKED') {
        Navigator.of(context).pop(true);
      }
    }
  }

  String _resultMessage(bool confirming, AdminReviewResult result) {
    final lines = <String>[];
    if (confirming) {
      final strike = result.strike;
      if (strike == null) {
        lines.add(
          _case.targetType == 'mute' ? '已維持禁言。' : '已確認，不計違規次數（對方帳號已永久刪除）。',
        );
      } else {
        if (strike.strikeNumber != null) {
          lines.add('這是第 ${strike.strikeNumber} 次違規。');
        }
        if (strike.locked) {
          lines.add('帳號已鎖定。');
        } else if (strike.muteUntil != null) {
          lines.add('禁言到 ${formatDateTime(strike.muteUntil!)}。');
        }
        if (strike.cancelledEventCount > 0) {
          lines.add('連帶取消 ${strike.cancelledEventCount} 個主辦中的活動。');
        }
      }
    } else {
      if (_case.contentRemoved) {
        lines.add('已恢復內容。');
      } else if (_case.targetType == 'mute') {
        lines.add('已解除禁言。');
      } else {
        lines.add('已撤銷，不記違規。');
      }
      if (result.autoLiftedMuteId != null) lines.add('同時自動解除了該使用者的檢舉禁言。');
    }
    return lines.join('\n');
  }

  @override
  Widget build(BuildContext context) => AdminScaffold(
    title: '案件詳情',
    body: (context, senior) => RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        children: [
          AdminCaseCard(
            adminCase: _case,
            seniorMode: senior,
            compareSnapshot: true,
          ),
          if (_case.offenderStatus == 'locked')
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                0,
              ),
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _unlock,
                icon: const Icon(Icons.lock_open_outlined),
                label: const Text('解鎖帳號'),
              ),
            ),
          if (_case.isPending)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: TextField(
                controller: _note,
                maxLines: 3,
                inputFormatters: const [
                  Utf16LengthLimitingTextInputFormatter(_noteMax),
                ],
                buildCounter: utf16CounterBuilder(_note, _noteMax),
                decoration: const InputDecoration(
                  labelText: '備註（選填）',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
        ],
      ),
    ),
    bottom: (context, senior) => !_case.isPending
        ? const SizedBox.shrink()
        : AdminActionBar(
            children: [
              OutlinedButton(
                onPressed: _busy ? null : () => _submit('overturn'),
                child: const Text('撤銷'),
              ),
              FilledButton(
                onPressed: _busy ? null : () => _submit('confirm'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.creamLight,
                ),
                child: const Text('確認違規'),
              ),
            ],
          ),
  );
}
