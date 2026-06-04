import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/constants/app_colors.dart';
import 'screens/auth/login_screen.dart';
import 'screens/community/community_screen.dart';
import 'screens/culture/culture_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/learn/learn_screen.dart';
import 'screens/plaza/events_screen.dart';
import 'screens/plaza/plaza_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'shared/widgets/truku_bottom_tab.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const KariTrukuApp());
}

class KariTrukuApp extends StatelessWidget {
  const KariTrukuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
            bodyMedium: TextStyle(color: AppColors.creamLight),
          ),
        ),
      ),
      initialRoute: '/splash',
      routes: {
        '/splash': (_) => const SplashScreen(),
        '/login': (_) => const LoginScreen(),
        '/home': (_) => const MainContainer(),
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
              HomeScreen(onShowProfile: () => setState(() => _showProfile = true)),
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
              child: Stack(
                children: [
                  Material(
                    color: AppColors.surface,
                    child: const _ProfileTab(),
                  ),
                  Positioned(
                    top: 56,
                    left: 16,
                    child: GestureDetector(
                      onTap: () => setState(() => _showProfile = false),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                        child: const Icon(Icons.chevron_left, color: AppColors.creamLight),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      bottomNavigationBar: _showProfile
          ? null
          : TrukuBottomTab(
              currentIndex: _currentIndex,
              onTap: _navigate,
            ),
    );
  }
}


// ─── 個人中心（Phase 7 完整重寫，目前保留舊版暗色樣式）──────────────────────

class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 80, 16, 40),
      children: [
        const Center(
          child: Column(children: [
            CircleAvatar(radius: 45, backgroundImage: NetworkImage('https://picsum.photos/id/64/200/200')),
            SizedBox(height: 15),
            Text('Apyang Imiq', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            Text('LEVEL 2 • 太魯閣族語學習者', style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          ]),
        ),
        const SizedBox(height: 35),
        Row(children: [
          _statBox('12', '連續學習', AppColors.orangeLight),
          const SizedBox(width: 12),
          _statBox('120', '已學單字', AppColors.blueLight),
          const SizedBox(width: 12),
          _statBox('05', '社群貢獻', AppColors.greenLight),
        ]),
        const SizedBox(height: 35),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(children: [
            _menuItem(Icons.access_time_filled_rounded, '我的學習進度', AppColors.blue),
            _divider(),
            _menuItem(Icons.star_rounded, '我的收藏', AppColors.amber),
            _divider(),
            _menuItem(Icons.military_tech_rounded, '我參與的活動', AppColors.purple),
            _divider(),
            _menuItem(Icons.settings_rounded, '帳號設定', Colors.grey),
            _divider(),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: AppColors.danger, size: 22),
              title: const Text('登出帳號 Logout', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.danger)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              onTap: () => Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false),
            ),
          ]),
        ),
      ],
    );
  }

  Widget _statBox(String v, String l, Color c) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(children: [
          Text(v, style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: c)),
          const SizedBox(height: 6),
          Text(l, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }

  Widget _menuItem(IconData i, String l, Color ic) {
    return ListTile(
      leading: Icon(i, color: ic, size: 22),
      title: Text(l, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white12, size: 18),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
    );
  }

  Widget _divider() => Divider(height: 1, color: Colors.white.withValues(alpha: 0.03), indent: 20, endIndent: 20);
}
