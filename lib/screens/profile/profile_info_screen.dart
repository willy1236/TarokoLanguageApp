// 個人資料設定獨立頁：原本整段內嵌在「我的」主頁，把主頁拉得很長，
// 現在收成一頁，入口和意見回饋、關於等其他設定放在一起。
//
// 這裡所有寫入都走 UserService.updateMe()，它會同步 userNotifier，
// 所以「我的」主頁不必等返回值就會跟著更新。

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_icon_size.dart';
import '../../core/constants/app_typography.dart';
import '../../core/network/api_client.dart';
import '../../models/tribe_model.dart';
import '../../models/user_model.dart';
import '../../services/senior_mode_controller.dart';
import '../../services/user_service.dart';
import '../../shared/widgets/tribe_picker_sheet.dart';
import 'notification_email_screen.dart';
import 'widgets/profile_rename_dialog.dart';
import 'widgets/profile_rows.dart';

class ProfileInfoScreen extends StatefulWidget {
  /// 從「我的」主頁 hero 上的族語名進來時為 true：開頁即彈出族語名編輯對話框，
  /// 使用者不必再自己在清單裡找那一列。
  final bool editTribalNameOnOpen;

  const ProfileInfoScreen({super.key, this.editTribalNameOnOpen = false});

  @override
  State<ProfileInfoScreen> createState() => _ProfileInfoScreenState();
}

class _ProfileInfoScreenState extends State<ProfileInfoScreen> {
  UserModel? _user = UserService.cachedUser;

  // 目前僅太魯閣族一個族群，選部落時固定連同 ethnic_group 一起送，
  // 避免後端「改 ethnic_group 未附 tribe_id 就清空」的規則誤觸發。
  static const String _defaultEthnicGroup = '太魯閣族';

  @override
  void initState() {
    super.initState();
    UserService.userNotifier.addListener(_onUserChanged);
    _loadUser();
    if (widget.editTribalNameOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _editTribalName();
      });
    }
  }

  @override
  void dispose() {
    UserService.userNotifier.removeListener(_onUserChanged);
    super.dispose();
  }

  void _onUserChanged() {
    final user = UserService.cachedUser;
    if (!mounted || user == null) return;
    setState(() => _user = user);
  }

  Future<void> _loadUser() async {
    try {
      final user = await UserService.fetchMe();
      if (!mounted) return;
      setState(() => _user = user);
    } catch (e, st) {
      debugPrint('Failed to fetch user: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: seniorModeController,
    builder: (context, _) => _buildScaffold(seniorModeController.enabled),
  );

  Widget _buildScaffold(bool seniorMode) => Scaffold(
    backgroundColor: AppColors.creamLight,
    body: SafeArea(
      child: Column(
        children: [
          _topBar(seniorMode),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 40),
              children: [_buildSettingsSection(seniorMode: seniorMode)],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _topBar(bool seniorMode) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
    child: Row(
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          iconSize: AppIconSize.action(seniorMode),
          icon: const Icon(Icons.arrow_back, color: AppColors.ink),
        ),
        Expanded(
          child: Text(
            '個人資料設定',
            style: AppTypography.titleStyle(
              seniorMode: seniorMode,
              color: AppColors.ink,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildSettingsSection({required bool seniorMode}) {
    final identityLocked = _user?.ethnicGroup != null;
    return profileSection('PSPUNG · 個人資料設定', [
      profileSettingRow(
        '中文姓名',
        _user?.displayName ?? 'Apyang Imiq',
        editable: true,
        onTap: _editDisplayName,
        seniorMode: seniorMode,
      ),
      profileSettingRow(
        '公開暱稱',
        _user?.videoNickname ?? '尚未設定',
        editable: true,
        onTap: _editVideoNickname,
        seniorMode: seniorMode,
      ),
      profileSettingRow(
        '自我介紹',
        (_user?.selfIntro == null || _user!.selfIntro!.isEmpty)
            ? '尚未填寫'
            : _user!.selfIntro!,
        editable: true,
        onTap: _editSelfIntro,
        seniorMode: seniorMode,
      ),
      profileSettingRow(
        '好友碼',
        _user?.friendCode ?? '—',
        editable: _user?.friendCode != null,
        copyable: true,
        onTap: _copyFriendCode,
        seniorMode: seniorMode,
      ),
      profileSwitchRow(
        '是否為原住民',
        _user?.isIndigenous ?? false,
        locked: true,
        lockedHint: '已設定，如需更正請聯繫管理員',
        onChanged: (_) {},
        seniorMode: seniorMode,
      ),
      // 族語名只開放原住民填寫（與完善資料頁一致），非原住民不顯示這列。
      if (_user?.isIndigenous == true)
        profileSettingRow(
          '族語名字',
          _user?.tribalName ?? '尚未設定',
          // 尚未設定時顯示中文提示字，不套用族語專用的斜體字型，避免字型跟中文不搭。
          truku: _user?.tribalName != null && _user!.tribalName!.isNotEmpty,
          editable: true,
          onTap: _editTribalName,
          seniorMode: seniorMode,
        ),
      profileSettingRow(
        '部落',
        _user?.tribeName ?? '尚未設定',
        editable: !identityLocked,
        onTap: identityLocked ? null : _editTribe,
        seniorMode: seniorMode,
      ),
      profileSettingRow(
        '通知信箱',
        (_user?.email.isNotEmpty ?? false) ? _user!.email : '尚未設定',
        editable: _user != null && _user!.uid != 0,
        onTap: _editNotificationEmail,
        badge: (_user?.email.isNotEmpty ?? false)
            ? EmailVerifiedBadge(verified: _user!.emailVerified)
            : null,
        seniorMode: seniorMode,
      ),
    ], seniorMode: seniorMode);
  }

  Future<void> _editDisplayName() async {
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => ProfileRenameDialog(
        title: '修改姓名',
        label: '中文姓名',
        initialValue: _user?.displayName ?? '',
      ),
    );
    if (newName == null || newName.isEmpty || newName == _user?.displayName) {
      return;
    }
    try {
      final updated = await UserService.updateMe(displayName: newName);
      if (mounted) setState(() => _user = updated);
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (e, st) {
      debugPrint('Failed to update display name: $e');
      debugPrintStack(stackTrace: st);
      _showError('更新失敗，請稍後再試');
    }
  }

  /// 「我的」主頁 hero 上點族語名時，會導到本頁並自動彈出這個對話框。
  Future<void> _editTribalName() async {
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => ProfileRenameDialog(
        title: '修改族語名字',
        label: '族語名字',
        initialValue: _user?.tribalName ?? '',
      ),
    );
    if (newName == null || newName == _user?.tribalName) return;
    try {
      final updated = await UserService.updateMe(tribalName: newName);
      if (mounted) setState(() => _user = updated);
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (e, st) {
      debugPrint('Failed to update tribal name: $e');
      debugPrintStack(stackTrace: st);
      _showError('更新失敗，請稍後再試');
    }
  }

  // 視訊配對前必填；空字串視為清空，後端規則相同。
  Future<void> _editVideoNickname() async {
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => ProfileRenameDialog(
        title: '修改公開暱稱',
        label: '公開暱稱',
        initialValue: _user?.videoNickname ?? '',
      ),
    );
    if (newName == null || newName == _user?.videoNickname) return;
    try {
      final updated = await UserService.updateMe(videoNickname: newName);
      if (mounted) setState(() => _user = updated);
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (e, st) {
      debugPrint('Failed to update video nickname: $e');
      debugPrintStack(stackTrace: st);
      _showError('更新失敗，請稍後再試');
    }
  }

  Future<void> _editSelfIntro() async {
    final newIntro = await showDialog<String>(
      context: context,
      builder: (ctx) => ProfileRenameDialog(
        title: '修改自我介紹',
        label: '自我介紹',
        initialValue: _user?.selfIntro ?? '',
      ),
    );
    if (newIntro == null || newIntro == _user?.selfIntro) return;
    try {
      final updated = await UserService.updateMe(selfIntro: newIntro);
      if (mounted) setState(() => _user = updated);
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (e, st) {
      debugPrint('Failed to update self intro: $e');
      debugPrintStack(stackTrace: st);
      _showError('更新失敗，請稍後再試');
    }
  }

  Future<void> _editNotificationEmail() async {
    final user = _user;
    if (user == null) return;
    final updated = await Navigator.of(context).push<UserModel>(
      MaterialPageRoute(builder: (_) => NotificationEmailScreen(user: user)),
    );
    if (updated != null && mounted) setState(() => _user = updated);
  }

  Future<void> _copyFriendCode() async {
    final code = _user?.friendCode;
    if (code == null) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已複製好友碼')));
  }

  Future<void> _editTribe() async {
    final tribe = await showModalBottomSheet<Tribe>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) =>
          const TribePickerSheet(ethnicGroup: _defaultEthnicGroup),
    );
    if (tribe == null) return;
    if (tribe.id == kClearTribeId) {
      if (_user?.tribeId == null) return;
      try {
        final updated = await UserService.updateMe(clearTribeId: true);
        if (mounted) setState(() => _user = updated);
      } on ApiException catch (e) {
        if (e.isIdentityLocked) {
          _showError('族群已設定，如需更正請聯繫管理員');
        } else {
          _showError(e.message);
        }
      } catch (e, st) {
        debugPrint('Failed to clear tribe: $e');
        debugPrintStack(stackTrace: st);
        _showError('更新失敗，請稍後再試');
      }
      return;
    }
    if (tribe.id == _user?.tribeId) return;
    try {
      final updated = await UserService.updateMe(
        ethnicGroup: _defaultEthnicGroup,
        tribeId: tribe.id,
      );
      if (mounted) setState(() => _user = updated);
    } on ApiException catch (e) {
      if (e.isIdentityLocked) {
        _showError('族群已設定，如需更正請聯繫管理員');
      } else {
        _showError(e.message);
      }
    } catch (e, st) {
      debugPrint('Failed to update tribe: $e');
      debugPrintStack(stackTrace: st);
      _showError('更新失敗，請稍後再試');
    }
  }
}
