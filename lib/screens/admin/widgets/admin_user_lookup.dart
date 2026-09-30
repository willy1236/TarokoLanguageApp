// 後台共用的「以好友碼查人」元件：輸入好友碼查詢，查到後顯示對象卡。
//
// 後台端點只收 uid，這是好友碼轉 uid 的唯一入口（GET /api/admin/users/lookup）。
// 對外只吐出 [AdminUserLookup]；查詢中、查無此人或改了輸入時吐 null，
// 呼叫端據此清掉上一位對象，不會拿舊 uid 操作到別人。
// 對象卡刻意不顯示生日：出生日期只在更正生日的畫面出現。

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../models/admin_models.dart';
import '../../../services/admin_service.dart';
import '../admin_error.dart';
import 'admin_widgets.dart';

class AdminUserLookupPanel extends StatefulWidget {
  final ValueChanged<AdminUserLookup?> onChanged;
  final bool seniorMode;

  const AdminUserLookupPanel({
    super.key,
    required this.onChanged,
    this.seniorMode = false,
  });

  @override
  State<AdminUserLookupPanel> createState() => _AdminUserLookupPanelState();
}

class _AdminUserLookupPanelState extends State<AdminUserLookupPanel> {
  final _controller = TextEditingController();
  AdminUserLookup? _user;
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setUser(AdminUserLookup? user) {
    setState(() => _user = user);
    widget.onChanged(user);
  }

  void _onInputChanged(String _) {
    if (_user != null) _setUser(null);
  }

  Future<void> _lookup() async {
    final code = _controller.text.trim();
    if (code.isEmpty || _loading) return;
    FocusScope.of(context).unfocus();
    _setUser(null);
    setState(() => _loading = true);
    try {
      final user = await AdminService.lookupUser(code);
      if (!mounted) return;
      setState(() => _loading = false);
      _setUser(user);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      handleAdminError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final senior = widget.seniorMode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 8,
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'\s')),
                  ],
                  onChanged: _onInputChanged,
                  onSubmitted: (_) => _lookup(),
                  textInputAction: TextInputAction.search,
                  style: AppTypography.bodyLargeStyle(
                    seniorMode: senior,
                    color: AppColors.ink,
                  ),
                  decoration: const InputDecoration(
                    labelText: '對象的好友碼',
                    counterText: '',
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              FilledButton(
                onPressed: _loading ? null : _lookup,
                child: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('查詢'),
              ),
            ],
          ),
        ),
        if (_user != null) _userCard(_user!, senior),
      ],
    );
  }

  Widget _userCard(AdminUserLookup user, bool senior) => AdminCard(
    seniorMode: senior,
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
        AdminInfoRow('角色', adminRoleLabel(user.role), seniorMode: senior),
        AdminInfoRow(
          '狀態',
          adminUserStatusLabel(user.status),
          seniorMode: senior,
        ),
      ],
    ),
  );
}
