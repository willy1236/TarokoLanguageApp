import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../models/user_model.dart';
import '../../services/account_lock_controller.dart';
import '../../services/account_service.dart';
import '../../services/fcm_service.dart';
import '../../services/session_service.dart';
import '../../services/terms_service.dart';
import '../../services/user_service.dart';
import '../auth/entry_route.dart';
import '../../shared/widgets/truku_painters.dart';
import '../../shared/widgets/truku_widgets.dart';
import '../../core/constants/app_typography.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  /// JWT 已過期、續期時連不上：停在這頁顯示重試，不導去登入頁。
  bool _offline = false;

  /// 按了重試、還在等結果。
  bool _retrying = false;

  bool get _showRetryArea => _offline || _retrying;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) _start();
    });
  }

  void _retry() {
    setState(() {
      _offline = false;
      _retrying = true;
    });
    _start();
  }

  /// 還原登入並決定第一頁。只有 [RestoreResult.offline] 會留在這頁等重試。
  Future<void> _start() async {
    final restored = await SessionService.restore();
    if (!mounted) return;
    switch (restored) {
      case RestoreResult.offline:
        setState(() {
          _offline = true;
          _retrying = false;
        });
        return;
      case RestoreResult.loggedOut:
        Navigator.pushReplacementNamed(context, '/login');
        return;
      case RestoreResult.loggedIn:
        await _enter();
    }
  }

  /// 已登入：查帳號狀態、使用者資料與條款，導去該去的第一頁。
  Future<void> _enter() async {
    // /me 沒有帳號狀態欄位，鎖定（唯讀）要另查 status；與 /me 並行，
    // 查不到（離線）就維持非唯讀，寫入時由 403 ACCOUNT_LOCKED 補救。
    final lockCheck = AccountService.fetchStatus()
        .then((s) => accountLockController.setLocked(s.isLocked))
        .catchError((Object e) {
          debugPrint('SplashScreen: 帳號狀態查詢失敗，略過唯讀檢查：$e');
        });
    // 離線等原因查不到使用者資料時，不擋既有使用者進首頁。
    UserModel? user;
    try {
      user = await UserService.fetchMe();
    } on ApiException catch (e) {
      // 刪除中／已刪除帳號：ApiClient 已導去重新啟用畫面或登入頁，這裡不可再導頁蓋掉。
      // 未同意條款：ApiClient 已導去同意畫面，同意後由該畫面接續導頁，這裡再導會疊兩層。
      if (e.isAccountPendingDeletion ||
          e.isAccountPurged ||
          e.isConsentRequired) {
        return;
      }
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
    final route = entryRouteFor(user, allConsented: allConsented);
    Navigator.pushReplacementNamed(context, route);
    // 冷啟動由通知帶出的深連結導頁必須排在這裡之後，
    // 否則會被上面這行 pushReplacementNamed 蓋掉（見 fcm_service.dart）。
    // 補填出生日期不能跳過，深連結等補填完進首頁時由該頁接續。
    if (route != '/birth-date') FcmService.consumePendingInitialMessage();
  }

  Widget _buildOffline() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '無法連線，請檢查網路',
          textAlign: TextAlign.center,
          style: AppTypography.bodyLargeStyle(color: AppColors.creamLight),
        ),
        const SizedBox(height: 14),
        OutlinedButton(
          onPressed: _retry,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.gold,
            side: const BorderSide(color: AppColors.gold),
            minimumSize: const Size(140, 48),
          ),
          child: Text(
            '重試',
            style: AppTypography.bodyStyle(color: AppColors.gold),
          ),
        ),
      ],
    );
  }

  Widget _buildRetrying() {
    return const SizedBox(
      height: 48,
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.gold,
          ),
        ),
      ),
    );
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

          // 中央 logo 區（top: 32%）。顯示重試區時上移到 22%，騰出下方空間，
          // 320×568 這類小螢幕才放得下。
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            top: size.height * (_showRetryArea ? 0.22 : 0.32),
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
                // 離線重試接在 logo 下方跟著內容排，小螢幕、字體放大時也不會壓到上面。
                if (_showRetryArea) ...[
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _retrying ? _buildRetrying() : _buildOffline(),
                  ),
                ],
              ],
            ),
          ),

          // 底部 tagline（bottom: 70）。重試區會往下長到這裡，顯示時先收起。
          if (!_showRetryArea)
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
