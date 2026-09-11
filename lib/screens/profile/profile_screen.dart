import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_typography.dart';
import '../../core/network/api_client.dart';
import '../../core/platform/platform_features.dart';
import '../../models/shop_item.dart';
import '../../models/tribe_model.dart';
import '../../models/user_model.dart';
import '../../services/senior_mode_controller.dart';
import '../../services/shop_service.dart';
import '../../services/user_service.dart';
import '../../shared/widgets/tribe_picker_sheet.dart';
import 'about_app_screen.dart';
import 'widgets/profile_hero.dart';
import 'widgets/profile_logout_button.dart';
import 'widgets/profile_rename_dialog.dart';
import 'widgets/profile_rows.dart';
import 'widgets/profile_stats.dart';
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
  /// 由外層（合併分頁的膠囊切換）注入，顯示在頁面最上方。
  final Widget? topToggle;

  const ProfileScreen({super.key, this.topToggle});

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
    // 頂部是深色 hero，狀態列圖示改用淺色。
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.creamLight,
        body: ListView(
          padding: EdgeInsets.zero,
          children: [
            ProfileHero(
              user: _user,
              itemCatalogById: _itemCatalogById,
              seniorMode: seniorMode,
              onAvatarTap: _openAvatarOptions,
              topToggle: widget.topToggle,
            ),
            ProfileCoinBanner(
              user: _user,
              seniorMode: seniorMode,
              onTap: _openMilletLedger,
            ),
            ProfileStatsRow(user: _user, seniorMode: seniorMode),
            _buildQuickLinksGrid(seniorMode: seniorMode),
            _buildMoreSection(seniorMode: seniorMode),
            _buildSettingsSection(seniorMode: seniorMode),
            _buildAppSettingsSection(seniorMode: seniorMode),
            _buildOtherSection(seniorMode: seniorMode),
            const ProfileLogoutButton(),
            const SizedBox(height: 40),
          ],
        ),
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
              title: const Text('上傳照片', style: TextStyle(color: Colors.black)),
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

    if (!PlatformFeatures.hasFileSystem) {
      await _uploadAvatarWithoutFileSystem(picked, ext);
      return;
    }

    File file = File(picked.path);
    var mimeType = 'image/${ext == 'jpg' ? 'jpeg' : ext}';
    // 裁切產生的暫存目錄：無論成功、失敗或提早 return 都要刪掉，
    // 否則每換一次頭像就在裝置上多留一份圖。
    Directory? cropTempDir;

    try {
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
        cropTempDir = tempDir;
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

      final updated = await UserService.uploadAvatar(
        file,
        contentType: mimeType,
      );
      if (mounted) setState(() => _user = updated);
    } catch (e, st) {
      _showAvatarUploadError(e, st);
    } finally {
      try {
        await cropTempDir?.delete(recursive: true);
      } catch (e) {
        debugPrint('ProfileScreen: 刪除頭像裁切暫存檔失敗（忽略）：$e');
      }
    }
  }

  /// Web 版頭像上傳：沒有本機檔案系統，全程只處理 bytes、不寫暫存檔。
  Future<void> _uploadAvatarWithoutFileSystem(XFile picked, String ext) async {
    var mimeType = 'image/${ext == 'jpg' ? 'jpeg' : ext}';
    var filename = picked.name;

    try {
      var bytes = await picked.readAsBytes();
      // GIF 為動態圖，裁切會破壞動畫，跳過裁切步驟直接上傳原圖。
      if (ext != 'gif') {
        if (!mounted) return;
        final croppedBytes = await Navigator.push<Uint8List>(
          context,
          MaterialPageRoute(
            builder: (_) => AvatarCropScreen(imageBytes: bytes),
          ),
        );
        if (croppedBytes == null) return; // 使用者取消裁切，中止整個上傳流程
        bytes = croppedBytes;
        mimeType = 'image/png';
        filename = 'avatar.png';
      }

      if (bytes.length > _kMaxAvatarBytes) {
        _showError('檔案大小不可超過 8MB');
        return;
      }

      final updated = await UserService.uploadAvatarBytes(
        bytes,
        filename: filename,
        contentType: mimeType,
      );
      if (mounted) setState(() => _user = updated);
    } catch (e, st) {
      _showAvatarUploadError(e, st);
    }
  }

  void _showAvatarUploadError(Object e, StackTrace st) {
    if (e is ApiException) {
      if (e.isFileTooLarge) {
        _showError('檔案大小不可超過 8MB');
      } else if (e.isInvalidFileType) {
        _showError('僅接受 JPEG／PNG／WebP／GIF 圖片');
      } else {
        _showError(e.message);
      }
    } else {
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
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const MilletLedgerScreen()));
  }

  // ── 快速入口（好友／背包／商店／收藏）─────────────────────────────────────

  Widget _buildQuickLinksGrid({required bool seniorMode}) {
    final links = [
      ProfileQuickLink(
        icon: Icons.people_outline,
        label: '好友',
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const FriendsListScreen())),
      ),
      ProfileQuickLink(
        icon: Icons.inventory_2_outlined,
        label: '背包',
        onTap: _openBackpack,
      ),
      ProfileQuickLink(
        icon: Icons.storefront_outlined,
        label: '商店',
        onTap: _openShop,
      ),
      ProfileQuickLink(
        icon: Icons.bookmark_outline,
        label: '收藏',
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const MyBookmarksScreen())),
      ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: profileQuickLinkCard(links[0], seniorMode: seniorMode),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: profileQuickLinkCard(links[1], seniorMode: seniorMode),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: profileQuickLinkCard(links[2], seniorMode: seniorMode),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: profileQuickLinkCard(links[3], seniorMode: seniorMode),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 更多（活動／按讚）────────────────────────────────────────────────────

  Widget _buildMoreSection({required bool seniorMode}) {
    return profileSection('SMRATUC · 更多', [
      profileNavRow(
        icon: Icons.event_note_outlined,
        label: '我發起的活動',
        seniorMode: seniorMode,
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const MyEventsScreen())),
      ),
      const Divider(height: 1, color: AppColors.creamDeep),
      profileNavRow(
        icon: Icons.favorite_border,
        label: '我按讚的內容',
        seniorMode: seniorMode,
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const MyLikesScreen())),
      ),
    ]);
  }

  // ── 帳號設定 ──────────────────────────────────────────────────────────────

  Widget _buildSettingsSection({required bool seniorMode}) {
    final identityLocked = _user?.ethnicGroup != null;
    return profileSection('PSPUNG · 個人資料設定', [
      profileSettingRow(
        '中文姓名',
        _user?.displayName ?? 'Apyang Imiq',
        editable: true,
        onTap: _editDisplayName,
      ),
      profileSettingRow(
        '公開暱稱',
        _user?.videoNickname ?? '尚未設定',
        editable: true,
        onTap: _editVideoNickname,
      ),
      profileSettingRow(
        '自我介紹',
        (_user?.selfIntro == null || _user!.selfIntro!.isEmpty)
            ? '尚未填寫'
            : _user!.selfIntro!,
        editable: true,
        onTap: _editSelfIntro,
      ),
      profileSettingRow(
        '好友碼',
        _user?.friendCode ?? '—',
        editable: _user?.friendCode != null,
        copyable: true,
        onTap: _copyFriendCode,
      ),
      profileSettingRow(
        '族語名字',
        _user?.tribalName ?? '尚未設定',
        // 尚未設定時顯示中文提示字，不套用族語專用的斜體字型，避免字型跟中文不搭。
        truku: _user?.tribalName != null && _user!.tribalName!.isNotEmpty,
        editable: true,
        onTap: _editTribalName,
      ),
      profileSwitchRow(
        '是否原住民',
        _user?.isIndigenous ?? false,
        locked: true,
        lockedHint: '已設定，如需更正請聯繫管理員',
        onChanged: (_) {},
      ),
      profileSettingRow(
        '部落',
        _user?.tribeName ?? '尚未設定',
        editable: !identityLocked,
        onTap: identityLocked ? null : _editTribe,
      ),
      profileSettingRow(
        '電子信箱',
        _user?.email ?? 'apyang@truku.org',
        editable: false,
      ),
    ]);
  }

  Widget _buildAppSettingsSection({required bool seniorMode}) {
    return profileSection('PUSU · App 設定', [
      profileSwitchRow(
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
    return profileSection(
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
                        fontSize: seniorMode
                            ? AppTypography.headline
                            : AppTypography.bodyLarge,
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
}
