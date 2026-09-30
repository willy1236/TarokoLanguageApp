// 更正族群／部落：使用者設定後就鎖住（PATCH /api/me 回 IDENTITY_LOCKED），填錯由管理員更正。
// 以好友碼查人後顯示目前的身分並預帶進表單，選好新的身分、填理由、二次確認後整組送出。
// 規格：Truku_backend 說明文件/API/內部管理.md §8.10。

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_typography.dart';
import '../../core/network/api_client.dart';
import '../../models/admin_models.dart';
import '../../models/tribe_model.dart';
import '../../services/admin_service.dart';
import '../../services/user_service.dart';
import '../../shared/widgets/tribe_picker_sheet.dart';
import 'admin_error.dart';
import 'widgets/admin_reason_dialog.dart';
import 'widgets/admin_user_lookup.dart';
import 'widgets/admin_widgets.dart';

/// 目前唯一開放的族群；族群清單載不到時退回這個。
const String _defaultEthnicGroup = '太魯閣族';

class AdminIdentityScreen extends StatefulWidget {
  const AdminIdentityScreen({super.key});

  @override
  State<AdminIdentityScreen> createState() => _AdminIdentityScreenState();
}

class _AdminIdentityScreenState extends State<AdminIdentityScreen> {
  AdminUserLookup? _user;

  /// 對方目前的身分（查到的、或更正成功後的），畫面上方顯示用。
  ({bool isIndigenous, String? ethnicGroup, String? tribeName})? _current;

  // 表單上選的新身分。
  bool _isIndigenous = false;
  String? _ethnicGroup;
  int? _tribeId;
  String? _tribeName;

  List<String> _ethnicGroups = const [_defaultEthnicGroup];
  bool _submitting = false;

  /// 換對象時加一：送出途中換過對象，回來的結果不套用到畫面。
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _loadEthnicGroups();
  }

  Future<void> _loadEthnicGroups() async {
    try {
      final groups = await UserService.fetchEthnicGroups();
      if (!mounted || groups.isEmpty) return;
      setState(() => _ethnicGroups = [for (final g in groups) g.ethnicGroup]);
    } catch (e) {
      debugPrint('AdminIdentityScreen: 族群清單載入失敗，沿用預設：$e');
    }
  }

  void _onUserChanged(AdminUserLookup? user) => setState(() {
    _generation++;
    _user = user;
    _submitting = false;
    _current = user == null
        ? null
        : (
            isIndigenous: user.isIndigenous,
            ethnicGroup: user.ethnicGroup,
            tribeName: user.tribeName,
          );
    _isIndigenous = user?.isIndigenous ?? false;
    _ethnicGroup = user?.ethnicGroup;
    _tribeId = user?.tribeId;
    _tribeName = user?.tribeName;
  });

  void _setIndigenous(bool value) => setState(() {
    _isIndigenous = value;
    if (value) _ethnicGroup ??= _ethnicGroups.first;
  });

  /// 部落要屬於所選族群：換族群就清掉已選的部落。
  void _setEthnicGroup(String? value) {
    if (value == null || value == _ethnicGroup) return;
    setState(() {
      _ethnicGroup = value;
      _tribeId = null;
      _tribeName = null;
    });
  }

  Future<void> _pickTribe() async {
    final tribe = await showModalBottomSheet<Tribe>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          TribePickerSheet(ethnicGroup: _ethnicGroup, allowClear: false),
    );
    if (tribe == null || !mounted) return;
    setState(() {
      _tribeId = tribe.id;
      _tribeName = tribe.name;
    });
  }

  bool get _canSubmit =>
      !_submitting &&
      (!_isIndigenous || (_ethnicGroup != null && _tribeId != null));

  String _describe(bool isIndigenous, String? group, String? tribe) =>
      isIndigenous ? '${group ?? '（未設定族群）'}・${tribe ?? '（未設定部落）'}' : '非原住民';

  Future<void> _submit() async {
    final user = _user;
    if (user == null || !_canSubmit) return;
    final isIndigenous = _isIndigenous;
    final group = isIndigenous ? _ethnicGroup : null;
    final tribeId = isIndigenous ? _tribeId : null;
    final tribeName = isIndigenous ? _tribeName : null;
    final name = user.nickname.isEmpty ? '這位使用者' : '「${user.nickname}」';
    final target = _describe(isIndigenous, group, tribeName);
    final input = await promptAdminReason(
      context,
      title: '更正族群／部落',
      description: '$name的身分會改為「$target」。',
      confirmMessage: isIndigenous
          ? '確定把$name的身分更正為「$target」？'
          : '確定把$name更正為非原住民？族群、部落、族語名會一起清空。',
      confirmText: '更正',
    );
    if (input == null || !mounted) return;
    final generation = _generation;
    setState(() => _submitting = true);
    try {
      final result = await AdminService.updateIdentity(
        user.uid,
        isIndigenous: isIndigenous,
        ethnicGroup: group,
        tribeId: tribeId,
        reason: input.reason,
      );
      if (!mounted) return;
      // 提示帶名字：送出途中換了對象時，才分得出是誰被改了。
      showAdminMessage('已更正$name的族群／部落');
      if (generation != _generation) return;
      setState(() {
        _submitting = false;
        _current = (
          isIndigenous: result.isIndigenous,
          ethnicGroup: result.ethnicGroup,
          tribeName: result.isIndigenous ? tribeName : null,
        );
      });
    } catch (e) {
      if (!mounted) return;
      if (generation == _generation) {
        setState(() => _submitting = false);
        handleAdminError(context, e);
      } else if (!isAdminOnlyError(e)) {
        showAdminMessage('$name的族群／部落更正失敗：${apiErrorMessage(e)}');
      } else {
        handleAdminError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) => AdminScaffold(
    title: '更正族群／部落',
    body: (context, senior) => ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      children: [
        AdminUserLookupPanel(seniorMode: senior, onChanged: _onUserChanged),
        if (_user != null) _form(senior),
      ],
    ),
  );

  Widget _form(bool senior) {
    final current = _current;
    // 後端給的族群不在清單裡（清單沒載到）時也要選得到。
    final groups = {..._ethnicGroups, ?_ethnicGroup}.toList();
    return AdminCard(
      seniorMode: senior,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (current != null) ...[
            AdminInfoRow(
              '目前的原住民身分',
              current.isIndigenous ? '原住民' : '非原住民',
              seniorMode: senior,
            ),
            if (current.isIndigenous) ...[
              AdminInfoRow(
                '目前的族群',
                current.ethnicGroup ?? '未設定',
                seniorMode: senior,
              ),
              AdminInfoRow(
                '目前的部落',
                current.tribeName ?? '未設定',
                seniorMode: senior,
              ),
            ],
          ],
          const SizedBox(height: AppSpacing.md),
          Text(
            '更正為',
            style: AppTypography.subtitleStyle(
              seniorMode: senior,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: true, label: Text('原住民')),
              ButtonSegment(value: false, label: Text('非原住民')),
            ],
            selected: {_isIndigenous},
            onSelectionChanged: (s) => _setIndigenous(s.first),
          ),
          if (_isIndigenous) ...[
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: _ethnicGroup,
              decoration: const InputDecoration(labelText: '族群'),
              items: [
                for (final g in groups)
                  DropdownMenuItem(value: g, child: Text(g)),
              ],
              onChanged: _setEthnicGroup,
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: _ethnicGroup == null ? null : _pickTribe,
              icon: const Icon(Icons.place_outlined),
              label: Text(_tribeName == null ? '選擇部落' : '部落：$_tribeName'),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                '改成非原住民後，族群、部落、族語名會一起清空。',
                style: AppTypography.bodyStyle(
                  seniorMode: senior,
                  color: AppColors.inkSoft,
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: _canSubmit ? _submit : null,
            child: const Text('送出更正'),
          ),
        ],
      ),
    );
  }
}
