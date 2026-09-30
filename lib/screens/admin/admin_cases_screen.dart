// 違規區：依狀態切換的案件列表，每筆顯示類型、被處置者、來源、理由、開案資訊與預覽。

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/utils/date_format.dart';
import '../../models/admin_models.dart';
import '../../services/admin_service.dart';
import 'admin_case_detail_screen.dart';
import 'admin_error.dart';
import 'widgets/admin_snapshot_compare.dart';
import 'widgets/admin_widgets.dart';

const _statuses = <AdminStatusOption>[
  (label: '待二審', value: 'pending'),
  (label: '已確認', value: 'confirmed'),
  (label: '已撤銷', value: 'overturned'),
];

class AdminCasesScreen extends StatelessWidget {
  const AdminCasesScreen({super.key});

  @override
  Widget build(BuildContext context) => AdminStatusListScreen<AdminCase>(
    title: '違規區',
    statuses: _statuses,
    emptyMessage: '這個狀態目前沒有案件',
    fetch: (status, cursor) =>
        AdminService.fetchCases(status: status, cursor: cursor),
    itemBuilder: (context, adminCase, senior, reload) => AdminCaseCard(
      adminCase: adminCase,
      seniorMode: senior,
      onTap: () async {
        // 二審、解鎖都可能改動案件，返回一律重抓。
        await pushAdmin<bool>(
          context,
          AdminCaseDetailScreen(adminCase: adminCase),
        );
        await reload();
      },
    ),
  );
}

String _profileFieldLabel(String key) => switch (key) {
  'video_nickname' => '暱稱',
  'self_intro' => '自我介紹',
  'avatar_url' => '頭像',
  _ => key,
};

/// 依案件類型呈現預覽。個人檔案並列「重設前」與「目前」。
class AdminCasePreviewView extends StatelessWidget {
  final AdminCase adminCase;
  final bool seniorMode;

  const AdminCasePreviewView({
    super.key,
    required this.adminCase,
    this.seniorMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final children = switch (adminCase.preview) {
      PostCasePreview(:final title, :final body) => [
        if (title != null) AdminQuote(title, seniorMode: seniorMode),
        if (body != null) AdminQuote(body, seniorMode: seniorMode),
      ],
      CommentCasePreview(:final body) => [
        if (body != null) AdminQuote(body, seniorMode: seniorMode),
      ],
      MessageCasePreview(:final body, :final sentAt) => [
        if (body != null) AdminQuote(body, seniorMode: seniorMode),
        if (sentAt != null)
          AdminInfoRow('傳送時間', formatDateTime(sentAt), seniorMode: seniorMode),
      ],
      CallCasePreview(:final call) => [
        AdminInfoRow(
          '通話雙方',
          '${call.callerUid ?? '?'} → ${call.calleeUid ?? '?'}',
          seniorMode: seniorMode,
        ),
        if (call.createdAt != null)
          AdminInfoRow(
            '時間',
            formatDateTime(call.createdAt!),
            seniorMode: seniorMode,
          ),
      ],
      EventCasePreview(:final title, :final description, :final startsAt) => [
        if (title != null) AdminQuote(title, seniorMode: seniorMode),
        if (description != null && description.isNotEmpty)
          AdminQuote(description, seniorMode: seniorMode),
        if (startsAt != null)
          AdminInfoRow(
            '活動時間',
            formatDateTime(startsAt),
            seniorMode: seniorMode,
          ),
      ],
      MuteCasePreview(:final scope, :final muteUntil, :final liftedAt) => [
        AdminInfoRow('禁言範圍', scope ?? '—', seniorMode: seniorMode),
        if (muteUntil != null)
          AdminInfoRow(
            '到期時間',
            formatDateTime(muteUntil),
            seniorMode: seniorMode,
          ),
        if (liftedAt != null)
          AdminInfoRow(
            '已解除於',
            formatDateTime(liftedAt),
            seniorMode: seniorMode,
          ),
      ],
      ProfileCasePreview(:final before, :final current) => [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            '重設前',
            style: AppTypography.subtitleStyle(
              seniorMode: seniorMode,
              color: AppColors.ink,
            ),
          ),
        ),
        if (before.isEmpty)
          AdminInfoRow('內容', '（沒有紀錄）', seniorMode: seniorMode)
        else
          for (final entry in before.entries)
            AdminInfoRow(
              _profileFieldLabel(entry.key),
              '${entry.value ?? '（空）'}',
              seniorMode: seniorMode,
            ),
        if (current != null) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '目前',
              style: AppTypography.subtitleStyle(
                seniorMode: seniorMode,
                color: AppColors.ink,
              ),
            ),
          ),
          AdminInfoRow('暱稱', current.nickname ?? '（無）', seniorMode: seniorMode),
          AdminInfoRow(
            '自我介紹',
            (current.selfIntro?.isNotEmpty ?? false)
                ? current.selfIntro!
                : '（無）',
            seniorMode: seniorMode,
          ),
          AdminInfoRow(
            '頭像',
            current.avatarUrl ?? current.avatarId ?? '（預設）',
            seniorMode: seniorMode,
          ),
        ],
      ],
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

class AdminCaseCard extends StatelessWidget {
  final AdminCase adminCase;
  final bool seniorMode;
  final VoidCallback? onTap;

  /// 詳情頁為 true：有開案那筆檢舉當時的內容時，與目前的內容並列。
  final bool compareSnapshot;

  const AdminCaseCard({
    super.key,
    required this.adminCase,
    this.seniorMode = false,
    this.onTap,
    this.compareSnapshot = false,
  });

  Widget _content() {
    final current = AdminCasePreviewView(
      adminCase: adminCase,
      seniorMode: seniorMode,
    );
    final snapshot = adminCase.reportSnapshot;
    if (!compareSnapshot || snapshot == null) return current;
    return AdminSnapshotCompare(
      snapshot: snapshot,
      targetType: adminCase.targetType,
      current: current,
      seniorMode: seniorMode,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = adminCase;
    return AdminCard(
      seniorMode: seniorMode,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AdminBadge(
                adminTargetTypeLabel(c.targetType),
                seniorMode: seniorMode,
              ),
              const SizedBox(width: 8),
              AdminBadge(
                adminCaseStatusLabel(c.status),
                color: AppColors.moss,
                seniorMode: seniorMode,
              ),
              const Spacer(),
              if (c.openedAt != null)
                Text(
                  formatDateTime(c.openedAt!),
                  style: AppTypography.captionStyle(
                    seniorMode: seniorMode,
                    color: AppColors.fog,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            c.reason,
            style: AppTypography.bodyLargeStyle(
              seniorMode: seniorMode,
              color: AppColors.ink,
            ),
          ),
          AdminInfoRow(
            '被處置者',
            '${c.offenderNickname}'
                '${c.offenderStatus == null ? '' : '（${c.offenderStatus}）'}',
            seniorMode: seniorMode,
          ),
          if (c.offenderFriendCode != null && c.offenderFriendCode!.isNotEmpty)
            AdminInfoRow('好友碼', c.offenderFriendCode!, seniorMode: seniorMode),
          AdminInfoRow(
            '來源',
            adminCaseSourceLabel(c.source),
            seniorMode: seniorMode,
          ),
          AdminInfoRow(
            '開案者',
            c.openedByNickname ?? '系統',
            seniorMode: seniorMode,
          ),
          _content(),
          if (c.status != 'pending') ...[
            const SizedBox(height: 8),
            AdminInfoRow(
              '審核者',
              c.reviewedByNickname ?? '—',
              seniorMode: seniorMode,
            ),
            if (c.reviewedAt != null)
              AdminInfoRow(
                '審核時間',
                formatDateTime(c.reviewedAt!),
                seniorMode: seniorMode,
              ),
            if (c.reviewNote != null && c.reviewNote!.isNotEmpty)
              AdminInfoRow('備註', c.reviewNote!, seniorMode: seniorMode),
            if (c.strikeNumber != null)
              AdminInfoRow(
                '違規次數',
                '第 ${c.strikeNumber} 次',
                seniorMode: seniorMode,
              ),
          ],
        ],
      ),
    );
  }
}
