// 我收到的待回覆好友邀請。接受/拒絕後回傳 true 讓上一頁刷新列表。

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/network/api_client.dart';
import '../../models/friend_model.dart';
import '../../services/friend_service.dart';
import '../../services/senior_mode_controller.dart';
import '../../shared/widgets/truku_empty_state.dart';

class FriendRequestsScreen extends StatefulWidget {
  const FriendRequestsScreen({super.key});

  @override
  State<FriendRequestsScreen> createState() => _FriendRequestsScreenState();
}

class _FriendRequestsScreenState extends State<FriendRequestsScreen> {
  List<FriendRequest>? _requests;
  bool _loading = true;
  bool _changed = false;
  final Set<int> _busyUids = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final requests = await FriendService.getIncomingRequests();
      if (!mounted) return;
      setState(() {
        _requests = requests;
        _loading = false;
      });
    } catch (e, st) {
      debugPrint('Failed to fetch friend requests: $e');
      debugPrintStack(stackTrace: st);
      if (!mounted) return;
      setState(() {
        _requests = const [];
        _loading = false;
      });
    }
  }

  Future<void> _accept(FriendRequest r) async {
    setState(() => _busyUids.add(r.uid));
    try {
      await FriendService.acceptRequest(r.uid);
      _changed = true;
      if (!mounted) return;
      setState(() {
        _requests?.removeWhere((e) => e.uid == r.uid);
        _busyUids.remove(r.uid);
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busyUids.remove(r.uid));
      _showError(e.message);
    } catch (e, st) {
      debugPrint('Failed to accept friend request: $e');
      debugPrintStack(stackTrace: st);
      if (!mounted) return;
      setState(() => _busyUids.remove(r.uid));
      _showError('操作失敗，請稍後再試');
    }
  }

  Future<void> _decline(FriendRequest r) async {
    setState(() => _busyUids.add(r.uid));
    try {
      await FriendService.declineRequest(r.uid);
      _changed = true;
      if (!mounted) return;
      setState(() {
        _requests?.removeWhere((e) => e.uid == r.uid);
        _busyUids.remove(r.uid);
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busyUids.remove(r.uid));
      _showError(e.message);
    } catch (e, st) {
      debugPrint('Failed to decline friend request: $e');
      debugPrintStack(stackTrace: st);
      if (!mounted) return;
      setState(() => _busyUids.remove(r.uid));
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

  Widget _buildScaffold(bool seniorMode) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (didPop) return;
      Navigator.of(context).pop(_changed);
    },
    child: Scaffold(
      backgroundColor: AppColors.creamLight,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(seniorMode),
            Expanded(child: _buildBody(seniorMode)),
          ],
        ),
      ),
    ),
  );

  Widget _topBar(bool seniorMode) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
    child: Row(
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).pop(_changed),
          icon: const Icon(Icons.arrow_back, color: AppColors.ink),
        ),
        Expanded(
          child: Text(
            '好友邀請',
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
    final requests = _requests ?? const [];
    if (requests.isEmpty) {
      return TrukuEmptyState(
        icon: Icons.mail_outline,
        message: '目前沒有待回覆的邀請',
        subtitle: '有人加你好友時會顯示在這裡',
        seniorMode: seniorMode,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: requests.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _requestCard(requests[i], seniorMode),
    );
  }

  Widget _requestCard(FriendRequest r, bool seniorMode) {
    final busy = _busyUids.contains(r.uid);
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.nickname?.isNotEmpty == true ? r.nickname! : '未命名旅人',
                  style: AppTypography.bodyLargeStyle(seniorMode: seniorMode, color: AppColors.ink),
                ),
                if (r.selfIntro != null && r.selfIntro!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    r.selfIntro!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.captionStyle(seniorMode: seniorMode, color: AppColors.fog),
                  ),
                ],
              ],
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
          else ...[
            IconButton(
              onPressed: () => _decline(r),
              icon: const Icon(Icons.close, color: AppColors.fog),
              tooltip: '拒絕',
            ),
            IconButton(
              onPressed: () => _accept(r),
              icon: const Icon(Icons.check_circle, color: AppColors.primary),
              tooltip: '接受',
            ),
          ],
        ],
      ),
    );
  }
}
