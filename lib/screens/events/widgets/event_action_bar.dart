// 活動詳情頁底部行動列：依身分（發起人／已報名／其他）與活動狀態切換按鈕。

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/event_model.dart';
import '../reminder_compose_screen.dart';
import '../../../core/constants/app_typography.dart';

class EventActionBar extends StatelessWidget {
  final EventDetail event;

  /// 目前登入者 uid（判斷是否為發起人／已報名）。
  final int? uid;

  /// 參加／退出／取消等操作進行中：按鈕停用並顯示轉圈。
  final bool acting;
  final bool seniorMode;
  final VoidCallback onJoin;
  final VoidCallback onLeave;
  final VoidCallback onCancel;
  final VoidCallback onEdit;
  final VoidCallback onExport;
  final VoidCallback onDelete;

  const EventActionBar({
    super.key,
    required this.event,
    required this.uid,
    required this.acting,
    required this.seniorMode,
    required this.onJoin,
    required this.onLeave,
    required this.onCancel,
    required this.onEdit,
    required this.onExport,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) =>
      _buildActionBar(context, event, seniorMode);

  Widget _buildActionBar(BuildContext context, EventDetail e, bool seniorMode) {
    final isHost = e.isHostedBy(uid);
    final isJoined = e.isJoinedBy(uid);
    final status = e.displayStatus;

    Widget content;
    if (status == 'cancelled') {
      content = _disabledButton('活動已取消', seniorMode);
    } else if (status == 'ended') {
      content = _disabledButton('活動已結束', seniorMode);
    } else if (isHost) {
      content = _hostActions(context, e, seniorMode);
    } else if (isJoined) {
      content = _joinedActions(seniorMode);
    } else if (e.registrationOpen && !e.isFull) {
      content = _primaryButton('我要參加', acting ? null : onJoin, seniorMode);
    } else if (e.isFull) {
      content = _disabledButton('名額已滿', seniorMode);
    } else {
      content = _disabledButton('報名已截止', seniorMode);
    }

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        decoration: BoxDecoration(
          color: AppColors.creamLight,
          border: Border(top: BorderSide(color: AppColors.creamDeep)),
        ),
        child: content,
      ),
    );
  }

  // 發起人：發送提醒 + 取消活動
  Widget _hostActions(BuildContext context, EventDetail e, bool seniorMode) {
    final sendReminderButton = GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ReminderComposeScreen(eventId: e.id, eventTitle: e.title),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_active_outlined,
              color: AppColors.creamLight,
              size: seniorMode ? 24 : 18,
            ),
            const SizedBox(width: 8),
            Text(
              '發送提醒',
              style: GoogleFonts.notoSerifTc(
                fontSize: AppTypography.size(AppTypography.bodyLarge, seniorMode: seniorMode),
                fontWeight: FontWeight.w600,
                color: AppColors.creamLight,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
    final cancelButton = GestureDetector(
      onTap: acting ? null : onCancel,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.danger.withValues(alpha: 0.5)),
        ),
        child: Center(
          heightFactor: 1.0,
          child: Text(
            '取消活動',
            style: GoogleFonts.notoSerifTc(
              fontSize: AppTypography.size(AppTypography.body, seniorMode: seniorMode),
              fontWeight: FontWeight.w600,
              color: AppColors.dangerDark,
              letterSpacing: 1.0,
            ),
          ),
        ),
      ),
    );
    final notStarted = e.startsAt.isAfter(DateTime.now());
    final manageRow = Row(
      children: [
        TextButton.icon(
          onPressed: acting ? null : onEdit,
          icon: Icon(Icons.edit_outlined, size: seniorMode ? 22 : 16),
          label: Text('編輯活動', style: TextStyle(fontSize: AppTypography.size(AppTypography.body, seniorMode: seniorMode))),
        ),
        TextButton.icon(
          onPressed: acting ? null : onExport,
          icon: Icon(Icons.file_download_outlined, size: seniorMode ? 22 : 16),
          label: Text('匯出名單', style: TextStyle(fontSize: AppTypography.size(AppTypography.body, seniorMode: seniorMode))),
        ),
        if (notStarted)
          TextButton.icon(
            onPressed: acting ? null : onDelete,
            icon: Icon(
              Icons.delete_outline,
              size: seniorMode ? 22 : 16,
              color: AppColors.dangerDark,
            ),
            label: Text(
              '刪除活動',
              style: TextStyle(
                fontSize: AppTypography.size(AppTypography.body, seniorMode: seniorMode),
                color: AppColors.dangerDark,
              ),
            ),
          ),
      ],
    );
    if (seniorMode) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          manageRow,
          const SizedBox(height: 4),
          SizedBox(width: double.infinity, child: sendReminderButton),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: cancelButton),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        manageRow,
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(flex: 2, child: sendReminderButton),
            const SizedBox(width: 10),
            Expanded(flex: 1, child: cancelButton),
          ],
        ),
      ],
    );
  }

  // 參加者：已報名（可退出）
  Widget _joinedActions(bool seniorMode) {
    final joinedBadge = Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        color: AppColors.moss.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.moss.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            color: AppColors.mossDeep,
            size: seniorMode ? 24 : 18,
          ),
          const SizedBox(width: 8),
          Text(
            '已報名',
            style: GoogleFonts.notoSerifTc(
              fontSize: AppTypography.size(AppTypography.bodyLarge, seniorMode: seniorMode),
              fontWeight: FontWeight.w600,
              color: AppColors.mossDeep,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
    final leaveButton = GestureDetector(
      onTap: acting ? null : onLeave,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: seniorMode ? 24 : 18,
          vertical: 15,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.fog),
        ),
        child: Center(
          heightFactor: 1.0,
          child: Text(
            '退出',
            style: TextStyle(
              fontSize: AppTypography.size(AppTypography.body, seniorMode: seniorMode),
              color: AppColors.inkSoft,
              letterSpacing: 1.0,
            ),
          ),
        ),
      ),
    );
    if (seniorMode) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: double.infinity, child: joinedBadge),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: leaveButton),
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: joinedBadge),
        const SizedBox(width: 10),
        leaveButton,
      ],
    );
  }

  Widget _primaryButton(String label, VoidCallback? onTap, bool seniorMode) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: onTap == null
              ? AppColors.primary.withValues(alpha: 0.5)
              : AppColors.primary,
          borderRadius: BorderRadius.circular(14),
        ),
        // heightFactor: 1.0 讓 Center 收縮到子元件高度；預設在 Scaffold
        // bottomNavigationBar 的有界高度下會撐滿整個高度，把 body 擠成 0。
        child: Center(
          heightFactor: 1.0,
          child: acting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.creamLight,
                  ),
                )
              : Text(
                  label,
                  style: GoogleFonts.notoSerifTc(
                    fontSize: AppTypography.size(AppTypography.bodyLarge, seniorMode: seniorMode),
                    fontWeight: FontWeight.w600,
                    color: AppColors.creamLight,
                    letterSpacing: 2.0,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _disabledButton(String label, bool seniorMode) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        color: AppColors.fog.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        heightFactor: 1.0,
        child: Text(
          label,
          style: TextStyle(
            fontSize: AppTypography.size(AppTypography.bodyLarge, seniorMode: seniorMode),
            fontWeight: FontWeight.w600,
            color: AppColors.inkSoft,
            letterSpacing: 2.0,
          ),
        ),
      ),
    );
  }
}
