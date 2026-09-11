// 個人頁共用的列與區塊原語（section 外框、設定列、開關列、導覽列、統計格、
// 快速入口卡）與圖示 painter。都是純展示，狀態與動作由 ProfileScreen 傳入。

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';

Widget profileInfoBadge(String text) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.gold.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
    ),
    child: Text(
      text,
      style: AppTypography.bodyLargeStyle(color: AppColors.goldDeep),
    ),
  );
}

Widget profileStatDivider() => const SizedBox(
  height: 32,
  child: VerticalDivider(color: AppColors.creamDeep, width: 1),
);

Widget profileStatCell(bool seniorMode, String value, String label) {
  return Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: AppTypography.titleStyle(
            seniorMode: seniorMode,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTypography.bodyLargeStyle(
            seniorMode: seniorMode,
            color: AppColors.fog,
          ),
        ),
      ],
    ),
  );
}

class ProfileQuickLink {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const ProfileQuickLink({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}

Widget profileQuickLinkCard(ProfileQuickLink link, {required bool seniorMode}) {
  return GestureDetector(
    onTap: link.onTap,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.creamDeep),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.12),
            ),
            child: Icon(link.icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              link.label,
              style: AppTypography.titleStyle(
                seniorMode: seniorMode,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget profileNavRow({
  required IconData icon,
  required String label,
  required VoidCallback onTap,
  bool seniorMode = false,
}) {
  return GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: seniorMode ? AppSpacing.lg : 14,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: seniorMode ? 30 : 18, color: AppColors.primary),
              SizedBox(width: seniorMode ? AppSpacing.md : 10),
              Text(
                label,
                style: GoogleFonts.notoSerifTc(
                  fontSize: AppTypography.size(AppTypography.body, seniorMode: seniorMode),
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          Icon(
            Icons.chevron_right,
            color: AppColors.fog,
            size: seniorMode ? 24 : 16,
          ),
        ],
      ),
    ),
  );
}

Widget profileSection(String label, List<Widget> children, {bool seniorMode = false}) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.crimsonPro(
            fontStyle: FontStyle.italic,
            fontSize: AppTypography.size(AppTypography.micro, seniorMode: seniorMode),
            color: AppColors.fog,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.cream,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.creamDeep),
          ),
          clipBehavior: Clip.hardEdge,
          child: Column(children: children),
        ),
      ],
    ),
  );
}

Widget profileSettingRow(
  String label,
  String value, {
  bool truku = false,
  bool editable = true,
  bool copyable = false,
  VoidCallback? onTap,
  bool seniorMode = false,
}) {
  return Column(
    children: [
      GestureDetector(
        onTap: editable ? onTap : null,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: seniorMode ? AppSpacing.lg : 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.notoSerifTc(
                      fontSize: AppTypography.size(AppTypography.caption, seniorMode: seniorMode),
                      color: AppColors.fog,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style:
                        (truku
                                ? GoogleFonts.crimsonPro(
                                    fontStyle: FontStyle.italic,
                                  )
                                : GoogleFonts.notoSerifTc())
                            .copyWith(
                              fontSize: AppTypography.size(AppTypography.body, seniorMode: seniorMode),
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink,
                              letterSpacing: 0.5,
                            ),
                  ),
                ],
              ),
              if (copyable)
                Icon(Icons.copy_rounded, size: seniorMode ? 24 : 16, color: AppColors.primary)
              else if (editable)
                CustomPaint(
                  size: Size.square(seniorMode ? 24 : 16),
                  painter: ProfileEditPenPainter(),
                ),
            ],
          ),
        ),
      ),
      const Divider(
        height: 1,
        color: AppColors.creamDeep,
        indent: 16,
        endIndent: 16,
      ),
    ],
  );
}

/// 可互動的開關列，供族群鎖定等需要送出 PATCH 的設定使用（區別於純顯示用的
/// 純顯示用的列）。locked=true 時停用點擊，並在下方顯示 lockedHint 提示。
Widget profileSwitchRow(
  String label,
  bool on, {
  required ValueChanged<bool> onChanged,
  bool locked = false,
  String? lockedHint,
  bool seniorMode = false,
}) {
  final trackWidth = seniorMode ? 52.0 : 36.0;
  final trackHeight = seniorMode ? 30.0 : 22.0;
  final thumbSize = seniorMode ? 26.0 : 18.0;
  return Column(
    children: [
      Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: seniorMode ? AppSpacing.lg : 14,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.notoSerifTc(
                      fontSize: AppTypography.size(AppTypography.body, seniorMode: seniorMode),
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (locked && lockedHint != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      lockedHint,
                      style: GoogleFonts.notoSerifTc(
                        fontSize: AppTypography.size(AppTypography.caption, seniorMode: seniorMode),
                        color: AppColors.fog,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            GestureDetector(
              onTap: locked ? null : () => onChanged(!on),
              child: Container(
                width: trackWidth,
                height: trackHeight,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(trackHeight / 2),
                  color: on
                      ? (locked
                            ? AppColors.primary.withValues(alpha: 0.5)
                            : AppColors.primary)
                      : AppColors.creamDeep,
                ),
                child: Align(
                  alignment: on ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    width: thumbSize,
                    height: thumbSize,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.creamLight,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      const Divider(
        height: 1,
        color: AppColors.creamDeep,
        indent: 16,
        endIndent: 16,
      ),
    ],
  );
}

// ── SVG 圖示 Painters ─────────────────────────────────────────────────────────

class ProfileEditIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(size.width * 0.58, size.height * 0.17)
      ..lineTo(size.width * 0.83, size.height * 0.42)
      ..lineTo(size.width * 0.33, size.height * 0.92)
      ..lineTo(size.width * 0.08, size.height * 0.92)
      ..lineTo(size.width * 0.08, size.height * 0.67)
      ..close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

class ProfileEditPenPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(size.width * 0.58, size.height * 0.17)
      ..lineTo(size.width * 0.83, size.height * 0.42)
      ..lineTo(size.width * 0.33, size.height * 0.92)
      ..lineTo(size.width * 0.08, size.height * 0.92)
      ..lineTo(size.width * 0.08, size.height * 0.67)
      ..close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

class ProfileLogoutIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.55, size.height * 0.5),
      Offset(size.width, size.height * 0.5),
      p,
    );
    canvas.drawLine(
      Offset(size.width * 0.75, size.height * 0.25),
      Offset(size.width, size.height * 0.5),
      p,
    );
    canvas.drawLine(
      Offset(size.width * 0.75, size.height * 0.75),
      Offset(size.width, size.height * 0.5),
      p,
    );
    final door = Path()
      ..moveTo(size.width * 0.45, size.height * 0.13)
      ..lineTo(size.width * 0.2, size.height * 0.13)
      ..arcToPoint(
        Offset(size.width * 0.08, size.height * 0.25),
        radius: Radius.circular(size.width * 0.12),
      )
      ..lineTo(size.width * 0.08, size.height * 0.75)
      ..arcToPoint(
        Offset(size.width * 0.2, size.height * 0.87),
        radius: Radius.circular(size.width * 0.12),
      )
      ..lineTo(size.width * 0.45, size.height * 0.87);
    canvas.drawPath(door, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}
