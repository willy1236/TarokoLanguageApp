// 管理後台首頁：功能清單。只列已實作的功能，沒做的不顯示。

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../profile/widgets/profile_rows.dart';
import 'admin_announcements_screen.dart';
import 'admin_appeals_screen.dart';
import 'admin_article_form_screen.dart';
import 'admin_banned_words_screen.dart';
import 'admin_birth_date_screen.dart';
import 'admin_cases_screen.dart';
import 'admin_error.dart';
import 'admin_identity_screen.dart';
import 'admin_millet_screen.dart';
import 'admin_mutes_screen.dart';
import 'admin_question_reports_screen.dart';
import 'admin_reports_screen.dart';
import 'admin_roles_screen.dart';
import 'admin_terms_publish_screen.dart';
import 'widgets/admin_widgets.dart';

typedef _Entry = ({IconData icon, String label, Widget Function() screen});

/// 後台功能入口，依顯示順序排列。
final List<_Entry> _entries = [
  (
    icon: Icons.flag_outlined,
    label: '檢舉佇列',
    screen: () => const AdminReportsScreen(),
  ),
  (
    icon: Icons.gavel_outlined,
    label: '違規區',
    screen: () => const AdminCasesScreen(),
  ),
  (
    icon: Icons.balance_outlined,
    label: '申訴',
    screen: () => const AdminAppealsScreen(),
  ),
  (
    icon: Icons.volume_off_outlined,
    label: '禁言',
    screen: () => const AdminMutesScreen(),
  ),
  (
    icon: Icons.manage_accounts_outlined,
    label: '角色管理',
    screen: () => const AdminRolesScreen(),
  ),
  (
    icon: Icons.cake_outlined,
    label: '更正出生日期',
    screen: () => const AdminBirthDateScreen(),
  ),
  (
    icon: Icons.diversity_3_outlined,
    label: '更正族群／部落',
    screen: () => const AdminIdentityScreen(),
  ),
  (
    icon: Icons.savings_outlined,
    label: '小米幣查帳',
    screen: () => const AdminMilletScreen(),
  ),
  (
    icon: Icons.block_outlined,
    label: '髒話詞庫',
    screen: () => const AdminBannedWordsScreen(),
  ),
  (
    icon: Icons.help_outline,
    label: '題目回報',
    screen: () => const AdminQuestionReportsScreen(),
  ),
  (
    icon: Icons.campaign_outlined,
    label: '官方公告',
    screen: () => const AdminAnnouncementsScreen(),
  ),
  (
    icon: Icons.post_add_outlined,
    label: '新增文章',
    screen: () => const AdminArticleFormScreen(),
  ),
  (
    icon: Icons.description_outlined,
    label: '發布條款',
    screen: () => const AdminTermsPublishScreen(),
  ),
];

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) => AdminScaffold(
    title: '管理後台',
    body: (context, senior) => ListView(
      children: [
        profileSection('管理 · 功能', [
          for (var i = 0; i < _entries.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.creamDeep),
            profileNavRow(
              icon: _entries[i].icon,
              label: _entries[i].label,
              seniorMode: senior,
              onTap: () => pushAdmin(context, _entries[i].screen()),
            ),
          ],
        ], seniorMode: senior),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Text(
            '操作會記錄是哪一位管理員做的。',
            style: AppTypography.captionStyle(
              seniorMode: senior,
              color: AppColors.fog,
            ),
          ),
        ),
      ],
    ),
  );
}
