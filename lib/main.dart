import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/constants/app_colors.dart';
import 'firebase_options.dart';
import 'screens/auth/login_screen.dart';
import 'screens/community/community_screen.dart';
import 'screens/culture/culture_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/learn/learn_screen.dart';
import 'screens/plaza/event_detail_screen.dart';
import 'screens/plaza/events_screen.dart';
import 'screens/plaza/plaza_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/shop/shop_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'services/fcm_service.dart';
import 'services/user_service.dart';
import 'shared/widgets/truku_bottom_tab.dart';

final navigatorKey = GlobalKey<NavigatorState>();

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
    navigatorKey.currentState?.push(
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
  int _currentIndex = 0;
  bool _showProfile = false;
  String? _displayName;

  @override
  void initState() {
    super.initState();
    _fetchDisplayName();
  }

  Future<void> _fetchDisplayName() async {
    try {
      final user = await UserService.fetchMe();
      if (mounted) setState(() => _displayName = user.displayName);
    } catch (e, st) {
      debugPrint('Failed to fetch displayName: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  void _navigate(int index) => setState(() {
    _currentIndex = index;
    _showProfile = false;
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 主內容（6 個分頁）
          IndexedStack(
            index: _currentIndex,
            children: [
              HomeScreen(
                displayName: _displayName,
                onShowProfile: () => setState(() => _showProfile = true),
                onNavigateToTab: _navigate,
              ),
              const LearnScreen(),
              const CultureScreen(),
              const CommunityScreen(),
              const PlazaScreen(),
              const EventsScreen(),
            ],
          ),

          // ProfileScreen overlay
          if (_showProfile)
            Positioned.fill(
              child: ProfileScreen(
                onClose: () {
                  setState(() => _showProfile = false);
                  _fetchDisplayName();
                },
              ),
            ),
        ],
      ),
      bottomNavigationBar: _showProfile
          ? null
          : TrukuBottomTab(currentIndex: _currentIndex, onTap: _navigate),
    );
  }
}
