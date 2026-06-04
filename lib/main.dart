import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/constants/app_colors.dart';
import 'screens/auth/login_screen.dart';
import 'screens/learn/learn_screen.dart';
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
              _OldHomeTab(onNavigate: _navigate),
              const LearnScreen(),
              const _PlaceholderTab('影音 · Culture', AppColors.midnight),
              const _PlaceholderTab('視訊 · Video Call', AppColors.midnight),
              const _PlaceholderTab('廣場 · Plaza', AppColors.creamLight),
              const _PlaceholderTab('活動 · Events', AppColors.creamLight),
            ],
          ),

          // Avatar 按鈕（首頁分頁、無 profile overlay 時顯示）
          if (_currentIndex == 0 && !_showProfile)
            Positioned(
              top: 56,
              right: 16,
              child: GestureDetector(
                onTap: () => setState(() => _showProfile = true),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary,
                    border: Border.all(color: AppColors.gold, width: 2),
                  ),
                  child: const Icon(Icons.person, color: AppColors.creamLight),
                ),
              ),
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

// ─── 佔位分頁（Phase 2–6 逐步替換）──────────────────────────────────────────

class _PlaceholderTab extends StatelessWidget {
  final String label;
  final Color bg;
  const _PlaceholderTab(this.label, this.bg);

  @override
  Widget build(BuildContext context) {
    final textColor = bg == AppColors.creamLight ? AppColors.fog : AppColors.fog;
    return Container(
      color: bg,
      child: Center(
        child: Text(label, style: TextStyle(color: textColor, fontSize: 16)),
      ),
    );
  }
}

// ─── 舊版首頁（Phase 2 完整重寫）────────────────────────────────────────────

class _OldHomeTab extends StatelessWidget {
  final Function(int) onNavigate;
  const _OldHomeTab({required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            children: [
              Row(
                children: const [
                  CircleAvatar(radius: 28, backgroundImage: NetworkImage('https://picsum.photos/id/64/100/100')),
                  SizedBox(width: 15),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Mhuway su!', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 12)),
                      Text('Kating, 歡迎學習', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('每日學習進度', style: TextStyle(color: Colors.white70, fontSize: 11)),
                  Text('85%', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: const LinearProgressIndicator(value: 0.85, minHeight: 6, backgroundColor: Colors.white10),
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),
        const Text('族語學習路徑', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 15),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 15,
          mainAxisSpacing: 15,
          childAspectRatio: 1.5,
          children: [
            _quickCard('每日練習', Icons.book_rounded, AppColors.rose),
            _quickCard('檢定衝刺', Icons.verified_rounded, Colors.indigoAccent),
          ],
        ),
      ],
    );
  }

  Widget _quickCard(String t, IconData i, Color c) {
    return Container(
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.20)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [Icon(i, color: c, size: 28), const SizedBox(height: 8), Text(t, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))],
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
