import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../main.dart';
import '../../models/friend_model.dart';
import '../../models/shop_item.dart';
import '../../services/friend_service.dart';
import '../../services/shop_service.dart';
import '../../services/video_call_service.dart';
import '../../shared/widgets/truku_painters.dart';
import '../../shared/widgets/user_avatar.dart';
import '../chat/chat_screen.dart';
import '../friends/friends_list_screen.dart';
import '../profile/profile_screen.dart';
import 'video_call_notice_screen.dart';
import 'video_call_screen.dart';
import 'video_waiting_screen.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  bool _isJoining = false;

  List<Friendship>? _friends;
  bool _friendsLoading = true;
  Map<String, ShopItem> _itemCatalogById = const {};

  @override
  void initState() {
    super.initState();
    _loadFriends();
    _loadItemCatalog();
  }

  Future<void> _loadFriends() async {
    setState(() => _friendsLoading = true);
    try {
      final friends = await FriendService.getFriends();
      if (!mounted) return;
      setState(() {
        _friends = friends;
        _friendsLoading = false;
      });
    } catch (e) {
      debugPrint('Failed to fetch friends: $e');
      if (!mounted) return;
      setState(() {
        _friends = const [];
        _friendsLoading = false;
      });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamLight,
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            _buildHeroCard(),
            _buildNoticeLink(),
            _buildFriendList(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PGKALA · 互動',
            style: GoogleFonts.crimsonPro(
              fontStyle: FontStyle.italic,
              fontSize: 12,
              color: AppColors.fog,
              letterSpacing: 3.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '面對面，學族語',
            style: GoogleFonts.notoSerifTc(
              fontSize: 26,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            Container(
              color: AppColors.ink,
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // weave background
                  SizedBox(
                    height: 0,
                    child: OverflowBox(
                      maxHeight: double.infinity,
                      alignment: Alignment.topLeft,
                      child: SizedBox(
                        width: MediaQuery.of(context).size.width - 40,
                        height: 220,
                        child: Opacity(
                          opacity: 0.12,
                          child: CustomPaint(
                            painter: TrukuWeavePainter(
                              color: AppColors.gold,
                              opacity: 1.0,
                              scale: 0.7,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Text(
                    '1 ON 1 · KMSAPUH',
                    style: GoogleFonts.crimsonPro(
                      fontStyle: FontStyle.italic,
                      fontSize: 11,
                      color: AppColors.gold,
                      letterSpacing: 3.0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '和耆老一對一\n用族語聊 10 分鐘',
                    style: GoogleFonts.notoSerifTc(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppColors.creamLight,
                      height: 1.3,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '系統會幫你配對線上的族人',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.creamLight.withValues(alpha: 0.7),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildAvatarRow(),
                  const SizedBox(height: 16),
                  _buildStartButton(),
                ],
              ),
            ),
            // actual weave overlay
            Positioned.fill(
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0.12,
                  child: CustomPaint(
                    painter: TrukuWeavePainter(
                      color: AppColors.gold,
                      opacity: 1.0,
                      scale: 0.7,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoticeLink() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const VideoCallNoticeScreen()),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shield_outlined, size: 14, color: AppColors.fog),
            const SizedBox(width: 6),
            Text(
              '查看視訊配對須知',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.fog,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.fog,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarRow() {
    const initials = ['B', 'Y', 'P', 'S'];
    return Row(
      children: [
        SizedBox(
          width: 32.0 + (initials.length - 1) * 22.0,
          height: 32,
          child: Stack(
            children: List.generate(initials.length, (i) {
              return Positioned(
                left: i * 22.0,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i.isEven ? AppColors.primary : AppColors.moss,
                    border: Border.all(color: AppColors.ink, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initials[i],
                    style: GoogleFonts.notoSerifTc(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.gold,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(width: 10),
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.online,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '族人在線中',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.creamLight.withValues(alpha: 0.85),
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 開始配對：先要相機/麥克風權限，再呼叫後端佇列 API。配到直接進通話畫面，
  /// 否則進等待畫面排隊。後端 FIFO 配對，不區分/不針對特定 rudan。
  Future<void> _startMatching() async {
    if (_isJoining) return;
    setState(() => _isJoining = true);
    try {
      final camera = await Permission.camera.request();
      final mic = await Permission.microphone.request();
      if (!camera.isGranted || !mic.isGranted) {
        _showMessage('需要相機與麥克風權限才能開始視訊配對');
        return;
      }

      if (!await hasSeenVideoCallNotice()) {
        if (!mounted) return;
        final agreed = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => const VideoCallNoticeScreen()),
        );
        if (agreed != true) {
          return;
        }
        await markVideoCallNoticeSeen();
      }

      final result = await VideoCallService.joinQueue();
      if (!mounted) return;
      if (result.matched) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VideoCallScreen(
              session: result.session!,
              credentials: result.credentials!,
            ),
          ),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const VideoWaitingScreen()),
        );
      }
    } on ApiException catch (e) {
      if (e.isVideoNicknameRequired) {
        _showVideoNicknameRequiredDialog();
      } else {
        _showMessage(e.isVideoUnavailable ? '視訊功能暫時無法使用，請稍後再試' : e.message);
      }
    } catch (_) {
      _showMessage('連線失敗，請稍後再試');
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  void _showMessage(String message) {
    scaffoldMessengerKey.currentState
      ?..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showVideoNicknameRequiredDialog() async {
    if (!mounted) return;
    final goToProfile = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('請先設定視訊暱稱'),
        content: const Text('視訊配對前需要先在個人資料設定一個視訊暱稱，讓對方在通話時看到。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('前往設定'),
          ),
        ],
      ),
    );
    if (goToProfile == true && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      );
    }
  }

  Widget _buildStartButton() {
    return GestureDetector(
      onTap: _isJoining ? null : _startMatching,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.gold.withValues(alpha: _isJoining ? 0.6 : 1.0),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CustomPaint(
              size: const Size(16, 16),
              painter: _VideoIconPainter(AppColors.ink),
            ),
            const SizedBox(width: 8),
            Text(
              _isJoining ? '配對中…' : '開始配對',
              style: GoogleFonts.notoSerifTc(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
                letterSpacing: 2.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendList() {
    const maxShown = 5;
    final friends = _friends;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '我的好友',
                style: GoogleFonts.notoSerifTc(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                  letterSpacing: 1.5,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FriendsListScreen()),
                ),
                child: Text(
                  '查看全部 →',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.primary,
                    letterSpacing: 2.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_friendsLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (friends == null || friends.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                '尚無好友，先去加好友吧',
                style: TextStyle(fontSize: 12, color: AppColors.fog),
              ),
            )
          else
            ...List.generate(
              friends.length > maxShown ? maxShown : friends.length,
              (i) {
                final shown = friends.length > maxShown
                    ? maxShown
                    : friends.length;
                return Padding(
                  padding: EdgeInsets.only(bottom: i < shown - 1 ? 10 : 0),
                  child: _FriendTile(
                    friend: friends[i],
                    itemCatalogById: _itemCatalogById,
                    onTap: () => _chatWithFriend(friends[i]),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

// ─── 好友列表項目 ──────────────────────────────────────────────────────────────

class _FriendTile extends StatelessWidget {
  final Friendship friend;
  final Map<String, ShopItem> itemCatalogById;
  final VoidCallback onTap;

  const _FriendTile({
    required this.friend,
    required this.itemCatalogById,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.creamDeep),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 52,
              height: 52,
              child: Center(
                child: FramedUserAvatar(
                  avatarId: friend.avatarId,
                  avatarUrl: friend.avatarUrl,
                  frameId: friend.frameId,
                  itemCatalogById: itemCatalogById,
                  size: 44,
                  fallbackIconColor: AppColors.gold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    friend.nickname ?? friend.friendCode ?? '未命名好友',
                    style: GoogleFonts.notoSerifTc(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    friend.bondLevel.name,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.fog,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.creamDeep),
              ),
              child: Text(
                '聊天',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.primary,
                  letterSpacing: 2.0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 視訊 icon (M15 5 L20 3 V21 L15 19 H4 V5 Z) ───────────────────────────

class _VideoIconPainter extends CustomPainter {
  final Color color;
  const _VideoIconPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 15 / 24, h * 5 / 24)
      ..lineTo(w * 20 / 24, h * 3 / 24)
      ..lineTo(w * 20 / 24, h * 21 / 24)
      ..lineTo(w * 15 / 24, h * 19 / 24)
      ..lineTo(w * 15 / 24, h * 19 / 24)
      ..lineTo(w * 4 / 24, h * 19 / 24)
      ..lineTo(w * 4 / 24, h * 5 / 24)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_VideoIconPainter old) => old.color != color;
}
