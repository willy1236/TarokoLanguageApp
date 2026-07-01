import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../shared/widgets/truku_painters.dart';
import '../../shared/widgets/truku_widgets.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    Future.delayed(const Duration(milliseconds: 2500), () async {
      if (!mounted) return;
      final loggedIn = await AuthService.isLoggedIn();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, loggedIn ? '/home' : '/login');
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 漸層背景（midnight → primaryDeep → primary）
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.6, 1.0],
                colors: [AppColors.midnight, AppColors.primaryDeep, AppColors.primary],
              ),
            ),
          ),

          // 織紋紋理
          Positioned.fill(
            child: Opacity(
              opacity: 0.18,
              child: CustomPaint(
                painter: const TrukuWeavePainter(color: AppColors.gold, opacity: 1.0),
              ),
            ),
          ),

          // 山脈剪影（後層）
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Opacity(
              opacity: 0.85,
              child: CustomPaint(
                size: Size(size.width, 180),
                painter: const TrukuMountainsPainter(color: Color(0xFF0E0604), opacity: 0.7),
              ),
            ),
          ),

          // 山脈剪影（前層）
          Positioned(
            bottom: 30, left: 0, right: 0,
            child: Opacity(
              opacity: 0.6,
              child: CustomPaint(
                size: Size(size.width, 120),
                painter: const TrukuMountainsPainter(color: Color(0xFF0E0604), opacity: 0.5),
              ),
            ),
          ),

          // 頂部菱形鏈（top: 90）
          const Positioned(
            top: 90, left: 0, right: 0,
            child: Center(
              child: TrukuChain(count: 9, size: 10, color: AppColors.gold, gap: 6),
            ),
          ),

          // 中央 logo 區（top: 32%）
          Positioned(
            top: size.height * 0.32,
            left: 0, right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 220, height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.gold.withValues(alpha: 0.19),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.7],
                        ),
                      ),
                    ),
                    Icon(
                      Icons.language,
                      size: 120,
                      color: AppColors.gold.withValues(alpha: 0.9),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'Kari Truku · Lnglungan',
                  style: GoogleFonts.crimsonPro(
                    fontStyle: FontStyle.italic,
                    fontSize: 16,
                    color: AppColors.gold,
                    letterSpacing: 3.2,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 8),
                const TrukuChain(count: 5, size: 8, color: AppColors.gold, gap: 5),
              ],
            ),
          ),

          // 底部 tagline（bottom: 70）
          Positioned(
            bottom: 70, left: 0, right: 0,
            child: Text(
              '說我們的話 · 走我們的山',
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSansTc(
                fontSize: 13,
                color: AppColors.cream.withValues(alpha: 0.7),
                letterSpacing: 3.9,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
