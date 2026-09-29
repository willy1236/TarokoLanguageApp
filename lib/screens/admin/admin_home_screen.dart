// 管理後台首頁：功能清單。只列已實作的功能，沒做的不顯示。

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../profile/widgets/profile_rows.dart';
import 'admin_cases_screen.dart';
import 'admin_error.dart';
import 'admin_reports_screen.dart';
import 'widgets/admin_widgets.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) => AdminScaffold(
    title: '管理後台',
    body: (context, senior) {
      final entries =
          <({IconData icon, String label, Widget Function() screen})>[
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
          ];
      return ListView(
        children: [
          profileSection('管理 · 功能', [
            for (var i = 0; i < entries.length; i++) ...[
              if (i > 0) const Divider(height: 1, color: AppColors.creamDeep),
              profileNavRow(
                icon: entries[i].icon,
                label: entries[i].label,
                seniorMode: senior,
                onTap: () => pushAdmin(context, entries[i].screen()),
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
      );
    },
  );
}
