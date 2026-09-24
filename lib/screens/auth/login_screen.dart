import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../services/account_lock_controller.dart';
import '../../services/auth_service.dart';
import '../../services/fcm_service.dart';
import '../../services/session_service.dart';
import '../../services/terms_service.dart';
import '../../services/user_service.dart';
import '../../shared/widgets/truku_painters.dart';
import '../../shared/widgets/truku_widgets.dart';
import '../../core/constants/app_typography.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  /// 登入進行中的方式（'google'／'apple'），null 表示閒置。
  String? _loggingProvider;

  // Apple 登入目前只接 iOS 原生；Android／Web 需另設 Service ID，先不顯示。
  bool get _showApple =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  Future<void> _handleLogin(
    String provider,
    Future<LoginResult> Function() signIn,
  ) async {
    if (_loggingProvider != null) return;
    setState(() => _loggingProvider = provider);
    try {
      final result = await signIn();
      if (!mounted) return;
      // 非 active 帳號的 token 打一般 API 都會被狀態閘擋下，不能照常進 App。
      if (result.isPendingDeletion) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/account-pending',
          (_) => false,
          arguments: result.purgeAt,
        );
        return;
      }
      // 鎖定帳號照常進 App，只是切到唯讀模式（寫入端點會回 403 ACCOUNT_LOCKED）。
      accountLockController.setLocked(result.isLocked);
      if (!result.isActive && !result.isLocked) {
        await SessionService.signOut(unregisterDevice: false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('此帳號目前無法使用，如有疑問請聯絡我們')),
        );
        return;
      }
      // 登入成功才上傳 FCM token（需 JWT）。失敗不阻斷進首頁，故獨立 try/catch。
      try {
        await FcmService.registerDevice();
      } catch (_) {}
      if (!mounted) return;
      final user = await UserService.fetchMe();
      if (!mounted) return;
      final profileCompleted = user.profileCompleted;
      var allConsented = true;
      if (profileCompleted) {
        try {
          final status = await TermsService.fetchStatus();
          allConsented = status.allConsented;
        } catch (e) {
          debugPrint('LoginScreen: fetchStatus 失敗，略過同意條款檢查：$e');
        }
      }
      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        !profileCompleted
            ? '/complete-profile'
            : (!allConsented ? '/terms-consent' : '/home'),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('登入發生未預期錯誤：$e')));
    } finally {
      if (mounted) setState(() => _loggingProvider = null);
    }
  }

  Widget _loadingIcon() => const SizedBox(
    width: 18,
    height: 18,
    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // 漸層背景：midnight → primaryDeep → primary
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.midnight,
                    AppColors.primaryDeep,
                    AppColors.primary,
                  ],
                  stops: [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),

          // 織紋紋理
          Positioned.fill(
            child: CustomPaint(
              painter: TrukuWeavePainter(color: AppColors.gold, opacity: 0.12),
            ),
          ),

          // 山脈剪影（底部）
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 200,
            child: Opacity(
              opacity: 0.7,
              child: CustomPaint(
                painter: TrukuMountainsPainter(
                  color: const Color(0xFF0E0604),
                  opacity: 0.8,
                ),
              ),
            ),
          ),

          // 主要內容
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Logo 區
                          _buildLogoSection(),
                          const SizedBox(height: 48),

                          // 表單區
                          _buildFormSection(),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoSection() {
    return Column(
      children: [
        // Logo 框
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            border: Border.all(
              color: AppColors.gold.withValues(alpha: 0.55),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.all(20),
          child: Image.asset(
            'assets/icon/logo.png',
            color: AppColors.gold,
            colorBlendMode: BlendMode.srcIn,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Kari Truku · Lnglungan',
          style: AppTypography.latin(
            fontStyle: FontStyle.italic,
            fontSize: AppTypography.body,
            color: AppColors.gold,
            letterSpacing: 2.5,
          ),
        ),
        const SizedBox(height: 10),
        const TrukuChain(count: 5, size: 8, color: AppColors.gold, gap: 5),
      ],
    );
  }

  Widget _buildFormSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 問候語
        Text(
          'MHUWAY SU · 歡迎回來',
          textAlign: TextAlign.center,
          style: AppTypography.latin(
            fontStyle: FontStyle.italic,
            fontSize: AppTypography.caption,
            color: AppColors.gold,
            letterSpacing: 3.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '登入，繼續說我們的話',
          textAlign: TextAlign.center,
          style: AppTypography.serif(
            fontSize: AppTypography.title,
            fontWeight: FontWeight.w600,
            color: AppColors.creamLight,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 32),

        // 第三方登入
        Row(
          children: [
            if (_showApple) ...[
              _buildSocialButton(
                icon: _loggingProvider == 'apple'
                    ? _loadingIcon()
                    : const Icon(
                        Icons.apple,
                        color: AppColors.creamLight,
                        size: 20,
                      ),
                label: 'Apple',
                onTap: _loggingProvider != null
                    ? null
                    : () => _handleLogin('apple', AuthService.signInWithApple),
              ),
              const SizedBox(width: 10),
            ],
            _buildSocialButton(
              icon: _loggingProvider == 'google'
                  ? _loadingIcon()
                  : const Icon(
                      Icons.g_mobiledata_rounded,
                      color: AppColors.creamLight,
                      size: 24,
                    ),
              label: 'Google',
              onTap: _loggingProvider != null
                  ? null
                  : () => _handleLogin('google', AuthService.signInWithGoogle),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSocialButton({
    required Widget icon,
    required String label,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.creamLight.withValues(alpha: 0.05),
            border: Border.all(color: AppColors.cream.withValues(alpha: 0.18)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon,
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: AppTypography.micro,
                  color: AppColors.cream.withValues(alpha: 0.8),
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
