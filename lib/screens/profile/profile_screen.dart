import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_typography.dart';
import '../../core/network/api_client.dart';
import '../../models/shop_item.dart';
import '../../models/tribe_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/fcm_service.dart';
import '../../services/senior_mode_controller.dart';
import '../../services/shop_service.dart';
import '../../services/user_service.dart';
import '../../shared/widgets/millet_coin_icon.dart';
import '../../shared/widgets/truku_painters.dart';
import '../../shared/widgets/tribe_picker_sheet.dart';
import '../../shared/widgets/user_avatar.dart';
import 'about_app_screen.dart';
import 'avatar_crop_screen.dart';
import '../backpack/backpack_screen.dart';
import '../events/my_events_screen.dart';
import '../shop/shop_screen.dart';
import '../millet/millet_ledger_screen.dart';
import 'my_bookmarks_screen.dart';
import 'my_likes_screen.dart';
import '../terms/terms_consent_screen.dart';
import '../friends/friends_list_screen.dart';

// 頭像檔案限制（後端規則：≤8MB，僅接受 JPEG/PNG/WebP/GIF），前端先擋掉明顯無效
// 的檔案以減少無效上傳，實際裁切壓縮一律由後端處理。
const int _kMaxAvatarBytes = 8 * 1024 * 1024;
const _kAllowedAvatarExtensions = {'jpg', 'jpeg', 'png', 'webp', 'gif'};

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserModel? _user;

  // 後端 GET /api/shop/items 的合併目錄（頭像＋頭像框，含 image_url）；id → item，
  // 供渲染頭貼／頭像框用。空 map 代表尚未取得或功能未開放，此時直接顯示預設圖示。
  Map<String, ShopItem> _itemCatalogById = const {};

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadItemCatalog();
  }

  Future<void> _loadUser() async {
    try {
      final user = await UserService.fetchMe();
      if (!mounted) return;
      setState(() => _user = user);
    } catch (e, st) {
      debugPrint('Failed to fetch user: $e');
      debugPrintStack(stackTrace: st);
      // 讀取失敗時退回空白/預設 UserModel，避免整個個人頁面崩潰。
      if (!mounted) return;
      setState(
        () => _user = UserModel(uid: 0, email: '', createdAt: DateTime.now()),
      );
    }
  }

  Future<void> _loadItemCatalog() async {
    try {
      final items = await ShopService.fetchShopItems();
      if (!mounted) return;
      setState(() {
        _itemCatalogById = {for (final i in items) i.id: i};
      });
    } catch (e) {
      // 取得失敗（含離線）：維持空 map，頭貼一律顯示預設圖示。
      debugPrint('ProfileScreen._loadItemCatalog failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: seniorModeController,
      builder: (context, _) => _buildScaffold(seniorModeController.enabled),
    );
  }

  Widget _buildScaffold(bool seniorMode) {
    return Scaffold(
      backgroundColor: AppColors.creamLight,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildHero(seniorMode: seniorMode),
          _buildCoinBanner(),
          _buildStatsRow(seniorMode: seniorMode),
          _buildQuickLinksGrid(seniorMode: seniorMode),
          _buildMoreSection(seniorMode: seniorMode),
          _buildSettingsSection(seniorMode: seniorMode),
          _buildAppSettingsSection(seniorMode: seniorMode),
          _buildOtherSection(seniorMode: seniorMode),
          _buildLogout(context),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ── Hero ──────────────────────────────────────────────────────────────────

  Widget _buildHero({required bool seniorMode}) {
    final tribeLine = _user?.isIndigenous == true
        ? (_user?.tribeName ?? '尚未設定')
        : null;
    return Container(
      decoration: const BoxDecoration(color: AppColors.midnight),
      child: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.15,
              child: CustomPaint(
                painter: TrukuWeavePainter(
                  color: AppColors.gold,
                  opacity: 1.0,
                  scale: 0.8,
                ),
              ),
            ),
          ),
          Positioned(
            top: 56,
            right: 16,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.creamLight.withValues(alpha: 0.15),
              ),
              child: CustomPaint(painter: _SettingsIconPainter()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 76, 20, 28),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAvatar(),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _user?.displayName ?? 'Apyang Imiq',
                        style: AppTypography.headlineStyle(
                          seniorMode: seniorMode,
                          color: AppColors.creamLight,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (tribeLine != null)
                        Text(
                          tribeLine,
                          style: AppTypography.bodyStyle(
                            seniorMode: seniorMode,
                            color: AppColors.creamLight.withValues(alpha: 0.75),
                          ),
                        ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (_user?.studyStreak != null && _user!.studyStreak > 0)
                            _infoBadge('連續 ${_user!.studyStreak} 天'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: AppTypography.captionStyle(color: AppColors.goldDeep),
      ),
    );
  }

  Widget _buildAvatar() {
    // 頭像框疊加在頭像外圍：frame_id 對應圖 + avatar_id 對應圖，框在外、頭像在中間
    // 疊加顯示（見 頭像商店.md §5）。無 frame_id 時維持純頭像圓形。
    final frameId = _user?.frameId;
    final frameImageUrl = frameId != null
        ? _itemCatalogById[frameId]?.imageUrl
        : null;
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (frameImageUrl != null)
            Image.network(
              frameImageUrl,
              width: 96,
              height: 96,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.ink,
              border: Border.all(color: AppColors.gold, width: 2),
            ),
            child: ClipOval(
              child: Center(
                child: UserAvatar(
                  avatarId: _user?.avatarId,
                  avatarUrl: _user?.avatarUrl,
                  itemCatalogById: _itemCatalogById,
                  size: 80,
                  fallbackIconColor: AppColors.gold.withValues(alpha: 0.7),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 6,
            right: 6,
            child: GestureDetector(
              onTap: _openAvatarOptions,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.gold,
                  border: Border.all(color: AppColors.primary, width: 2),
                ),
                child: CustomPaint(painter: _EditIconPainter()),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 背包／小米幣 ──────────────────────────────────────────────────────────

  /// 前往背包頁面（統一查看已擁有的頭像／頭像框並配戴）；背包頁目前不會 pop 回
  /// 更新後的 UserModel，因此回到本頁後一律重新呼叫 fetchMe() 以取得最新的
  /// avatarId/frameId。
  Future<void> _openBackpack() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const BackpackScreen()));
    if (!mounted) return;
    _loadUser();
  }

  /// 頭像編輯鉛筆入口：讓使用者選擇「從商店挑選內建頭像」或「上傳自己的照片」，
  /// 兩者互不衝突（上傳照片時後端會自動清空 avatar_id，見 uploadAvatar()）。
  Future<void> _openAvatarOptions() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.photo_library_outlined,
                color: Colors.black,
              ),
              title: const Text(
                '上傳照片',
                style: TextStyle(color: Colors.black),
              ),
              onTap: () => Navigator.pop(ctx, 'upload'),
            ),
            ListTile(
              leading: const Icon(
                Icons.inventory_2_outlined,
                color: Colors.black,
              ),
              title: const Text(
                '從商店選擇內建頭像',
                style: TextStyle(color: Colors.black),
              ),
              onTap: () => Navigator.pop(ctx, 'backpack'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'upload') {
      await _pickAndUploadAvatar();
    } else {
      await _openBackpack();
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final ext = picked.name.split('.').last.toLowerCase();
    if (!_kAllowedAvatarExtensions.contains(ext)) {
      _showError('僅接受 JPEG／PNG／WebP／GIF 圖片');
      return;
    }

    File file = File(picked.path);
    var mimeType = 'image/${ext == 'jpg' ? 'jpeg' : ext}';

    // GIF 為動態圖，裁切會破壞動畫，跳過裁切步驟直接上傳原圖。
    if (ext != 'gif') {
      final originalBytes = await file.readAsBytes();
      if (!mounted) return;
      final croppedBytes = await Navigator.push<Uint8List>(
        context,
        MaterialPageRoute(
          builder: (_) => AvatarCropScreen(imageBytes: originalBytes),
        ),
      );
      if (croppedBytes == null) return; // 使用者取消裁切，中止整個上傳流程

      final tempDir = await Directory.systemTemp.createTemp('avatar_crop_');
      final croppedFile = File('${tempDir.path}/avatar.png');
      await croppedFile.writeAsBytes(croppedBytes);
      file = croppedFile;
      mimeType = 'image/png';
    }

    final size = await file.length();
    if (size > _kMaxAvatarBytes) {
      _showError('檔案大小不可超過 8MB');
      return;
    }

    try {
      final updated = await UserService.uploadAvatar(file, contentType: mimeType);
      if (mounted) setState(() => _user = updated);
    } on ApiException catch (e) {
      if (e.isFileTooLarge) {
        _showError('檔案大小不可超過 8MB');
      } else if (e.isInvalidFileType) {
        _showError('僅接受 JPEG／PNG／WebP／GIF 圖片');
      } else {
        _showError(e.message);
      }
    } catch (e, st) {
      debugPrint('Failed to upload avatar: $e');
      debugPrintStack(stackTrace: st);
      _showError('頭像上傳失敗，請稍後再試');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// 前往商店頁面兌換新道具；商店頁不會 pop 回更新後的 UserModel，
  /// 因此回到本頁後一律重新呼叫 fetchMe() 以取得最新的 millet/owned 清單。
  Future<void> _openShop() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const ShopScreen()));
    if (!mounted) return;
    _loadUser();
  }

  Future<void> _openMilletLedger() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const MilletLedgerScreen()),
    );
  }

  Widget _buildCoinBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.creamDeep),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.gold.withValues(alpha: 0.2),
              ),
              child: const MilletCoinIcon(size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_user?.millet ?? 0}',
                    style: AppTypography.headlineStyle(color: AppColors.primary),
                  ),
                  Text(
                    '小米 · 每日登入／完成單元可得',
                    style: AppTypography.captionStyle(color: AppColors.fog),
                  ),
                ],
              ),
            ),
            OutlinedButton(
              onPressed: _openMilletLedger,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: const Text('明細'),
            ),
          ],
        ),
      ),
    );
  }

  // ── 統計 ──────────────────────────────────────────────────────────────────

  Widget _buildStatsRow({required bool seniorMode}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.creamDeep),
        ),
        child: Row(
          children: [
            _statCell(seniorMode, '${_user?.studyStreak ?? 0}', '連續學習'),
            _statDivider(),
            _statCell(seniorMode, '${_user?.videoCallCount ?? 0}', '通話次數'),
            _statDivider(),
            _statCell(seniorMode, '${_user?.forumPostCount ?? 0}', '發文'),
          ],
        ),
      ),
    );
  }

  Widget _statDivider() =>
      const SizedBox(height: 32, child: VerticalDivider(color: AppColors.creamDeep, width: 1));

  Widget _statCell(bool seniorMode, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: AppTypography.titleStyle(
              seniorMode: seniorMode,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTypography.captionStyle(
              seniorMode: seniorMode,
              color: AppColors.fog,
            ),
          ),
        ],
      ),
    );
  }

  // ── 快速入口（好友／背包／商店／收藏）─────────────────────────────────────

  Widget _buildQuickLinksGrid({required bool seniorMode}) {
    final links = [
      _QuickLink(
        icon: Icons.people_outline,
        label: '好友',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FriendsListScreen()),
        ),
      ),
      _QuickLink(
        icon: Icons.inventory_2_outlined,
        label: '背包',
        onTap: _openBackpack,
      ),
      _QuickLink(
        icon: Icons.storefront_outlined,
        label: '商店',
        onTap: _openShop,
      ),
      _QuickLink(
        icon: Icons.bookmark_outline,
        label: '收藏',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const MyBookmarksScreen()),
        ),
      ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _quickLinkCard(links[0], seniorMode: seniorMode)),
              const SizedBox(width: 12),
              Expanded(child: _quickLinkCard(links[1], seniorMode: seniorMode)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _quickLinkCard(links[2], seniorMode: seniorMode)),
              const SizedBox(width: 12),
              Expanded(child: _quickLinkCard(links[3], seniorMode: seniorMode)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quickLinkCard(_QuickLink link, {required bool seniorMode}) {
    return GestureDetector(
      onTap: link.onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.creamDeep),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.12),
              ),
              child: Icon(link.icon, size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                link.label,
                style: AppTypography.subtitleStyle(
                  seniorMode: seniorMode,
                  color: AppColors.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 更多（活動／按讚）────────────────────────────────────────────────────

  Widget _buildMoreSection({required bool seniorMode}) {
    return _section('SMRATUC · 更多', [
      _navRow(
        icon: Icons.event_note_outlined,
        label: '我發起的活動',
        seniorMode: seniorMode,
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const MyEventsScreen())),
      ),
      const Divider(height: 1, color: AppColors.creamDeep),
      _navRow(
        icon: Icons.favorite_border,
        label: '我按讚的內容',
        seniorMode: seniorMode,
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const MyLikesScreen())),
      ),
    ]);
  }

  Widget _navRow({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool seniorMode = false,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: seniorMode ? AppSpacing.lg : 14,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: seniorMode ? 30 : 18,
                  color: AppColors.primary,
                ),
                SizedBox(width: seniorMode ? AppSpacing.md : 10),
                Text(
                  label,
                  style: GoogleFonts.notoSerifTc(
                    fontSize: seniorMode ? AppTypography.headline : AppTypography.bodyLarge,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            Icon(
              Icons.chevron_right,
              color: AppColors.fog,
              size: seniorMode ? 24 : 16,
            ),
          ],
        ),
      ),
    );
  }

  // ── 帳號設定 ──────────────────────────────────────────────────────────────

  Widget _buildSettingsSection({required bool seniorMode}) {
    final identityLocked = _user?.ethnicGroup != null;
    return _section('PSPUNG · 個人資料設定', [
      _settingRow(
        '中文姓名',
        _user?.displayName ?? 'Apyang Imiq',
        editable: true,
        onTap: _editDisplayName,
      ),
      _settingRow(
        '公開暱稱',
        _user?.videoNickname ?? '尚未設定',
        editable: true,
        onTap: _editVideoNickname,
      ),
      _settingRow(
        '自我介紹',
        (_user?.selfIntro == null || _user!.selfIntro!.isEmpty)
            ? '尚未填寫'
            : _user!.selfIntro!,
        editable: true,
        onTap: _editSelfIntro,
      ),
      _settingRow(
        '好友碼',
        _user?.friendCode ?? '—',
        editable: _user?.friendCode != null,
        copyable: true,
        onTap: _copyFriendCode,
      ),
      _settingRow(
        '族語名字',
        _user?.tribalName ?? '尚未設定',
        // 尚未設定時顯示中文提示字，不套用族語專用的斜體字型，避免字型跟中文不搭。
        truku: _user?.tribalName != null && _user!.tribalName!.isNotEmpty,
        editable: true,
        onTap: _editTribalName,
      ),
      _switchRow(
        '是否原住民',
        _user?.isIndigenous ?? false,
        locked: true,
        lockedHint: '已設定，如需更正請聯繫管理員',
        onChanged: (_) {},
      ),
      _settingRow(
        '部落',
        _user?.tribeName ?? '尚未設定',
        editable: !identityLocked,
        onTap: identityLocked ? null : _editTribe,
      ),
      _settingRow('電子信箱', _user?.email ?? 'apyang@truku.org', editable: false),
    ]);
  }

  Widget _buildAppSettingsSection({required bool seniorMode}) {
    return _section('PUSU · App 設定', [
      _switchRow(
        '精簡模式',
        seniorMode,
        seniorMode: seniorMode,
        onChanged: (v) => seniorModeController.setEnabled(v),
      ),
    ]);
  }

  Future<void> _editDisplayName() async {
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => _RenameDialog(
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

  Future<void> _editTribalName() async {
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => _RenameDialog(
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

  Future<void> _editVideoNickname() async {
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => _RenameDialog(
        title: '修改公開暱稱',
        label: '公開暱稱',
        initialValue: _user?.videoNickname ?? '',
      ),
    );
    if (newName == null || newName.isEmpty || newName == _user?.videoNickname) {
      return;
    }
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
      builder: (ctx) => _RenameDialog(
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

  Future<void> _copyFriendCode() async {
    final code = _user?.friendCode;
    if (code == null) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已複製好友碼')));
  }

  // 目前僅太魯閣族一個族群，選部落時固定連同 ethnic_group 一起送，
  // 避免後端「改 ethnic_group 未附 tribe_id 就清空」的規則誤觸發。
  static const String _defaultEthnicGroup = '太魯閣族';

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

  // ── 其他 ──────────────────────────────────────────────────────────────────

  Widget _buildOtherSection({required bool seniorMode}) {
    const items = ['意見回饋', '關於語見太魯閣', '服務條款與隱私權政策'];
    return _section(
      'DUMA · 其他',
      List.generate(items.length, (i) {
        final onTap = items[i] == '服務條款與隱私權政策'
            ? _openTermsView
            : items[i] == '意見回饋'
            ? _openContactEmail
            : items[i] == '關於語見太魯閣'
            ? _openAboutApp
            : null;
        return Column(
          children: [
            InkWell(
              onTap: onTap,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: seniorMode ? AppSpacing.lg : 14,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      items[i],
                      style: GoogleFonts.notoSerifTc(
                        fontSize: seniorMode ? AppTypography.headline : AppTypography.bodyLarge,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: AppColors.fog,
                      size: seniorMode ? 24 : 16,
                    ),
                  ],
                ),
              ),
            ),
            if (i < items.length - 1)
              const Divider(
                height: 1,
                color: AppColors.creamDeep,
                indent: 16,
                endIndent: 16,
              ),
          ],
        );
      }),
    );
  }

  void _openAboutApp() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AboutAppScreen()));
  }

  void _openTermsView() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const TermsConsentScreen(readOnly: true),
      ),
    );
  }

  Future<void> _openContactEmail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'yujiantailuge@gmail.com',
      query: 'subject=語見太魯閣 App 意見回饋',
    );
    final launched = await launchUrl(uri);
    if (!launched && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('無法開啟郵件應用程式')));
    }
  }

  // ── 登出 ──────────────────────────────────────────────────────────────────

  Widget _buildLogout(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        children: [
          GestureDetector(
            onTap: () async {
              // 先移除本裝置 FCM token（需 JWT，故在 signOut 之前），再登出。
              await FcmService.unregisterDevice();
              UserService.clearCache();
              await AuthService.signOut();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login',
                  (_) => false,
                );
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CustomPaint(
                    size: const Size(16, 16),
                    painter: _LogoutIconPainter(),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '登出',
                    style: GoogleFonts.notoSerifTc(
                      fontSize: AppTypography.bodyLarge,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'v1.0.0 · MHUWAY SU',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              color: AppColors.fog,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  // ── 共用 section 外框 ─────────────────────────────────────────────────────

  Widget _section(String label, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.crimsonPro(
              fontStyle: FontStyle.italic,
              fontSize: 10,
              color: AppColors.fog,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.cream,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.creamDeep),
            ),
            clipBehavior: Clip.hardEdge,
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _settingRow(
    String label,
    String value, {
    bool truku = false,
    bool editable = true,
    bool copyable = false,
    VoidCallback? onTap,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: editable ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.notoSerifTc(
                        fontSize: AppTypography.caption,
                        color: AppColors.fog,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style:
                          (truku
                                  ? GoogleFonts.crimsonPro(
                                      fontStyle: FontStyle.italic,
                                    )
                                  : GoogleFonts.notoSerifTc())
                              .copyWith(
                                fontSize: AppTypography.bodyLarge,
                                fontWeight: FontWeight.w600,
                                color: AppColors.ink,
                                letterSpacing: 0.5,
                              ),
                    ),
                  ],
                ),
                if (copyable)
                  Icon(Icons.copy_rounded, size: 16, color: AppColors.primary)
                else if (editable)
                  CustomPaint(
                    size: const Size(16, 16),
                    painter: _EditPenPainter(),
                  ),
              ],
            ),
          ),
        ),
        const Divider(
          height: 1,
          color: AppColors.creamDeep,
          indent: 16,
          endIndent: 16,
        ),
      ],
    );
  }

  /// 可互動的開關列，供族群鎖定等需要送出 PATCH 的設定使用（區別於純顯示用的
  /// [_toggleRow]）。locked=true 時停用點擊，並在下方顯示 lockedHint 提示。
  Widget _switchRow(
    String label,
    bool on, {
    required ValueChanged<bool> onChanged,
    bool locked = false,
    String? lockedHint,
    bool seniorMode = false,
  }) {
    final trackWidth = seniorMode ? 52.0 : 36.0;
    final trackHeight = seniorMode ? 30.0 : 22.0;
    final thumbSize = seniorMode ? 26.0 : 18.0;
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: seniorMode ? AppSpacing.lg : 14,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.notoSerifTc(
                        fontSize: seniorMode ? AppTypography.headline : AppTypography.bodyLarge,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (locked && lockedHint != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        lockedHint,
                        style: GoogleFonts.notoSerifTc(
                          fontSize: AppTypography.caption,
                          color: AppColors.fog,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              GestureDetector(
                onTap: locked ? null : () => onChanged(!on),
                child: Container(
                  width: trackWidth,
                  height: trackHeight,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(trackHeight / 2),
                    color: on
                        ? (locked
                              ? AppColors.primary.withValues(alpha: 0.5)
                              : AppColors.primary)
                        : AppColors.creamDeep,
                  ),
                  child: Align(
                    alignment: on
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      width: thumbSize,
                      height: thumbSize,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.creamLight,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(
          height: 1,
          color: AppColors.creamDeep,
          indent: 16,
          endIndent: 16,
        ),
      ],
    );
  }

}

class _QuickLink {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickLink({required this.icon, required this.label, required this.onTap});
}

class _RenameDialog extends StatefulWidget {
  final String title;
  final String label;
  final String initialValue;
  const _RenameDialog({
    required this.title,
    required this.label,
    required this.initialValue,
  });

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(labelText: widget.label),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('儲存'),
        ),
      ],
    );
  }
}

// ── SVG 圖示 Painters ─────────────────────────────────────────────────────────

class _EditIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(size.width * 0.58, size.height * 0.17)
      ..lineTo(size.width * 0.83, size.height * 0.42)
      ..lineTo(size.width * 0.33, size.height * 0.92)
      ..lineTo(size.width * 0.08, size.height * 0.92)
      ..lineTo(size.width * 0.08, size.height * 0.67)
      ..close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

class _EditPenPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(size.width * 0.58, size.height * 0.17)
      ..lineTo(size.width * 0.83, size.height * 0.42)
      ..lineTo(size.width * 0.33, size.height * 0.92)
      ..lineTo(size.width * 0.08, size.height * 0.92)
      ..lineTo(size.width * 0.08, size.height * 0.67)
      ..close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

class _LogoutIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.55, size.height * 0.5),
      Offset(size.width, size.height * 0.5),
      p,
    );
    canvas.drawLine(
      Offset(size.width * 0.75, size.height * 0.25),
      Offset(size.width, size.height * 0.5),
      p,
    );
    canvas.drawLine(
      Offset(size.width * 0.75, size.height * 0.75),
      Offset(size.width, size.height * 0.5),
      p,
    );
    final door = Path()
      ..moveTo(size.width * 0.45, size.height * 0.13)
      ..lineTo(size.width * 0.2, size.height * 0.13)
      ..arcToPoint(
        Offset(size.width * 0.08, size.height * 0.25),
        radius: Radius.circular(size.width * 0.12),
      )
      ..lineTo(size.width * 0.08, size.height * 0.75)
      ..arcToPoint(
        Offset(size.width * 0.2, size.height * 0.87),
        radius: Radius.circular(size.width * 0.12),
      )
      ..lineTo(size.width * 0.45, size.height * 0.87);
    canvas.drawPath(door, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

class _SettingsIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.creamLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.16;
    canvas.drawCircle(Offset(cx, cy), r, p);
    for (int i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      final inner = r + size.width * 0.08;
      final outer = r + size.width * 0.22;
      canvas.drawLine(
        Offset(cx + inner * math.cos(a), cy + inner * math.sin(a)),
        Offset(cx + outer * math.cos(a), cy + outer * math.sin(a)),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}
