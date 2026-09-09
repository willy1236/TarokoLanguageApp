// 我封鎖的人。可在此解除封鎖。

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/network/api_client.dart';
import '../../models/friend_model.dart';
import '../../services/friend_service.dart';
import '../../services/senior_mode_controller.dart';
import '../../shared/widgets/truku_empty_state.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  List<BlockedUser>? _blocked;
  bool _loading = true;
  final Set<int> _busyUids = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final blocked = await FriendService.getBlockedUsers();
      if (!mounted) return;
      setState(() {
        _blocked = blocked;
        _loading = false;
      });
    } catch (e, st) {
      debugPrint('Failed to fetch blocked users: $e');
      debugPrintStack(stackTrace: st);
      if (!mounted) return;
      setState(() {
        _blocked = const [];
        _loading = false;
      });
    }
  }

  Future<void> _unblock(BlockedUser u) async {
    setState(() => _busyUids.add(u.uid));
    try {
      await FriendService.unblockUser(u.uid);
      if (!mounted) return;
      setState(() {
        _blocked?.removeWhere((e) => e.uid == u.uid);
        _busyUids.remove(u.uid);
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busyUids.remove(u.uid));
      _showError(e.message);
    } catch (e, st) {
      debugPrint('Failed to unblock user: $e');
      debugPrintStack(stackTrace: st);
      if (!mounted) return;
      setState(() => _busyUids.remove(u.uid));
      _showError('操作失敗，請稍後再試');
    }
  }

  void _showError(String message) {
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
            '已封鎖名單',
            style: AppTypography.titleStyle(seniorMode: seniorMode, color: AppColors.ink),
          ),
        ),
      ],
    ),
  );

  Widget _buildBody(bool seniorMode) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    final blocked = _blocked ?? const [];
    if (blocked.isEmpty) {
      return TrukuEmptyState(
        icon: Icons.block,
        message: '沒有封鎖任何人',
        subtitle: '封鎖的對象會顯示在這裡',
        seniorMode: seniorMode,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: blocked.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _blockedCard(blocked[i], seniorMode),
    );
  }

  Widget _blockedCard(BlockedUser u, bool seniorMode) {
    final busy = _busyUids.contains(u.uid);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.creamDeep),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              u.nickname?.isNotEmpty == true ? u.nickname! : '未命名旅人',
              style: AppTypography.bodyLargeStyle(seniorMode: seniorMode, color: AppColors.ink),
            ),
          ),
          if (busy)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
              ),
            )
          else
            TextButton(
              onPressed: () => _unblock(u),
              child: const Text('解除封鎖'),
            ),
        ],
      ),
    );
  }
}
