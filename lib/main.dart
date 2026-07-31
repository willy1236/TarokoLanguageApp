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
import 'screens/plaza/events_screen.dart';
import 'screens/plaza/forum_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/shop/shop_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'services/checkin_service.dart';
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
  int _currentIndex = 0;
  bool _showProfile = false;
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
    } on CheckinFeatureUnavailableException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('功能尚未開放')),
      );
    } on CheckinApiException catch (e) {
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
                millet: _millet,
                checkedInToday: _checkedInToday,
                checkinStreak: _checkinStreak,
                onCheckin: _checkin,
                onShowProfile: () => setState(() => _showProfile = true),
                onNavigateToTab: _navigate,
              ),
              const LearnScreen(),
              const CultureScreen(),
              const CommunityScreen(),
              const ForumScreen(),
              const EventsScreen(),
            ],
          ),

          // ProfileScreen overlay
          if (_showProfile)
            Positioned.fill(
              child: ProfileScreen(
                onClose: () {
                  setState(() => _showProfile = false);
                  _fetchUserSummary();
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
