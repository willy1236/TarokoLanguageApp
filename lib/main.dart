import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/constants/app_colors.dart';
import 'core/constants/app_typography.dart';
import 'firebase_options.dart';
import 'screens/auth/complete_profile_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/backpack/backpack_screen.dart';
import 'screens/friends/friends_list_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/learn/learn_culture_screen.dart';
import 'screens/events/event_detail_screen.dart';
import 'screens/community/video_call_screen.dart';
import 'screens/forum/forum_detail_screen.dart';
import 'screens/friends/incoming_call_screen.dart';
import 'screens/plaza/plaza_event_screen.dart';
import 'screens/profile/profile_video_screen.dart';
import 'screens/shop/shop_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/terms/terms_consent_screen.dart';
import 'core/network/api_client.dart';
import 'models/shop_item.dart';
import 'models/user_model.dart';
import 'services/checkin_service.dart';
import 'services/fcm_service.dart';
import 'services/senior_mode_controller.dart';
import 'services/shop_service.dart';
import 'services/user_service.dart';
import 'services/video_call_service.dart';
import 'shared/widgets/truku_bottom_tab.dart';

final navigatorKey = GlobalKey<NavigatorState>();
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // 點提醒/取消通知 → 導到該活動詳情頁（用全域 navigatorKey，不依賴當下 context）。
  FcmService.onReminderTapped = (eventId) {
    if (eventId == null) return;
    final navState = navigatorKey.currentState;
    if (navState == null) {
      debugPrint('FcmService.onReminderTapped: navigatorKey 尚未掛上，導頁被忽略');
      return;
    }
    navState.push(
      MaterialPageRoute(builder: (_) => EventDetailScreen(eventId: eventId)),
    );
  };
  // 冷啟動/背景點擊 video_matched 通知 → 查目前 active session 並導到通話畫面。
  // FCM payload 只有 session_id/channel，權威資料一律重新查詢（見 fcm_service.dart
  // 檔頭註解），避免跟輪詢路徑組出不一致的 VideoSession。
  FcmService.onVideoMatchedColdStart = (sessionId, channel) async {
    if (sessionId == null) return;
    try {
      final session = await VideoCallService.fetchCurrentSession();
      if (session == null || session.id != sessionId) return;
      final navState = navigatorKey.currentState;
      if (navState == null) {
        debugPrint('FcmService.onVideoMatchedColdStart: navigatorKey 尚未掛上，導頁被忽略');
        return;
      }
      navState.push(
        MaterialPageRoute(builder: (_) => VideoCallScreen(session: session)),
      );
    } catch (e) {
      debugPrint('FcmService.onVideoMatchedColdStart: 查詢 session 失敗：$e');
    }
  };
  // 點論壇回覆通知 → 導到該貼文詳情頁。
  FcmService.onForumReplyTapped = (postId) {
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => ForumDetailScreen(postId: postId)),
    );
  };
  // 收到好友定向來電（前景推播、或背景點擊通知開啟）→ 導到響鈴畫面。
  FcmService.onFriendCallIncoming = (call) {
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => IncomingCallScreen(call: call)),
    );
  };
  // FCM 掛載（要權限、掛前景/點擊監聽）。失敗不阻斷 App 啟動；token 上傳待登入後。
  try {
    await FcmService.init();
  } catch (e) {
    debugPrint('FcmService.init 失敗（不影響 App 啟動）：$e');
  }

  // 還原精簡模式開關；失敗不阻斷啟動，維持預設關閉。
  try {
    await seniorModeController.load();
  } catch (e) {
    debugPrint('SeniorModeController.load 失敗（不影響 App 啟動）：$e');
  }

  runApp(const KariTrukuApp());
}

class KariTrukuApp extends StatelessWidget {
  const KariTrukuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: seniorModeController,
      builder: (context, _) => _buildApp(context),
    );
  }

  Widget _buildApp(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: scaffoldMessengerKey,
      title: 'KARI TRUKU',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        primaryColor: AppColors.primary,
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primary,
          secondary: AppColors.surfaceVariant,
          surface: AppColors.surface,
        ),
        textTheme: GoogleFonts.notoSansTcTextTheme(
          const TextTheme(
            bodySmall: TextStyle(
              fontSize: AppTypography.caption,
              color: AppColors.creamLight,
            ),
            bodyMedium: TextStyle(
              fontSize: AppTypography.body,
              color: AppColors.creamLight,
            ),
            bodyLarge: TextStyle(
              fontSize: AppTypography.bodyLarge,
              color: AppColors.creamLight,
            ),
            titleSmall: TextStyle(
              fontSize: AppTypography.subtitle,
              color: AppColors.creamLight,
            ),
            titleMedium: TextStyle(
              fontSize: AppTypography.title,
              color: AppColors.creamLight,
            ),
            titleLarge: TextStyle(
              fontSize: AppTypography.headline,
              color: AppColors.creamLight,
            ),
          ),
        ),
      ),
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        final seniorMode = seniorModeController.enabled;
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: mediaQuery.textScaler.clamp(
              minScaleFactor: 1.0,
              maxScaleFactor: seniorMode ? 1.5 : 1.15,
            ),
          ),
          child: child!,
        );
      },
      initialRoute: '/splash',
      routes: {
        '/splash': (_) => const SplashScreen(),
        '/login': (_) => const LoginScreen(),
        '/complete-profile': (_) => const CompleteProfileScreen(),
        '/terms-consent': (_) => const TermsConsentScreen(),
        '/home': (_) => const MainContainer(),
        '/shop': (_) => const ShopScreen(),
        '/backpack': (_) => const BackpackScreen(),
      },
    );
  }
}

// ─── App Shell ─────────────────────────────────────────────────────────────

class MainContainer extends StatefulWidget {
  const MainContainer({super.key});

  @override
  State<MainContainer> createState() => _MainContainerState();
}

class _MainContainerState extends State<MainContainer> {
  // 分頁 index 需與 IndexedStack、TrukuBottomTab._keys、home_screen 的 _modeTabIndex 一致。
  static const int _learnCultureIndex = 1;
  static const int _plazaEventIndex = 2;
  static const int _profileVideoIndex = 4;

  int _currentIndex = 0;
  // 精簡模式首頁省略「族語學習」卡，學習影音分頁預設改開文化影音（1）。
  late bool _seniorMode = seniorModeController.enabled;
  late int _learnCultureSubTab = _defaultLearnCultureSubTab(_seniorMode);
  int _plazaEventSubTab = 0;
  int _profileVideoSubTab = 0;
  String? _displayName;
  int? _millet;
  String? _avatarId;
  String? _avatarUrl;
  Map<String, ShopItem> _itemCatalogById = const {};
  bool _checkedInToday = false;
  int _checkinStreak = 0;
  int _weeklyCheckinCount = 0;
  bool _weeklyBonusEarned = false;

  @override
  void initState() {
    super.initState();
    _fetchUserSummary();
    _loadItemCatalog();
    _loadCheckinStatus();
    seniorModeController.addListener(_onSeniorModeChanged);
    UserService.userNotifier.addListener(_onUserChanged);
  }

  @override
  void dispose() {
    seniorModeController.removeListener(_onSeniorModeChanged);
    UserService.userNotifier.removeListener(_onUserChanged);
    super.dispose();
  }

  static int _defaultLearnCultureSubTab(bool seniorMode) => seniorMode ? 1 : 0;

  // 只在精簡模式真的切換時重設子分頁，避免無關 notify 蓋掉使用者手動切的分頁。
  void _onSeniorModeChanged() {
    final enabled = seniorModeController.enabled;
    if (enabled == _seniorMode) return;
    setState(() {
      _seniorMode = enabled;
      _learnCultureSubTab = _defaultLearnCultureSubTab(enabled);
    });
  }

  // 個人頁改名、換頭像、商店購買等都會寫回 UserService 快取，這裡同步刷新首頁頂部。
  void _onUserChanged() {
    final user = UserService.userNotifier.value;
    if (user == null || !mounted) return;
    _applyUserSummary(user);
  }

  void _applyUserSummary(UserModel user) {
    setState(() {
      _displayName = user.displayName;
      _millet = user.millet;
      _avatarId = user.avatarId;
      _avatarUrl = user.avatarUrl;
    });
  }

  // 簽到只回傳部分欄位，合併回快取讓其他畫面讀到的小米數一致。
  void _syncCheckinToCache(CheckinStatus status) {
    final cached = UserService.cachedUser;
    if (cached == null) return;
    UserService.cacheUser(
      cached.copyWith(
        millet: status.millet,
        checkedInToday: status.checkedInToday,
        checkinStreak: status.checkinStreak,
      ),
    );
  }

  Future<void> _fetchUserSummary() async {
    try {
      final user = await UserService.fetchMe();
      if (mounted) _applyUserSummary(user);
    } catch (e, st) {
      debugPrint('Failed to fetch user summary: $e');
      debugPrintStack(stackTrace: st);
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
      debugPrint('_MainContainerState._loadItemCatalog failed: $e');
    }
  }

  Future<void> _loadCheckinStatus() async {
    try {
      final status = await CheckinService.fetchStatus();
      if (!mounted) return;
      _syncCheckinToCache(status);
      setState(() {
        _checkedInToday = status.checkedInToday;
        _checkinStreak = status.checkinStreak;
        _millet = status.millet;
        _weeklyCheckinCount = status.weeklyCheckinCount;
        _weeklyBonusEarned = status.weeklyBonusEarned;
      });
    } catch (e) {
      // 功能尚未開放或發生錯誤：維持現狀，簽到按鈕保持預設（可點）樣式。
      debugPrint('Failed to load checkin status: $e');
    }
  }

  Future<void> _checkin() async {
    try {
      final status = await CheckinService.checkin();
      if (!mounted) return;
      _syncCheckinToCache(status);
      setState(() {
        _checkedInToday = status.checkedInToday;
        _checkinStreak = status.checkinStreak;
        _millet = status.millet;
        _weeklyCheckinCount = status.weeklyCheckinCount;
        _weeklyBonusEarned = status.weeklyBonusEarned;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status.weeklyBonusEarned
                ? '簽到成功，+50 小米・週全勤再 +50！'
                : '簽到成功，+50 小米',
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'ALREADY_CHECKED_IN') {
        setState(() => _checkedInToday = true);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('今日已簽到')));
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('簽到失敗，請稍後再試')));
    }
  }

  void _navigate(int index, {int? subTab}) => setState(() {
    _currentIndex = index;
    if (subTab != null) {
      if (index == _learnCultureIndex) _learnCultureSubTab = subTab;
      if (index == _plazaEventIndex) _plazaEventSubTab = subTab;
      if (index == _profileVideoIndex) _profileVideoSubTab = subTab;
    }
  });

  Future<void> _handleBack() async {
    if (_currentIndex != 0) {
      _navigate(0);
      return;
    }
    await _confirmExit();
  }

  Future<void> _confirmExit() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('離開'),
        content: const Text('確定要關閉 App 嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('離開'),
          ),
        ],
      ),
    );
    if (shouldExit == true) {
      await SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: seniorModeController,
      builder: (context, _) {
        final seniorMode = seniorModeController.enabled;
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            _handleBack();
          },
          child: Scaffold(
            extendBody: false,
            body: IndexedStack(
              index: _currentIndex,
              children: [
                HomeScreen(
                  displayName: _displayName,
                  millet: _millet,
                  avatarId: _avatarId,
                  avatarUrl: _avatarUrl,
                  itemCatalogById: _itemCatalogById,
                  checkedInToday: _checkedInToday,
                  checkinStreak: _checkinStreak,
                  weeklyCheckinCount: _weeklyCheckinCount,
                  weeklyBonusEarned: _weeklyBonusEarned,
                  onCheckin: _checkin,
                  onShowProfile: () => _navigate(_profileVideoIndex, subTab: 0),
                  onNavigateToTab: _navigate,
                ),
                LearnCultureScreen(
                  key: ValueKey('learn_culture_$_learnCultureSubTab'),
                  initialTabIndex: _learnCultureSubTab,
                ),
                PlazaEventScreen(
                  key: ValueKey('plaza_event_$_plazaEventSubTab'),
                  initialTabIndex: _plazaEventSubTab,
                ),
                const FriendsListScreen(showBackButton: false),
                ProfileVideoScreen(
                  key: ValueKey('profile_video_$_profileVideoSubTab'),
                  initialTabIndex: _profileVideoSubTab,
                ),
              ],
            ),
            bottomNavigationBar: TrukuBottomTab(
              currentIndex: _currentIndex,
              onTap: _navigate,
              seniorMode: seniorMode,
            ),
          ),
        );
      },
    );
  }
}
