// 公開個人檔案唯讀頁。顯示暱稱/自我介紹/好友碼/加入天數/羈絆等級，
// 並提供加好友／封鎖／解除封鎖／刪除好友等操作（見右上角選單）。
//
// 後端 GET /api/users/:friend_code 不回傳「我與對方的關係狀態」，因此改由前端
// 另外拉好友清單／封鎖清單比對出實際關係，只顯示符合關係的選單項目；若前端快取
// 過期導致誤判，仍交由 API 回應的錯誤碼／SnackBar 兜底。

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/network/api_client.dart';
import '../../models/public_profile_model.dart';
import '../../models/shop_item.dart';
import '../../services/friend_service.dart';
import '../../services/senior_mode_controller.dart';
import '../../services/shop_service.dart';
import '../../services/user_service.dart';
import '../../shared/widgets/truku_empty_state.dart';
import '../../shared/widgets/user_avatar.dart';
import '../chat/chat_screen.dart';
import 'widgets/bond_level_badge.dart';

enum _ProfileAction { addFriend, removeFriend, block, unblock }

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

  Future<void> _loadRelationship(int uid) async {
    try {
      final results = await Future.wait([
        FriendService.getFriends(),
        FriendService.getBlockedUsers(),
      ]);
      if (!mounted) return;
      final friends = results[0];
      final blocked = results[1];
      setState(() {
        if (blocked.any((b) => b.uid == uid)) {
          _relationship = _Relationship.blocked;
        } else if (friends.any((f) => f.uid == uid)) {
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
      if (profile.uid != UserService.currentUid) _loadRelationship(profile.uid);
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
        IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back, color: AppColors.ink),
        ),
        const Spacer(),
        if (_profile != null &&
            _profile!.uid != UserService.currentUid &&
            _relationship != null)
          PopupMenuButton<_ProfileAction>(
            icon: const Icon(Icons.more_vert, color: AppColors.ink),
            onSelected: _handleAction,
            itemBuilder: (context) => _menuItemsFor(_relationship!),
          ),
      ],
    ),
  );

  List<PopupMenuItem<_ProfileAction>> _menuItemsFor(_Relationship relationship) {
    switch (relationship) {
      case _Relationship.friend:
        return const [
          PopupMenuItem(value: _ProfileAction.removeFriend, child: Text('刪除好友')),
          PopupMenuItem(value: _ProfileAction.block, child: Text('封鎖')),
        ];
      case _Relationship.blocked:
        return const [
          PopupMenuItem(value: _ProfileAction.unblock, child: Text('解除封鎖')),
        ];
      case _Relationship.stranger:
        return const [
          PopupMenuItem(value: _ProfileAction.addFriend, child: Text('加好友')),
          PopupMenuItem(value: _ProfileAction.block, child: Text('封鎖')),
        ];
    }
  }

  void _openChat() {
    final profile = _profile;
    if (profile == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          partnerUid: profile.uid,
          partnerNickname: profile.nickname,
          partnerAvatarUrl: profile.avatarUrl,
        ),
      ),
    );
  }

  Future<void> _handleAction(_ProfileAction action) async {
    final profile = _profile;
    if (profile == null) return;
    try {
      switch (action) {
        case _ProfileAction.addFriend:
          final status = await FriendService.sendRequest(uid: profile.uid);
          _showMessage(status == 'accepted' ? '你們已成為好友！' : '已送出好友邀請');
          break;
        case _ProfileAction.removeFriend:
          await FriendService.removeFriend(profile.uid);
          _showMessage('已刪除好友');
          break;
        case _ProfileAction.block:
          await FriendService.blockUser(profile.uid);
          _showMessage('已封鎖此使用者');
          break;
        case _ProfileAction.unblock:
          await FriendService.unblockUser(profile.uid);
          _showMessage('已解除封鎖');
          break;
      }
      _loadRelationship(profile.uid);
    } on ApiException catch (e) {
      _showMessage(_friendlyErrorMessage(e));
    } catch (e, st) {
      debugPrint('Failed to $action on public profile: $e');
      debugPrintStack(stackTrace: st);
      _showMessage('操作失敗，請稍後再試');
    }
  }

  String _friendlyErrorMessage(ApiException e) {
    if (e.isAlreadyFriends) return '你們已經是好友';
    if (e.isRequestAlreadySent) return '已送出邀請，等待對方回覆';
    if (e.isBlocked) return '因封鎖關係，無法執行此操作';
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
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
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
            style: AppTypography.headlineStyle(seniorMode: seniorMode, color: AppColors.ink),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            '加入 ${profile.joinedDays} 天',
            style: AppTypography.subtitleStyle(seniorMode: seniorMode, color: AppColors.fog),
          ),
          if (profile.bondShowcase.isNotEmpty) ...[
            const SizedBox(height: 10),
            _bondShowcaseRow(profile.bondShowcase, seniorMode),
          ],
          const SizedBox(height: 20),
          if (profile.selfIntro != null && profile.selfIntro!.isNotEmpty) ...[
            _card(
              child: Text(
                profile.selfIntro!,
                style: AppTypography.bodyLargeStyle(seniorMode: seniorMode, color: AppColors.ink),
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
                        style: AppTypography.captionStyle(seniorMode: seniorMode, color: AppColors.fog),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        profile.friendCode,
                        style: AppTypography.titleStyle(seniorMode: seniorMode, color: AppColors.ink),
                      ),
                    ],
                  ),
                  const Icon(Icons.copy, size: 18, color: AppColors.primary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _openChat,
              icon: const Icon(Icons.chat_bubble_outline, color: AppColors.primary),
              label: Text(
                '傳訊息',
                style: AppTypography.bodyLargeStyle(seniorMode: seniorMode, color: AppColors.primary),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
          decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.ink),
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

  Widget _bondShowcaseRow(List<BondShowcaseItem> items, bool seniorMode) => Column(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Text(
        '羈絆好友',
        style: AppTypography.subtitleStyle(seniorMode: seniorMode, color: AppColors.fog),
      ),
      const SizedBox(height: 6),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: items
            .map((item) => BondLevelBadge(
                  level: item.bondLevel.level,
                  name: item.bondLevel.name,
                  seniorMode: seniorMode,
                ))
            .toList(),
      ),
    ],
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
