// 檢舉詳情：完整預覽＋「駁回」「判定成立」（一審）。
// 有檢舉當時的內容時與目前的內容並列；下拉重新整理會重抓這筆檢舉
// （頭像複本是限時網址，過期要靠這個拿新的）。
//
// 處理完（或發現已被別人處理）以 pop(true) 通知列表重新整理。錯誤一律顯示後端
// message：SELF_INVOLVED 留在本頁（交給別位管理員）、ALREADY_REVIEWED 直接回列表
// 重抓、TARGET_NOT_FOUND 提示改用駁回。

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_typography.dart';
import '../../core/network/api_client.dart';
import '../../models/admin_models.dart';
import '../../services/admin_service.dart';
import '../../shared/widgets/confirm_dialog.dart';
import 'admin_error.dart';
import 'admin_reports_screen.dart';
import 'widgets/admin_profile_field_picker.dart';
import 'widgets/admin_widgets.dart';

class AdminReportDetailScreen extends StatefulWidget {
  final AdminReport report;

  const AdminReportDetailScreen({super.key, required this.report});

  @override
  State<AdminReportDetailScreen> createState() =>
      _AdminReportDetailScreenState();
}

class _AdminReportDetailScreenState extends State<AdminReportDetailScreen> {
  final Set<String> _resetFields = AdminProfileFieldPicker.allFields;
  bool _busy = false;

  /// 判定成立時後端說找不到被檢舉對象：這筆只能駁回。
  bool _targetGone = false;

  late AdminReport _report = widget.report;
  bool get _isProfile => _report.targetType == 'profile';

  /// 後端沒有查單筆檢舉的端點：沿同一個狀態的佇列找回這筆換成新的；
  /// 已不在這個狀態（被其他管理員處理了）就提示並回列表重抓。
  Future<void> _refresh() async {
    try {
      final result = await findInAdminPages(
        (cursor) =>
            AdminService.fetchReports(status: _report.status, cursor: cursor),
        (fresh) => fresh.id == _report.id,
      );
      if (!mounted) return;
      final found = result.found;
      if (found != null) {
        setState(() => _report = found);
      } else if (result.gone) {
        showAdminMessage('這筆已被其他管理員處理');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) handleAdminError(context, e);
    }
  }

  Future<void> _submit(String action) async {
    final actioned = action == 'action';
    final confirmed = await showConfirmDialog(
      context,
      title: actioned ? '判定成立？' : '駁回這筆檢舉？',
      message: actioned ? '內容會立刻隱藏並開案，送進違規區等另一位管理員二審。' : '不動內容、不開案，這筆檢舉結案。',
      confirmText: actioned ? '判定成立' : '駁回',
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      final result = await AdminService.resolveReport(
        _report.id,
        action,
        resetFields: actioned && _isProfile ? _resetFields.toList() : null,
      );
      if (!mounted) return;
      await _showResult(result);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      if (handleAdminError(context, e)) return;
      if (e is! ApiException) return;
      if (e.code == 'ALREADY_REVIEWED') Navigator.of(context).pop(true);
      if (e.code == 'TARGET_NOT_FOUND') setState(() => _targetGone = true);
    }
  }

  Future<void> _showResult(AdminResolveResult result) async {
    if (result.status == 'dismissed') {
      showAdminMessage(
        result.autoLiftedMuteId == null ? '已駁回' : '已駁回，已自動解除該使用者的檢舉禁言',
      );
      return;
    }
    final lines = [
      '已開案（案件編號 ${result.openedCase?.id ?? '—'}），送進違規區等二審。',
      if (result.autoClosedReportIds.isNotEmpty)
        '同一則內容另有 ${result.autoClosedReportIds.length} 筆檢舉一併結案。',
    ];
    await showAdminInfoDialog(
      context,
      title: '已判定成立',
      message: lines.join('\n'),
    );
  }

  @override
  Widget build(BuildContext context) => AdminScaffold(
    title: '檢舉詳情',
    body: (context, senior) => RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        children: [
          AdminReportCard(
            report: _report,
            seniorMode: senior,
            compareSnapshot: true,
          ),
          if (_report.status == 'pending') ...[
            if (_isProfile)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  0,
                ),
                child: AdminProfileFieldPicker(
                  selected: _resetFields,
                  seniorMode: senior,
                  onChanged: (fields) => setState(() {
                    _resetFields
                      ..clear()
                      ..addAll(fields);
                  }),
                ),
              ),
            if (_targetGone)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  0,
                ),
                child: Text(
                  '找不到被檢舉的對象，這筆請改用「駁回」。',
                  style: AppTypography.bodyLargeStyle(
                    seniorMode: senior,
                    color: AppColors.dangerDark,
                  ),
                ),
              ),
          ],
        ],
      ),
    ),
    bottom: (context, senior) => _report.status != 'pending'
        ? const SizedBox.shrink()
        : AdminActionBar(
            children: [
              OutlinedButton(
                onPressed: _busy ? null : () => _submit('dismiss'),
                child: const Text('駁回'),
              ),
              FilledButton(
                onPressed:
                    _busy || _targetGone || (_isProfile && _resetFields.isEmpty)
                    ? null
                    : () => _submit('action'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.creamLight,
                ),
                child: const Text('判定成立'),
              ),
            ],
          ),
  );
}
