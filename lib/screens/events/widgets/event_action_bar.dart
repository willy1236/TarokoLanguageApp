// 活動詳情頁底部行動列：依身分（發起人／已報名／其他）與活動狀態切換按鈕。

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/event_model.dart';
import '../../../services/account_lock_controller.dart';
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

  /// 發送提醒成功後回呼（詳情頁據此重抓提醒紀錄）。ReminderComposeScreen 已
  /// 依專案慣例 pop(context, true)，這裡負責把它接回上層。
  final Future<void> Function()? onReminderSent;

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
    this.onReminderSent,
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
        if (blockIfReadOnly()) return;
        final sent = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ReminderComposeScreen(eventId: e.id, eventTitle: e.title),
          ),
        );
        if (sent == true) await onReminderSent?.call();
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
              style: AppTypography.serif(
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
            style: AppTypography.serif(
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
    final manageButtons = <Widget>[
      // 後端只允許編輯未開始的活動，開始後 PATCH 回 409 EVENT_ENDED。
      if (notStarted)
        _outlinedButton(
          label: '編輯活動',
          icon: Icons.edit_outlined,
          onTap: acting ? null : onEdit,
          seniorMode: seniorMode,
        ),
      _outlinedButton(
        label: '匯出名單',
        icon: Icons.file_download_outlined,
        onTap: acting ? null : onExport,
        seniorMode: seniorMode,
      ),
      if (notStarted)
        _outlinedButton(
          label: '刪除活動',
          icon: Icons.delete_outline,
          onTap: acting ? null : onDelete,
          seniorMode: seniorMode,
          danger: true,
        ),
    ];
    // 精簡模式字大，三顆並排一定爆版，改成一顆一列。
    final manageRow = seniorMode
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < manageButtons.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                SizedBox(width: double.infinity, child: manageButtons[i]),
              ],
            ],
          )
        : Row(
            children: [
              for (int i = 0; i < manageButtons.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(child: manageButtons[i]),
              ],
            ],
          );
    if (seniorMode) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          manageRow,
          const SizedBox(height: 10),
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
        const SizedBox(height: 10),
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

  /// 發起人管理動作共用的外框按鈕，樣式與底部的「取消活動」一致（透明底、圓角
  /// 14、文字置中）；danger 為 true 時用紅色系，標示破壞性動作。
  Widget _outlinedButton({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
    required bool seniorMode,
    bool danger = false,
  }) {
    final color = danger ? AppColors.dangerDark : AppColors.primary;
    final borderColor = (danger ? AppColors.danger : AppColors.primary)
        .withValues(alpha: 0.5);
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: disabled ? 0.4 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: seniorMode ? 22 : 16, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.serif(
                    fontSize: AppTypography.size(
                      AppTypography.body,
                      seniorMode: seniorMode,
                    ),
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
            style: AppTypography.serif(
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
                  style: AppTypography.serif(
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
