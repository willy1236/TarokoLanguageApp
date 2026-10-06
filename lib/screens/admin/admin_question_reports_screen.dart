// 題目錯誤回報：待處理優先，可篩選狀態，標記已查看／已解決。

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/utils/date_format.dart';
import '../../models/admin_models.dart';
import '../../services/admin_service.dart';
import 'admin_error.dart';
import 'widgets/admin_widgets.dart';

// 「全部」不帶 status，後端排序待處理優先。
const _statuses = <AdminStatusOption>[
  (label: '全部', value: ''),
  (label: '待處理', value: 'pending'),
  (label: '已查看', value: 'reviewed'),
  (label: '已解決', value: 'resolved'),
];

class AdminQuestionReportsScreen extends StatelessWidget {
  const AdminQuestionReportsScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      AdminStatusListScreen<AdminQuestionReport>(
        title: '題目回報',
        statuses: _statuses,
        emptyMessage: '這個狀態目前沒有回報',
        fetch: (status, cursor) =>
            AdminService.fetchQuestionReports(status: status, cursor: cursor),
        itemBuilder: (context, report, senior, reload) => _QuestionReportCard(
          key: ValueKey(report.id),
          report: report,
          seniorMode: senior,
          reload: reload,
        ),
      );
}

class _QuestionReportCard extends StatefulWidget {
  final AdminQuestionReport report;
  final bool seniorMode;
  final Future<void> Function() reload;

  const _QuestionReportCard({
    super.key,
    required this.report,
    required this.seniorMode,
    required this.reload,
  });

  @override
  State<_QuestionReportCard> createState() => _QuestionReportCardState();
}

class _QuestionReportCardState extends State<_QuestionReportCard> {
  /// 標記送出中：這一筆的兩顆標記鈕都停用，連點只送一次。
  bool _busy = false;

  AdminQuestionReport get report => widget.report;
  bool get seniorMode => widget.seniorMode;

  Future<void> _mark(String status) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await AdminService.updateQuestionReport(report.id, status);
      showAdminMessage('已標記為${adminQuestionReportStatusLabel(status)}');
      await widget.reload();
    } catch (e) {
      if (!mounted) return;
      handleAdminError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final truku = report.contentTruku;
    final zh = report.contentZh;
    return AdminCard(
      seniorMode: seniorMode,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AdminBadge(
                adminQuestionTypeLabel(report.questionType),
                seniorMode: seniorMode,
              ),
              const SizedBox(width: 8),
              AdminBadge(
                adminQuestionReportStatusLabel(report.status),
                color: AppColors.moss,
                seniorMode: seniorMode,
              ),
              const Spacer(),
              if (report.createdAt != null)
                Text(
                  formatDateTime(report.createdAt!),
                  style: AppTypography.captionStyle(
                    seniorMode: seniorMode,
                    color: AppColors.fog,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            report.message,
            style: AppTypography.bodyLargeStyle(
              seniorMode: seniorMode,
              color: AppColors.ink,
            ),
          ),
          if (truku != null) AdminInfoRow('族語', truku, seniorMode: seniorMode),
          if (zh != null) AdminInfoRow('中文', zh, seniorMode: seniorMode),
          AdminInfoRow(
            '回報人',
            report.reporterNickname ?? '（未知）',
            seniorMode: seniorMode,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 8,
              children: [
                if (report.status != 'reviewed')
                  TextButton(
                    onPressed: _busy ? null : () => _mark('reviewed'),
                    child: const Text('標為已查看'),
                  ),
                if (report.status != 'resolved')
                  TextButton(
                    onPressed: _busy ? null : () => _mark('resolved'),
                    child: const Text('標為已解決'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
