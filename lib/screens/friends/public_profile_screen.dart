// 公開個人檔案唯讀頁。目前僅顯示暱稱/自我介紹/好友碼/加入天數/羈絆等級，
// 加好友／封鎖／刪除好友等操作按鈕在 Stage 3 加入。

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/network/api_client.dart';
import '../../models/public_profile_model.dart';
import '../../services/friend_service.dart';
import '../../services/senior_mode_controller.dart';
import '../../shared/widgets/truku_empty_state.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
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
      ],
    ),
  );

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
            style: AppTypography.captionStyle(seniorMode: seniorMode, color: AppColors.fog),
          ),
          if (profile.bondLevel != null) ...[
            const SizedBox(height: 10),
            _bondBadge(profile.bondLevel!, seniorMode),
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
        ],
      ),
    );
  }

  Widget _avatar(PublicProfile profile, bool seniorMode) {
    final size = seniorMode ? 104.0 : 88.0;
    final avatarUrl = profile.avatarUrl;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.ink,
        border: Border.all(color: AppColors.gold, width: 2),
      ),
      child: ClipOval(
        child: (avatarUrl == null || avatarUrl.isEmpty)
            ? _initialsAvatar(profile, size)
            : Image.network(
                avatarUrl,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _initialsAvatar(profile, size),
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

  Widget _bondBadge(BondLevel level, bool seniorMode) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
    decoration: BoxDecoration(
      color: AppColors.gold.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(
      '羈絆 · ${level.name}',
      style: AppTypography.captionStyle(seniorMode: seniorMode, color: AppColors.goldDeep),
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
