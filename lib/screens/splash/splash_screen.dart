import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../services/account_lock_controller.dart';
import '../../services/account_service.dart';
import '../../services/auth_service.dart';
import '../../services/fcm_service.dart';
import '../../services/terms_service.dart';
import '../../services/user_service.dart';
import '../../shared/widgets/truku_painters.dart';
import '../../shared/widgets/truku_widgets.dart';
import '../../core/constants/app_typography.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
    Future.delayed(const Duration(milliseconds: 2500), () async {
      if (!mounted) return;
      final loggedIn = await AuthService.isLoggedIn();
      if (!mounted) return;
      if (!loggedIn) {
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }
      // /me 沒有帳號狀態欄位，鎖定（唯讀）要另查 status；與 /me 並行，
      // 查不到（離線）就維持非唯讀，寫入時由 403 ACCOUNT_LOCKED 補救。
      final lockCheck = AccountService.fetchStatus()
          .then((s) => accountLockController.setLocked(s.isLocked))
          .catchError((Object e) {
            debugPrint('SplashScreen: 帳號狀態查詢失敗，略過唯讀檢查：$e');
          });
      // 離線等原因查不到 profile_completed 時，不擋既有使用者進首頁。
      var profileCompleted = true;
      try {
        final user = await UserService.fetchMe();
        profileCompleted = user.profileCompleted;
      } on ApiException catch (e) {
        // 刪除中／已刪除帳號：ApiClient 已導去重新啟用畫面或登入頁，這裡不可再導頁蓋掉。
        if (e.isAccountPendingDeletion || e.isAccountPurged) return;
        debugPrint('SplashScreen: fetchMe 失敗，略過完善資料檢查：$e');
      } catch (e) {
        debugPrint('SplashScreen: fetchMe 失敗，略過完善資料檢查：$e');
      }
      // 同理，離線等原因查不到同意狀態時，不擋既有使用者進首頁。
      var allConsented = true;
      try {
        final status = await TermsService.fetchStatus();
        allConsented = status.allConsented;
      } catch (e) {
        debugPrint('SplashScreen: fetchStatus 失敗，略過同意條款檢查：$e');
      }
      await lockCheck;
      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        !profileCompleted
            ? '/complete-profile'
            : (!allConsented ? '/terms-consent' : '/home'),
      );
      // 冷啟動由通知帶出的深連結導頁必須排在這裡之後，
      // 否則會被上面這行 pushReplacementNamed 蓋掉（見 fcm_service.dart）。
      FcmService.consumePendingInitialMessage();
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
                colors: [
                  AppColors.midnight,
                  AppColors.primaryDeep,
                  AppColors.primary,
                ],
              ),
            ),
          ),

          // 織紋紋理
          Positioned.fill(
            child: Opacity(
              opacity: 0.18,
              child: CustomPaint(
                painter: const TrukuWeavePainter(
                  color: AppColors.gold,
                  opacity: 1.0,
                ),
              ),
            ),
          ),

          // 山脈剪影（後層）
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Opacity(
              opacity: 0.85,
              child: CustomPaint(
                size: Size(size.width, 180),
                painter: const TrukuMountainsPainter(
                  color: Color(0xFF0E0604),
                  opacity: 0.7,
                ),
              ),
            ),
          ),

          // 山脈剪影（前層）
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Opacity(
              opacity: 0.6,
              child: CustomPaint(
                size: Size(size.width, 120),
                painter: const TrukuMountainsPainter(
                  color: Color(0xFF0E0604),
                  opacity: 0.5,
                ),
              ),
            ),
          ),

          // 頂部菱形鏈（top: 90）
          const Positioned(
            top: 90,
            left: 0,
            right: 0,
            child: Center(
              child: TrukuChain(
                count: 9,
                size: 10,
                color: AppColors.gold,
                gap: 6,
              ),
            ),
          ),

          // 中央 logo 區（top: 32%）
          Positioned(
            top: size.height * 0.32,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 220,
                      height: 220,
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
                    Image.asset(
                      'assets/icon/logo.png',
                      width: 120,
                      height: 120,
                      color: AppColors.cream,
                      colorBlendMode: BlendMode.srcIn,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'Kari Truku · Lnglungan',
                  style: AppTypography.latin(
                    fontStyle: FontStyle.italic,
                    fontSize: AppTypography.bodyLarge,
                    color: AppColors.gold,
                    letterSpacing: 3.2,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 8),
                const TrukuChain(
                  count: 5,
                  size: 8,
                  color: AppColors.gold,
                  gap: 5,
                ),
              ],
            ),
          ),

          // 底部 tagline（bottom: 70）
          Positioned(
            bottom: 70,
            left: 0,
            right: 0,
            child: Text(
              '說我們的話 · 走我們的山',
              textAlign: TextAlign.center,
              style: AppTypography.sans(
                fontSize: AppTypography.body,
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
