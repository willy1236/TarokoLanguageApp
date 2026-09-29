// 檢舉佇列：依狀態切換，每筆顯示類型、理由、檢舉人、時間與被檢舉內容預覽。

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/utils/date_format.dart';
import '../../models/admin_models.dart';
import '../../services/admin_service.dart';
import 'admin_error.dart';
import 'admin_report_detail_screen.dart';
import 'widgets/admin_widgets.dart';

const _statuses = <AdminStatusOption>[
  (label: '待審', value: 'pending'),
  (label: '已審', value: 'reviewed'),
  (label: '已駁回', value: 'dismissed'),
  (label: '已成立', value: 'actioned'),
];

String adminReportStatusLabel(String status) => switch (status) {
  'pending' => '待審',
  'reviewed' => '已審',
  'dismissed' => '已駁回',
  'actioned' => '已成立',
  _ => status,
};

class AdminReportsScreen extends StatelessWidget {
  const AdminReportsScreen({super.key});

  @override
  Widget build(BuildContext context) => AdminStatusListScreen<AdminReport>(
    title: '檢舉佇列',
    statuses: _statuses,
    emptyMessage: '這個狀態目前沒有檢舉',
    fetch: (status, cursor) =>
        AdminService.fetchReports(status: status, cursor: cursor),
    itemBuilder: (context, report, senior, reload) => AdminReportCard(
      report: report,
      seniorMode: senior,
      onTap: () async {
        final changed = await pushAdmin<bool>(
          context,
          AdminReportDetailScreen(report: report),
        );
        if (changed ?? false) await reload();
      },
    ),
  );
}

/// 檢舉的預覽內容：貼文／留言／私訊／活動用文字預覽，通話與個人檔案各有專用欄位。
class AdminReportPreview extends StatelessWidget {
  final AdminReport report;
  final bool seniorMode;

  const AdminReportPreview({
    super.key,
    required this.report,
    this.seniorMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final call = report.targetCall;
    final profile = report.targetProfile;
    final preview = report.targetPreview;
    final children = <Widget>[
      if (report.targetDeleted)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: AdminBadge(
            '內容已刪除',
            color: AppColors.dangerDark,
            seniorMode: seniorMode,
          ),
        ),
      if (preview != null && preview.isNotEmpty)
        AdminQuote(preview, seniorMode: seniorMode),
      if (call != null) ...[
        AdminInfoRow(
          '通話',
          '${call.callerUid ?? '?'} → ${call.calleeUid ?? '?'}'
              '（${call.status ?? '未知'}）',
          seniorMode: seniorMode,
        ),
        if (call.createdAt != null)
          AdminInfoRow(
            '發起時間',
            formatDateTime(call.createdAt!),
            seniorMode: seniorMode,
          ),
      ],
      if (profile != null) ...[
        AdminInfoRow('暱稱', profile.nickname ?? '（無）', seniorMode: seniorMode),
        AdminInfoRow(
          '自我介紹',
          (profile.selfIntro?.isNotEmpty ?? false) ? profile.selfIntro! : '（無）',
          seniorMode: seniorMode,
        ),
        AdminInfoRow(
          '頭像',
          profile.avatarUrl ?? profile.avatarId ?? '（預設）',
          seniorMode: seniorMode,
        ),
      ],
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

class AdminReportCard extends StatelessWidget {
  final AdminReport report;
  final bool seniorMode;
  final VoidCallback? onTap;

  const AdminReportCard({
    super.key,
    required this.report,
    this.seniorMode = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => AdminCard(
    seniorMode: seniorMode,
    onTap: onTap,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            AdminBadge(
              adminTargetTypeLabel(report.targetType),
              seniorMode: seniorMode,
            ),
            const SizedBox(width: 8),
            AdminBadge(
              adminReportStatusLabel(report.status),
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
          report.reason,
          style: AppTypography.bodyLargeStyle(
            seniorMode: seniorMode,
            color: AppColors.ink,
          ),
        ),
        AdminInfoRow(
          '檢舉人',
          report.reporterNickname ?? '（未知）',
          seniorMode: seniorMode,
        ),
        AdminReportPreview(report: report, seniorMode: seniorMode),
      ],
    ),
  );
}
