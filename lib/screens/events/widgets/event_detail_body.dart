// 活動詳情頁內文：發起人、讚／收藏、時間地點、名額、介紹、提醒紀錄、聯絡資訊。

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_format.dart';
import '../../../models/event_model.dart';
import '../../../shared/widgets/engagement_icon_button.dart';
import '../../../core/constants/app_typography.dart';

class EventDetailBody extends StatelessWidget {
  final EventDetail event;

  /// 目前登入者 uid（判斷是否為發起人）。
  final int? uid;
  final List<EventReminder> reminders;
  final bool seniorMode;
  final VoidCallback onToggleLike;
  final VoidCallback onToggleBookmark;

  const EventDetailBody({
    super.key,
    required this.event,
    required this.uid,
    required this.reminders,
    required this.seniorMode,
    required this.onToggleLike,
    required this.onToggleBookmark,
  });

  @override
  Widget build(BuildContext context) => _buildBody(event, seniorMode);

  Widget _buildBody(EventDetail e, bool seniorMode) {
    final start = e.startsAt.toLocal();
    final timeText = formatDateTime(start);
    final hostName =
        e.participants
            .where((p) => p.uid == e.hostUid)
            .map((p) => p.displayName)
            .firstWhere((n) => n != null && n.isNotEmpty, orElse: () => null) ??
        '發起人';
    final isHost = e.isHostedBy(uid);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 發起人
          Row(
            children: [
              CircleAvatar(
                radius: seniorMode ? 20 : 15,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: Icon(
                  Icons.person,
                  size: seniorMode ? 22 : 16,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '發起人',
                    style: TextStyle(
                      fontSize: AppTypography.size(AppTypography.micro, seniorMode: seniorMode),
                      color: AppColors.fog,
                      letterSpacing: 1.5,
                    ),
                  ),
                  Text(
                    hostName,
                    style: GoogleFonts.notoSerifTc(
                      fontSize: AppTypography.size(AppTypography.body, seniorMode: seniorMode),
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
              if (isHost) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '你發起的',
                    style: TextStyle(
                      fontSize: AppTypography.size(AppTypography.micro, seniorMode: seniorMode),
                      color: AppColors.goldDeep,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              EngagementIconButton(
                icon: e.isLiked ? Icons.favorite : Icons.favorite_border,
                color: e.isLiked ? AppColors.primary : AppColors.fog,
                count: e.likeCount,
                onTap: onToggleLike,
                seniorMode: seniorMode,
              ),
              const SizedBox(width: 6),
              EngagementIconButton(
                icon: e.isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                color: e.isBookmarked ? AppColors.primary : AppColors.fog,
                onTap: onToggleBookmark,
                seniorMode: seniorMode,
              ),
            ],
          ),
          const SizedBox(height: 20),

          _infoRow(Icons.access_time, '時間', timeText, seniorMode),
          const SizedBox(height: 12),
          if (e.location != null && e.location!.isNotEmpty) ...[
            _infoRow(Icons.location_on_outlined, '地點', e.location!, seniorMode),
            const SizedBox(height: 12),
          ],
          if (e.address != null && e.address!.isNotEmpty) ...[
            _infoRow(Icons.map_outlined, '地址', e.address!, seniorMode),
            const SizedBox(height: 12),
          ],
          if (e.registrationDeadline != null) ...[
            _infoRow(
              Icons.how_to_reg_outlined,
              '報名截止',
              formatDateTime(e.registrationDeadline!.toLocal()),
              seniorMode,
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 8),

          // 名額
          _buildCapacity(e, seniorMode),
          const SizedBox(height: 22),

          // 介紹
          if (e.description != null && e.description!.isNotEmpty) ...[
            Text(
              '活動介紹',
              style: GoogleFonts.notoSerifTc(
                fontSize: AppTypography.size(AppTypography.bodyLarge, seniorMode: seniorMode),
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              e.description!,
              style: TextStyle(
                fontSize: AppTypography.size(AppTypography.body, seniorMode: seniorMode),
                color: AppColors.inkSoft,
                height: 1.7,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 22),
          ],

          // 提醒事項
          if (e.reminderNote != null && e.reminderNote!.isNotEmpty) ...[
            _buildNoteBox('提醒事項', e.reminderNote!, seniorMode),
            const SizedBox(height: 16),
          ],

          // 提醒紀錄：排定發送（尚未送出）／已發送（含失敗、取消等已處理完的）
          if (reminders.isNotEmpty) ...[
            Text(
              '提醒紀錄',
              style: GoogleFonts.notoSerifTc(
                fontSize: AppTypography.size(AppTypography.bodyLarge, seniorMode: seniorMode),
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            if (_pendingReminders().isNotEmpty) ...[
              _buildReminderGroupLabel('排定發送', seniorMode),
              const SizedBox(height: 6),
              for (final r in _pendingReminders()) ...[
                _buildReminderCard(r, seniorMode),
                const SizedBox(height: 10),
              ],
            ],
            if (_sentReminders().isNotEmpty) ...[
              _buildReminderGroupLabel('已發送', seniorMode),
              const SizedBox(height: 6),
              for (final r in _sentReminders()) ...[
                _buildReminderCard(r, seniorMode),
                const SizedBox(height: 10),
              ],
            ],
            const SizedBox(height: 2),
          ],

          // 聯絡資訊
          if ((e.contactEmail != null && e.contactEmail!.isNotEmpty) ||
              (e.contactPhone != null && e.contactPhone!.isNotEmpty)) ...[
            Text(
              '聯絡資訊',
              style: GoogleFonts.notoSerifTc(
                fontSize: AppTypography.size(AppTypography.bodyLarge, seniorMode: seniorMode),
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            if (e.contactEmail != null && e.contactEmail!.isNotEmpty)
              _infoRow(
                Icons.email_outlined,
                'Email',
                e.contactEmail!,
                seniorMode,
              ),
            if (e.contactPhone != null && e.contactPhone!.isNotEmpty) ...[
              const SizedBox(height: 8),
              _infoRow(Icons.phone_outlined, '電話', e.contactPhone!, seniorMode),
            ],
          ],
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, bool seniorMode) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: seniorMode ? 22 : 16, color: AppColors.primary),
        const SizedBox(width: 12),
        Text(
          '$label ',
          style: TextStyle(
            fontSize: AppTypography.size(AppTypography.caption, seniorMode: seniorMode),
            color: AppColors.fog,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: AppTypography.size(AppTypography.body, seniorMode: seniorMode),
              color: AppColors.ink,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoteBox(String title, String body, bool seniorMode) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.push_pin_outlined,
                size: seniorMode ? 18 : 14,
                color: AppColors.goldDeep,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: AppTypography.size(AppTypography.caption, seniorMode: seniorMode),
                  color: AppColors.goldDeep,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(
              fontSize: AppTypography.size(AppTypography.body, seniorMode: seniorMode),
              color: AppColors.inkSoft,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  /// 排定發送（尚未送出）：依排定時間由近到遠排序。
  List<EventReminder> _pendingReminders() {
    final list = reminders.where((r) => r.status == 'pending').toList();
    list.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return list;
  }

  /// 已發送（含失敗、取消等已處理完的）：新的（id 較大）排在前面；
  /// 後端固定回傳 scheduled_at 遞增排序，這裡反過來。
  List<EventReminder> _sentReminders() {
    final list = reminders.where((r) => r.status != 'pending').toList();
    list.sort((a, b) => b.id.compareTo(a.id));
    return list;
  }

  Widget _buildReminderGroupLabel(String text, bool seniorMode) {
    return Text(
      text,
      style: TextStyle(
        fontSize: AppTypography.size(AppTypography.caption, seniorMode: seniorMode),
        color: AppColors.fog,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildReminderCard(EventReminder r, bool seniorMode) {
    final (label, color) = switch (r.status) {
      'sent' => (
        '已發送 · ${formatDateTime((r.sentAt ?? r.scheduledAt).toLocal())}',
        AppColors.mossDeep,
      ),
      'failed' => ('發送失敗', AppColors.dangerDark),
      'cancelled' => ('已取消', AppColors.fog),
      _ => (
        '排定於 ${formatDateTime(r.scheduledAt.toLocal())}',
        AppColors.primary,
      ),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.creamDeep),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            r.message,
            style: TextStyle(
              fontSize: AppTypography.size(AppTypography.body, seniorMode: seniorMode),
              color: AppColors.ink,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: AppTypography.size(AppTypography.caption, seniorMode: seniorMode),
              color: color,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCapacity(EventDetail e, bool seniorMode) {
    final count = e.participantCount;
    final max = e.maxParticipants;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.creamDeep),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '報名人數',
                style: TextStyle(
                  fontSize: AppTypography.size(AppTypography.caption, seniorMode: seniorMode),
                  color: AppColors.inkSoft,
                  letterSpacing: 1.0,
                ),
              ),
              Text(
                max == null
                    ? '$count 人 · 不限名額'
                    : '$count / $max 人 · 剩 ${max - count} 個名額',
                style: TextStyle(
                  fontSize: AppTypography.size(AppTypography.caption, seniorMode: seniorMode),
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (max != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: max == 0 ? 0 : (count / max).clamp(0.0, 1.0),
                backgroundColor: AppColors.creamDeep,
                valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                minHeight: 6,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
