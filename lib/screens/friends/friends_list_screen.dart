// 好友列表。入口：profile_screen「好友」卡片。
// 每列顯示暱稱/自我介紹，右上角提供「加好友」「邀請」「已封鎖名單」的入口。

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/network/api_client.dart';
import '../../models/friend_model.dart';
import '../../services/friend_service.dart';
import '../../services/senior_mode_controller.dart';
import '../../shared/widgets/truku_empty_state.dart';
import '../chat/chat_screen.dart';
import '../chat/conversations_list_screen.dart';
import 'add_friend_screen.dart';
import 'blocked_users_screen.dart';
import 'directed_call_waiting_screen.dart';
import 'friend_requests_screen.dart';
import 'public_profile_screen.dart';
import 'widgets/bond_level_badge.dart';
import 'widgets/showcase_chip.dart';

class FriendsListScreen extends StatefulWidget {
  const FriendsListScreen({super.key});

  @override
  State<FriendsListScreen> createState() => _FriendsListScreenState();
}

class _FriendsListScreenState extends State<FriendsListScreen> {
  List<Friendship>? _friends;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final friends = await FriendService.getFriends();
      if (!mounted) return;
      setState(() {
        _friends = friends;
        _loading = false;
      });
    } catch (e, st) {
      debugPrint('Failed to fetch friends: $e');
      debugPrintStack(stackTrace: st);
      if (!mounted) return;
      setState(() {
        _friends = const [];
        _loading = false;
      });
    }
  }

  Future<void> _openAddFriend() async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AddFriendScreen()),
    );
    if (added == true) _load();
  }

  Future<void> _openRequests() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const FriendRequestsScreen()),
    );
    if (changed == true) _load();
  }

  void _openBlockedUsers() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const BlockedUsersScreen()),
    );
  }

  Future<void> _openFriendProfile(Friendship f) async {
    final code = f.friendCode;
    if (code == null) return;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => PublicProfileScreen(friendCode: code)),
    );
    if (changed == true) _load();
  }

  void _openConversations() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ConversationsListScreen()),
    );
  }

  void _chatWithFriend(Friendship f) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          partnerUid: f.uid,
          partnerNickname: f.nickname,
          partnerAvatarUrl: f.avatarUrl,
        ),
      ),
    );
  }

  Future<void> _toggleShowcase(Friendship f) async {
    final friends = _friends;
    if (friends == null) return;
    final idx = friends.indexOf(f);
    if (idx == -1) return;
    if (f.showcase.mutual) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('取消顯示羈絆？'),
          content: const Text('對方檔案上將立即看不到你們的羈絆等級。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('返回'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('取消顯示'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    final previous = List<Friendship>.from(friends);
    final requesting = !f.showcase.mine;
    setState(() {
      _friends = List<Friendship>.from(friends)
        ..[idx] = f.copyWith(
          showcase: requesting
              ? Showcase(mine: true, theirs: f.showcase.theirs, mutual: false)
              : Showcase.none,
        );
    });
    try {
      if (requesting) {
        final result = await FriendService.setShowcase(f.uid);
        if (!mounted) return;
        setState(() {
          final current = _friends;
          if (current == null) return;
          final i = current.indexWhere((e) => e.uid == f.uid);
          if (i == -1) return;
          _friends = List<Friendship>.from(current)
            ..[i] = current[i].copyWith(showcase: result);
        });
      } else {
        await FriendService.unsetShowcase(f.uid);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _friends = previous);
      _showError(e.message);
    } catch (e, st) {
      debugPrint('Failed to toggle showcase: $e');
      debugPrintStack(stackTrace: st);
      if (!mounted) return;
      setState(() => _friends = previous);
      _showError('操作失敗，請稍後再試');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _callFriend(Friendship f) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DirectedCallWaitingScreen(
          calleeUid: f.uid,
          calleeNickname: f.nickname,
        ),
      ),
    );
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
          Expanded(child: _buildBody(seniorMode)),
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
          icon: const Icon(Icons.arrow_back, color: AppColors.ink),
        ),
        Expanded(
          child: Text(
            '好友',
            style: AppTypography.titleStyle(seniorMode: seniorMode, color: AppColors.ink),
          ),
        ),
        IconButton(
          onPressed: _openConversations,
          icon: const Icon(Icons.chat_bubble_outline, color: AppColors.primary),
          tooltip: '訊息',
        ),
        IconButton(
          onPressed: _openRequests,
          icon: const Icon(Icons.mail_outline, color: AppColors.primary),
          tooltip: '好友邀請',
        ),
        IconButton(
          onPressed: _openBlockedUsers,
          icon: const Icon(Icons.block, color: AppColors.fog),
          tooltip: '已封鎖名單',
        ),
        IconButton(
          onPressed: _openAddFriend,
          icon: const Icon(Icons.person_add_alt_1, color: AppColors.primary),
          tooltip: '加好友',
        ),
      ],
    ),
  );

  Widget _buildBody(bool seniorMode) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    final friends = _friends ?? const [];
    if (friends.isEmpty) {
      return TrukuEmptyState(
        icon: Icons.people_outline,
        message: '還沒有好友',
        subtitle: '輸入對方的好友碼即可加好友',
        seniorMode: seniorMode,
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: friends.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) => _friendCard(friends[i], seniorMode),
      ),
    );
  }

  Widget _friendCard(Friendship f, bool seniorMode) => GestureDetector(
    onTap: () => _openFriendProfile(f),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.creamDeep),
      ),
      child: Row(
        children: [
          _avatar(f, seniorMode),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  f.nickname?.isNotEmpty == true ? f.nickname! : '未命名旅人',
                  style: AppTypography.bodyLargeStyle(seniorMode: seniorMode, color: AppColors.ink),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    BondLevelBadge(
                      level: f.bondLevel.level,
                      name: f.bondLevel.name,
                      seniorMode: seniorMode,
                    ),
                    ShowcaseChip(
                      showcase: f.showcase,
                      seniorMode: seniorMode,
                      onTap: () => _toggleShowcase(f),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _chatWithFriend(f),
            icon: const Icon(Icons.chat_bubble_outline, color: AppColors.primary),
            tooltip: '傳訊息',
          ),
          IconButton(
            onPressed: () => _callFriend(f),
            icon: const Icon(Icons.videocam_outlined, color: AppColors.primary),
            tooltip: '視訊通話',
          ),
          const Icon(Icons.chevron_right, color: AppColors.fog, size: 18),
        ],
      ),
    ),
  );

  Widget _avatar(Friendship f, bool seniorMode) {
    final size = seniorMode ? 52.0 : 44.0;
    final avatarUrl = f.avatarUrl;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.ink,
        border: Border.all(color: AppColors.gold, width: 1.5),
      ),
      child: ClipOval(
        child: (avatarUrl == null || avatarUrl.isEmpty)
            ? Center(
                child: Text(
                  f.nickname?.characters.firstOrNull ?? '?',
                  style: AppTypography.bodyLargeStyle(color: AppColors.gold),
                ),
              )
            : Image.network(
                avatarUrl,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Center(
                  child: Text(
                    f.nickname?.characters.firstOrNull ?? '?',
                    style: AppTypography.bodyLargeStyle(color: AppColors.gold),
                  ),
                ),
              ),
      ),
    );
  }
}
