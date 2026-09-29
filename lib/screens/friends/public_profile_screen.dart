// 公開個人檔案唯讀頁。顯示暱稱/自我介紹/好友碼/加入天數/羈絆等級，
// 並提供加好友／封鎖／解除封鎖／刪除好友等操作（見右上角選單）。
//
// 後端 GET /api/users/:friend_code 不回傳「我與對方的關係狀態」，因此改由前端
// 另外拉好友清單／封鎖清單比對出實際關係，只顯示符合關係的選單項目；若前端快取
// 過期導致誤判，仍交由 API 回應的錯誤碼／SnackBar 兜底。

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_icon_size.dart';
import '../../core/constants/app_typography.dart';
import '../../core/network/api_client.dart';
import '../../models/friend_model.dart';
import '../../models/public_profile_model.dart';
import '../../models/shop_item.dart';
import '../../services/account_lock_controller.dart';
import '../../services/admin_service.dart';
import '../../services/friend_service.dart';
import '../../services/senior_mode_controller.dart';
import '../../services/shop_service.dart';
import '../../services/user_service.dart';
import '../../shared/widgets/truku_empty_state.dart';
import '../../shared/widgets/user_avatar.dart';
import '../admin/admin_error.dart';
import '../admin/widgets/admin_reason_dialog.dart';
import '../chat/chat_screen.dart';
import '../forum/widgets/forum_report_sheet.dart';
import 'widgets/bond_level_badge.dart';
import '../../shared/widgets/app_back_button.dart';
import '../../shared/widgets/confirm_dialog.dart';

enum _ProfileAction {
  addFriend,
  removeFriend,
  block,
  unblock,
  report,
  adminReset,
}

enum _Relationship { friend, blocked, stranger }

class PublicProfileScreen extends StatefulWidget {
  final String friendCode;

  const PublicProfileScreen({super.key, required this.friendCode});

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  PublicProfile? _profile;
  bool _loading = true;
  bool _notFound = false;
  Map<String, ShopItem> _itemCatalogById = const {};
  _Relationship? _relationship;

  @override
  void initState() {
    super.initState();
    _load();
    _loadItemCatalog();
  }

  Future<void> _loadRelationship(String friendCode) async {
    try {
      final results = await Future.wait([
        FriendService.getFriends(),
        FriendService.getBlockedUsers(),
      ]);
      if (!mounted) return;
      final friends = results[0];
      final blocked = results[1];
      setState(() {
        if (blocked.any((b) => sameFriendCode(b.friendCode, friendCode))) {
          _relationship = _Relationship.blocked;
        } else if (friends.any(
          (f) => sameFriendCode(f.friendCode, friendCode),
        )) {
          _relationship = _Relationship.friend;
        } else {
          _relationship = _Relationship.stranger;
        }
      });
    } catch (e) {
      debugPrint('Failed to fetch relationship: $e');
    }
  }

  Future<void> _loadItemCatalog() async {
    try {
      final catalog = await ShopService.fetchItemCatalogCached();
      if (!mounted) return;
      setState(() => _itemCatalogById = catalog);
    } catch (e) {
      debugPrint('Failed to fetch item catalog: $e');
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _notFound = false;
    });
    try {
      final profile = await FriendService.getPublicProfile(widget.friendCode);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _loading = false;
      });
      if (!UserService.isMe(profile.friendCode)) {
        _loadRelationship(profile.friendCode);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _notFound = e.statusCode == 404;
        _loading = false;
      });
    } catch (e, st) {
      debugPrint('Failed to fetch public profile: $e');
      debugPrintStack(stackTrace: st);
      if (!mounted) return;
      setState(() {
        _notFound = true;
        _loading = false;
      });
    }
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
          _backBar(),
          Expanded(child: _buildBody(seniorMode)),
        ],
      ),
    ),
  );

  Widget _backBar() => Padding(
    padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
    child: Row(
      children: [
        const AppBackButton(),
        const Spacer(),
        if (_profile != null &&
            !UserService.isMe(_profile!.friendCode) &&
            _relationship != null)
          PopupMenuButton<_ProfileAction>(
            iconSize: AppIconSize.action(seniorModeController.enabled),
            icon: const Icon(Icons.more_vert, color: AppColors.ink),
            onSelected: _handleAction,
            itemBuilder: (context) => [
              ..._menuItemsFor(_relationship!),
              // 後台端點只收 uid；開關開啟後一般帳號拿不到 uid，這時不提供。
              if ((UserService.cachedUser?.isAdmin ?? false) &&
                  _profile?.uid != null)
                const PopupMenuItem(
                  value: _ProfileAction.adminReset,
                  child: Text('重設個人檔案'),
                ),
            ],
          ),
      ],
    ),
  );

  List<PopupMenuItem<_ProfileAction>> _menuItemsFor(
    _Relationship relationship,
  ) {
    switch (relationship) {
      case _Relationship.friend:
        return const [
          PopupMenuItem(
            value: _ProfileAction.removeFriend,
            child: Text('刪除好友'),
          ),
          PopupMenuItem(value: _ProfileAction.block, child: Text('封鎖')),
          PopupMenuItem(value: _ProfileAction.report, child: Text('檢舉')),
        ];
      case _Relationship.blocked:
        return const [
          PopupMenuItem(value: _ProfileAction.unblock, child: Text('解除封鎖')),
        ];
      case _Relationship.stranger:
        return const [
          PopupMenuItem(value: _ProfileAction.addFriend, child: Text('加好友')),
          PopupMenuItem(value: _ProfileAction.block, child: Text('封鎖')),
          PopupMenuItem(value: _ProfileAction.report, child: Text('檢舉')),
        ];
    }
  }

  /// 聊天中可能封鎖或被對方變更關係，返回後重抓本頁。
  Future<void> _openChat() async {
    final profile = _profile;
    if (profile == null) return;
    await Navigator.of(context).push(
      ChatScreen.route(
        friendCode: profile.friendCode,
        partnerNickname: profile.nickname,
        partnerAvatarUrl: profile.avatarUrl,
        avatarId: profile.avatarId,
        frameId: profile.frameId,
        // 已經在公開檔案頁了，聊天室不必再提供回到這裡的入口。
        linkToProfile: false,
      ),
    );
    if (!mounted) return;
    _load();
  }

  Future<void> _handleAction(_ProfileAction action) async {
    final profile = _profile;
    if (profile == null) return;
    // 唯讀帳號只擋加好友；刪除好友、封鎖等清理動作後端放行。
    if (action == _ProfileAction.addFriend && blockIfReadOnly()) return;
    if (action == _ProfileAction.report) {
      await showForumReportSheet(
        context,
        targetType: 'profile',
        targetId: profile.friendCode,
      );
      return;
    }
    if (action == _ProfileAction.adminReset) return _adminResetProfile();
    if (action == _ProfileAction.block && !await _confirmBlock()) return;
    try {
      switch (action) {
        case _ProfileAction.addFriend:
          final status = await FriendService.sendRequest(profile.friendCode);
          _showMessage(status == 'accepted' ? '你們已成為好友！' : '已送出好友邀請');
          break;
        case _ProfileAction.removeFriend:
          await FriendService.removeFriend(profile.friendCode);
          _showMessage('已刪除好友');
          break;
        case _ProfileAction.block:
          await FriendService.blockUser(profile.friendCode);
          _showMessage('已封鎖此使用者');
          break;
        case _ProfileAction.report:
        case _ProfileAction.adminReset:
          break;
        case _ProfileAction.unblock:
          await FriendService.unblockUser(profile.friendCode);
          _showMessage('已解除封鎖');
          break;
      }
      _loadRelationship(profile.friendCode);
    } on ApiException catch (e) {
      _showMessage(_friendlyErrorMessage(e));
    } catch (e, st) {
      debugPrint('Failed to $action on public profile: $e');
      debugPrintStack(stackTrace: st);
      _showMessage('操作失敗，請稍後再試');
    }
  }

  /// 管理員直接重設他人個人檔案：指定欄位立即改回預設值，並送進違規區等二審。
  Future<void> _adminResetProfile() async {
    final uid = _profile?.uid;
    if (uid == null) return;
    final input = await promptAdminReason(
      context,
      title: '重設個人檔案',
      description: '勾選的欄位會立刻改回預設值，並送進違規區等另一位管理員二審；撤銷時會自動還原。',
      confirmMessage: '確定重設這位使用者的個人檔案？',
      confirmText: '重設',
      profileFields: true,
    );
    if (input == null || !mounted) return;
    try {
      await AdminService.resetProfile(uid, input.reason, fields: input.fields);
      showAdminMessage('已重設，等待其他管理員二審');
      if (mounted) await _load();
    } catch (e) {
      if (mounted) handleAdminError(context, e);
    }
  }

  /// 封鎖會雙向切斷且解封不回復（後端 2026-09-26 起），送出前先講清楚。
  Future<bool> _confirmBlock() async {
    final confirmed = await showConfirmDialog(
      context,
      title: '封鎖此使用者？',
      message:
          '封鎖後會解除好友，並移除你們在彼此貼文上的留言與讚；進行中的通話也會結束。'
          '\n\n解除封鎖後，這些都不會恢復，需要重新加好友。',
      cancelText: '取消',
      confirmText: '封鎖',
    );
    return confirmed == true && mounted;
  }

  String _friendlyErrorMessage(ApiException e) {
    if (e.isAlreadyFriends) return '你們已經是好友';
    if (e.isRequestAlreadySent) return '已送出邀請，等待對方回覆';
    if (e.isRequestCooldown) return e.requestCooldownMessage;
    if (e.isBlocked) return '因封鎖關係，無法執行此操作';
    if (e.isUserUnavailable) return '該使用者暫時無法使用';
    if (e.isNotFriends) return '你們還不是好友';
    if (e.code == 'NOT_BLOCKED') return '你沒有封鎖此使用者';
    return e.message;
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildBody(bool seniorMode) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_notFound || _profile == null) {
      return TrukuEmptyState(
        icon: Icons.person_off_outlined,
        message: '此使用者無法檢視',
        subtitle: '對方可能不存在，或雙方之一已封鎖對方',
        seniorMode: seniorMode,
      );
    }
    final profile = _profile!;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
      child: Column(
        children: [
          _avatar(profile, seniorMode),
          const SizedBox(height: 16),
          Text(
            profile.nickname?.isNotEmpty == true ? profile.nickname! : '未命名旅人',
            style: AppTypography.headlineStyle(
              seniorMode: seniorMode,
              color: AppColors.ink,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            '加入 ${profile.joinedDays} 天',
            style: AppTypography.subtitleStyle(
              seniorMode: seniorMode,
              color: AppColors.fog,
            ),
          ),
          const SizedBox(height: 20),
          if (profile.selfIntro != null && profile.selfIntro!.isNotEmpty) ...[
            _card(
              child: Text(
                profile.selfIntro!,
                style: AppTypography.bodyLargeStyle(
                  seniorMode: seniorMode,
                  color: AppColors.ink,
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          _card(
            child: GestureDetector(
              onTap: () => _copyFriendCode(profile.friendCode),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '好友碼',
                        style: AppTypography.captionStyle(
                          seniorMode: seniorMode,
                          color: AppColors.fog,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        profile.friendCode,
                        style: AppTypography.titleStyle(
                          seniorMode: seniorMode,
                          color: AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                  const Icon(Icons.copy, size: 18, color: AppColors.primary),
                ],
              ),
            ),
          ),
          if (profile.bondShowcase.isNotEmpty) ...[
            const SizedBox(height: 14),
            _bondShowcaseCard(profile.bondShowcase, seniorMode),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _openChat,
              icon: const Icon(
                Icons.chat_bubble_outline,
                color: AppColors.primary,
              ),
              label: Text(
                '傳訊息',
                style: AppTypography.bodyLargeStyle(
                  seniorMode: seniorMode,
                  color: AppColors.primary,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar(PublicProfile profile, bool seniorMode) {
    final size = seniorMode ? 104.0 : 88.0;
    return Container(
      decoration: profile.frameId == null
          ? BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.gold, width: 2),
            )
          : null,
      child: FramedUserAvatar(
        avatarId: profile.avatarId,
        avatarUrl: profile.avatarUrl,
        frameId: profile.frameId,
        itemCatalogById: _itemCatalogById,
        size: size,
        fallbackIconColor: AppColors.gold,
        fallback: DecoratedBox(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.ink,
          ),
          child: _initialsAvatar(profile, size),
        ),
      ),
    );
  }

  Widget _initialsAvatar(PublicProfile profile, double size) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    child: Text(
      profile.nickname?.characters.firstOrNull ?? '?',
      style: AppTypography.headlineStyle(color: AppColors.gold),
    ),
  );

  Widget _bondShowcaseCard(List<BondShowcaseItem> items, bool seniorMode) =>
      _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '羈絆好友',
              style: AppTypography.captionStyle(
                seniorMode: seniorMode,
                color: AppColors.fog,
              ),
            ),
            // 每筆要帶出是誰，只放等級徽章會被讀成「檢視者與此人的羈絆」。
            for (final item in items) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  FramedUserAvatar(
                    avatarId: item.avatarId,
                    avatarUrl: item.avatarUrl,
                    frameId: item.frameId,
                    itemCatalogById: _itemCatalogById,
                    size: seniorMode ? 40 : 32,
                    fallbackIconColor: AppColors.gold,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.nickname?.isNotEmpty == true
                          ? item.nickname!
                          : '未命名旅人',
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyStyle(
                        seniorMode: seniorMode,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  BondLevelBadge(
                    level: item.bondLevel.level,
                    name: item.bondLevel.name,
                    seniorMode: seniorMode,
                  ),
                ],
              ),
            ],
          ],
        ),
      );

  Widget _card({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.cream,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.creamDeep),
    ),
    child: child,
  );

  Future<void> _copyFriendCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(const SnackBar(content: Text('已複製好友碼')));
  }
}
