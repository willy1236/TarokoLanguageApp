// 好友列表。入口：profile_screen「好友」卡片。
// 每列顯示暱稱/自我介紹，右上角提供「加好友」「邀請」「已封鎖名單」的入口。

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../models/friend_model.dart';
import '../../services/friend_service.dart';
import '../../services/senior_mode_controller.dart';
import '../../shared/widgets/truku_empty_state.dart';
import 'add_friend_screen.dart';
import 'blocked_users_screen.dart';
import 'friend_requests_screen.dart';
import 'public_profile_screen.dart';

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
                const SizedBox(height: 2),
                Text(
                  '羈絆 · ${f.bondLevel.name}',
                  style: AppTypography.captionStyle(seniorMode: seniorMode, color: AppColors.goldDeep),
                ),
              ],
            ),
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
