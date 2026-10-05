// 角色管理：列出目前的管理員與活動發起人，可改角色；也可用好友碼查人後指定新角色。
// 角色改完後端立即生效並推播當事人（account_role），當事人不必重開 App。

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_typography.dart';
import '../../models/admin_models.dart';
import '../../services/admin_service.dart';
import '../../shared/widgets/async_state_view.dart';
import 'admin_error.dart';
import 'widgets/admin_reason_dialog.dart';
import 'widgets/admin_user_lookup.dart';
import 'widgets/admin_widgets.dart';

class AdminRolesScreen extends StatefulWidget {
  const AdminRolesScreen({super.key});

  @override
  State<AdminRolesScreen> createState() => _AdminRolesScreenState();
}

class _AdminRolesScreenState extends State<AdminRolesScreen> {
  List<AdminRoleUser>? _users;
  Object? _error;
  AdminUserLookup? _found;

  /// 設定完角色後換 key 重建查人元件，清掉顯示舊角色的對象卡與輸入。
  int _lookupKey = 0;

  /// 改角色送出中：所有「改角色」「設定角色」鈕停用，連點只送一次。
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _error = null);
    try {
      final users = await AdminService.fetchRoleUsers();
      if (mounted) setState(() => _users = users);
    } catch (e) {
      if (!mounted || handleAdminError(context, e, toast: false)) return;
      setState(() => _error = e);
    }
  }

  /// 選角色 → 填理由 → 二次確認 → 送出。任一步取消就不送。
  Future<void> _changeRole({
    required int uid,
    required String nickname,
    required String currentRole,
  }) async {
    final role = await _pickRole(currentRole);
    if (role == null || !mounted) return;
    final name = nickname.isEmpty ? '這位使用者' : '「$nickname」';
    final input = await promptAdminReason(
      context,
      title: '設為${adminRoleLabel(role)}',
      description: '$name會立即變成${adminRoleLabel(role)}，並收到通知。',
      confirmMessage: '確定把$name設為${adminRoleLabel(role)}？',
      confirmText: '確定',
      maxLength: 200,
    );
    if (input == null || !mounted || _busy) return;
    setState(() => _busy = true);
    try {
      final result = await AdminService.setRole(uid, role, input.reason);
      showAdminMessage(
        result.changed ? '已將$name設為${adminRoleLabel(result.role)}' : '角色未變更',
      );
      if (!mounted) return;
      if (_found?.uid == uid) {
        setState(() {
          _found = null;
          _lookupKey++;
        });
      }
      await _reload();
    } catch (e) {
      if (mounted) handleAdminError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _pickRole(String currentRole) => showDialog<String>(
    context: context,
    builder: (ctx) => SimpleDialog(
      backgroundColor: AppColors.creamLight,
      title: Text(
        '選擇角色',
        style: AppTypography.serif(
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
      ),
      children: [
        for (final role in adminRoles)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, role),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    adminRoleLabel(role),
                    style: AppTypography.bodyLargeStyle(color: AppColors.ink),
                  ),
                ),
                if (role == currentRole)
                  Text(
                    '目前',
                    style: AppTypography.captionStyle(color: AppColors.fog),
                  ),
              ],
            ),
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => AdminScaffold(
    title: '角色管理',
    body: (context, senior) => RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        children: [
          _sectionTitle('指定新對象', senior),
          AdminUserLookupPanel(
            key: ValueKey(_lookupKey),
            seniorMode: senior,
            onChanged: (user) => setState(() => _found = user),
          ),
          if (_found != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: FilledButton(
                onPressed: _busy
                    ? null
                    : () => _changeRole(
                        uid: _found!.uid,
                        nickname: _found!.nickname,
                        currentRole: _found!.role,
                      ),
                child: const Text('設定角色'),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          _sectionTitle('目前的管理員與活動發起人', senior),
          ..._list(senior),
        ],
      ),
    ),
  );

  Widget _sectionTitle(String text, bool senior) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.sm,
      AppSpacing.md,
      AppSpacing.xs,
    ),
    child: Text(
      text,
      style: AppTypography.captionStyle(
        seniorMode: senior,
        color: AppColors.fog,
      ),
    ),
  );

  List<Widget> _list(bool senior) {
    if (_error != null) {
      return [
        TrukuErrorView(error: _error, onRetry: _reload, seniorMode: senior),
      ];
    }
    final users = _users;
    if (users == null) {
      return const [
        Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        ),
      ];
    }
    return [
      for (final user in users)
        AdminCard(
          seniorMode: senior,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.nickname.isEmpty ? '（未設定暱稱）' : user.nickname,
                      style: AppTypography.titleStyle(
                        seniorMode: senior,
                        color: AppColors.ink,
                      ),
                    ),
                    AdminInfoRow('好友碼', user.friendCode, seniorMode: senior),
                  ],
                ),
              ),
              AdminBadge(adminRoleLabel(user.role), seniorMode: senior),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => _changeRole(
                        uid: user.uid,
                        nickname: user.nickname,
                        currentRole: user.role,
                      ),
                child: const Text('改角色'),
              ),
            ],
          ),
        ),
    ];
  }
}
