import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/constants/app_colors.dart';
import 'firebase_options.dart';
import 'screens/auth/login_screen.dart';
import 'screens/backpack/backpack_screen.dart';
import 'screens/community/community_screen.dart';
import 'screens/culture/culture_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/learn/learn_screen.dart';
import 'screens/events/event_detail_screen.dart';
import 'screens/events/events_screen.dart';
import 'screens/plaza/plaza_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/shop/shop_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'core/network/api_client.dart';
import 'services/checkin_service.dart';
import 'services/fcm_service.dart';
import 'services/user_service.dart';
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
  // FCM 掛載（要權限、掛前景/點擊監聽）。失敗不阻斷 App 啟動；token 上傳待登入後。
  try {
    await FcmService.init();
  } catch (e) {
    debugPrint('FcmService.init 失敗（不影響 App 啟動）：$e');
  }

  runApp(const KariTrukuApp());
}

class KariTrukuApp extends StatelessWidget {
  const KariTrukuApp({super.key});

  @override
  Widget build(BuildContext context) {
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
          const TextTheme(bodyMedium: TextStyle(color: AppColors.creamLight)),
        ),
      ),
      initialRoute: '/splash',
      routes: {
        '/splash': (_) => const SplashScreen(),
        '/login': (_) => const LoginScreen(),
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
  static const int _profileIndex = 6;

  int _currentIndex = 0;
  int _previousIndex = 0;
  String? _displayName;
  int? _millet;
  bool _checkedInToday = false;
  int _checkinStreak = 0;

  @override
  void initState() {
    super.initState();
    _fetchUserSummary();
    _loadCheckinStatus();
  }

  Future<void> _fetchUserSummary() async {
    try {
      final user = await UserService.fetchMe();
      if (mounted) {
        setState(() {
          _displayName = user.displayName;
          _millet = user.millet;
        });
      }
    } catch (e, st) {
      debugPrint('Failed to fetch user summary: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  Future<void> _loadCheckinStatus() async {
    try {
      final status = await CheckinService.fetchStatus();
      if (!mounted) return;
      setState(() {
        _checkedInToday = status.checkedInToday;
        _checkinStreak = status.checkinStreak;
        _millet = status.millet;
      });
    } catch (_) {
      // 功能尚未開放或發生錯誤：維持現狀，簽到按鈕保持預設（可點）樣式。
    }
  }

  Future<void> _checkin() async {
    try {
      final status = await CheckinService.checkin();
      if (!mounted) return;
      setState(() {
        _checkedInToday = status.checkedInToday;
        _checkinStreak = status.checkinStreak;
        _millet = status.millet;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('簽到成功，+50 小米')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'ALREADY_CHECKED_IN') {
        setState(() => _checkedInToday = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('今日已簽到')),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('簽到失敗，請稍後再試')),
      );
    }
  }

  void _navigate(int index) => setState(() {
    _currentIndex = index;
  });

  void _openProfile() => setState(() {
    _previousIndex = _currentIndex;
    _currentIndex = _profileIndex;
  });

  void _closeProfile() {
    setState(() => _currentIndex = _previousIndex);
    _fetchUserSummary();
  }

  Future<void> _handleBack() async {
    if (_currentIndex == _profileIndex) {
      _closeProfile();
      return;
    }
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        extendBody: true,
        body: IndexedStack(
          index: _currentIndex,
          children: [
            HomeScreen(
              displayName: _displayName,
              millet: _millet,
              checkedInToday: _checkedInToday,
              checkinStreak: _checkinStreak,
              onCheckin: _checkin,
              onShowProfile: _openProfile,
              onNavigateToTab: _navigate,
            ),
            const LearnScreen(),
            const CultureScreen(),
            const CommunityScreen(),
            const PlazaScreen(),
            const EventsScreen(),
            ProfileScreen(onClose: _closeProfile),
          ],
        ),
        bottomNavigationBar: _currentIndex == _profileIndex
            ? null
            : TrukuBottomTab(currentIndex: _currentIndex, onTap: _navigate),
      ),
    );
  }
}
