// 更正出生日期：使用者只能自己填一次，填錯由管理員更正。
// 以好友碼查人後顯示目前的出生日期並預帶進滾輪，填理由、二次確認後送出，
// 結果顯示更正後是否滿 18 歲。生日只出現在這個畫面，換對象或離開就清掉。

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_typography.dart';
import '../../models/admin_models.dart';
import '../../services/admin_service.dart';
import '../../shared/utils/birth_date.dart';
import '../../shared/widgets/birth_date_field.dart';
import 'admin_error.dart';
import 'widgets/admin_reason_dialog.dart';
import 'widgets/admin_user_lookup.dart';
import 'widgets/admin_widgets.dart';

class AdminBirthDateScreen extends StatefulWidget {
  const AdminBirthDateScreen({super.key});

  @override
  State<AdminBirthDateScreen> createState() => _AdminBirthDateScreenState();
}

class _AdminBirthDateScreenState extends State<AdminBirthDateScreen> {
  AdminUserLookup? _user;

  /// 對方目前的出生日期；更正成功後改成新的值。
  DateTime? _current;
  DateTime? _selected;
  AdminBirthDateResult? _result;
  bool _submitting = false;

  void _onUserChanged(AdminUserLookup? user) => setState(() {
    _user = user;
    _current = user?.birthDate;
    _selected = user?.birthDate;
    _result = null;
    _submitting = false;
  });

  Future<void> _pick(bool senior) async {
    final picked = await pickBirthDate(
      context,
      initial: _selected,
      seniorMode: senior,
    );
    if (picked != null && mounted) setState(() => _selected = picked);
  }

  Future<void> _submit() async {
    final user = _user;
    final date = _selected;
    if (user == null || date == null || _submitting) return;
    final name = user.nickname.isEmpty ? '這位使用者' : '「${user.nickname}」';
    final input = await promptAdminReason(
      context,
      title: '更正出生日期',
      description:
          '$name的出生日期會改為 ${formatDisplayDate(date)}。'
          '更正後未滿 18 歲會立即移出隨機配對。',
      confirmMessage: '確定把$name的出生日期更正為 ${formatDisplayDate(date)}？',
      confirmText: '更正',
    );
    if (input == null || !mounted) return;
    setState(() => _submitting = true);
    try {
      final result = await AdminService.updateBirthDate(
        user.uid,
        date,
        input.reason,
      );
      if (!mounted) return;
      showAdminMessage('已更正出生日期');
      // 送出途中換了對象：更正已成功，但畫面已是別人，不套用結果。
      if (_user?.uid != user.uid) return;
      setState(() {
        _result = result;
        _current = result.birthDate ?? date;
        _submitting = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (_user?.uid == user.uid) setState(() => _submitting = false);
      handleAdminError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => AdminScaffold(
    title: '更正出生日期',
    body: (context, senior) => ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      children: [
        AdminUserLookupPanel(seniorMode: senior, onChanged: _onUserChanged),
        if (_user != null) _form(_user!, senior),
        if (_result != null) _resultCard(_result!, senior),
      ],
    ),
  );

  Widget _form(AdminUserLookup user, bool senior) => AdminCard(
    seniorMode: senior,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminInfoRow(
          '目前的出生日期',
          _current == null ? '未填寫' : formatDisplayDate(_current!),
          seniorMode: senior,
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: () => _pick(senior),
          icon: const Icon(Icons.calendar_today_outlined),
          label: Text(
            _selected == null
                ? '選擇正確的出生日期'
                : '更正為 ${formatDisplayDate(_selected!)}',
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        FilledButton(
          onPressed: _selected == null || _submitting ? null : _submit,
          child: const Text('送出更正'),
        ),
      ],
    ),
  );

  Widget _resultCard(AdminBirthDateResult r, bool senior) => AdminCard(
    seniorMode: senior,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '更正結果',
                style: AppTypography.titleStyle(
                  seniorMode: senior,
                  color: AppColors.ink,
                ),
              ),
            ),
            AdminBadge(
              r.adult ? '已滿 18 歲' : '未滿 18 歲',
              color: r.adult ? AppColors.online : AppColors.danger,
              seniorMode: senior,
            ),
          ],
        ),
        if (r.birthDate != null)
          AdminInfoRow(
            '出生日期',
            formatDisplayDate(r.birthDate!),
            seniorMode: senior,
          ),
        if (!r.adult)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '對方已被移出隨機配對佇列，滿 18 歲前不能使用隨機配對。',
              style: AppTypography.bodyStyle(
                seniorMode: senior,
                color: AppColors.inkSoft,
              ),
            ),
          ),
      ],
    ),
  );
}
