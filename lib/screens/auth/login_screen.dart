import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../shared/widgets/truku_painters.dart';
import '../../shared/widgets/truku_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _accountController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _loggingIn = false;

  @override
  void dispose() {
    _accountController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() {
    Navigator.pushReplacementNamed(context, '/home');
  }

  Future<void> _handleGoogleLogin() async {
    if (_loggingIn) return;
    setState(() => _loggingIn = true);
    try {
      await AuthService.signInWithGoogle();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('登入發生未預期錯誤：$e')),
      );
    } finally {
      if (mounted) setState(() => _loggingIn = false);
    }
  }

  void _showSoon(String name) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$name 登入即將推出')),
    );
  }

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
              painter: TrukuWeavePainter(
                color: AppColors.gold,
                opacity: 0.12,
              ),
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
            child: Column(
              children: [
                // Logo 區（上半）
                const SizedBox(height: 56),
                _buildLogoSection(),

                // 彈性間距
                const Expanded(child: SizedBox()),

                // 表單區（下半）
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                  child: _buildFormSection(),
                ),
                const SizedBox(height: 52),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoSection() {
    return Column(
      children: [
        // Logo 框（暫以圖示代替圖片）
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
          child: const Icon(
            Icons.language_rounded,
            size: 52,
            color: AppColors.gold,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Kari Truku · Lnglungan',
          style: GoogleFonts.crimsonPro(
            fontStyle: FontStyle.italic,
            fontSize: 13,
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 問候語
        Text(
          'MHUWAY SU · 歡迎回來',
          style: GoogleFonts.crimsonPro(
            fontStyle: FontStyle.italic,
            fontSize: 11,
            color: AppColors.gold,
            letterSpacing: 3.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '登入，繼續說我們的話',
          style: GoogleFonts.notoSerifTc(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.creamLight,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 20),

        // 帳號輸入框
        _buildInputField(
          controller: _accountController,
          labelTriku: 'HANGAN · 帳號',
          hint: 'yudaw.bakan',
          prefixIcon: const Icon(Icons.person_outline_rounded, size: 17, color: AppColors.cream),
          isGold: true,
        ),
        const SizedBox(height: 12),

        // 密碼輸入框
        _buildInputField(
          controller: _passwordController,
          labelTriku: 'PASWAD · 密碼',
          hint: '••••••••',
          prefixIcon: const Icon(Icons.lock_outline_rounded, size: 17, color: AppColors.cream),
          obscureText: _obscurePassword,
          suffixIcon: GestureDetector(
            onTap: () => setState(() => _obscurePassword = !_obscurePassword),
            child: Icon(
              _obscurePassword
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
              size: 18,
              color: AppColors.cream.withValues(alpha: 0.7),
            ),
          ),
          isGold: false,
        ),
        const SizedBox(height: 10),

        // 忘記密碼
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: () {},
            child: Text(
              '忘記密碼？',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.cream.withValues(alpha: 0.7),
                letterSpacing: 0.6,
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),

        // 登入按鈕（帳密版本暫時保留，導向 /home）
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _handleLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.ink,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
              shadowColor: AppColors.gold.withValues(alpha: 0.25),
            ),
            child: Text(
              '登　入',
              style: GoogleFonts.notoSerifTc(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 4,
                color: AppColors.ink,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // OR 分隔
        Row(
          children: [
            Expanded(child: Divider(color: AppColors.cream.withValues(alpha: 0.2), height: 1)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                'OR',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.cream.withValues(alpha: 0.55),
                  letterSpacing: 2,
                ),
              ),
            ),
            Expanded(child: Divider(color: AppColors.cream.withValues(alpha: 0.2), height: 1)),
          ],
        ),
        const SizedBox(height: 16),

        // 第三方登入
        Row(
          children: [
            _buildSocialButton(
              icon: const Icon(Icons.apple, color: AppColors.creamLight, size: 20),
              label: 'Apple',
              onTap: () => _showSoon('Apple'),
            ),
            const SizedBox(width: 10),
            _buildSocialButton(
              icon: const TrukuDiamond(size: 18, color: AppColors.gold, filled: true, strokeWidth: 1.2),
              label: '部落帳號',
              onTap: () => _showSoon('部落帳號'),
            ),
            const SizedBox(width: 10),
            _buildSocialButton(
              icon: _loggingIn
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.gold,
                      ),
                    )
                  : const Icon(Icons.g_mobiledata_rounded, color: AppColors.creamLight, size: 24),
              label: 'Google',
              onTap: _loggingIn ? null : _handleGoogleLogin,
            ),
          ],
        ),
        const SizedBox(height: 20),

        // 註冊提示
        Center(
          child: GestureDetector(
            onTap: () {},
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.cream.withValues(alpha: 0.85),
                  letterSpacing: 0.5,
                ),
                children: [
                  const TextSpan(text: '還沒有帳號？'),
                  TextSpan(
                    text: '　立即註冊',
                    style: GoogleFonts.notoSerifTc(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String labelTriku,
    required String hint,
    required Widget prefixIcon,
    Widget? suffixIcon,
    bool obscureText = false,
    bool isGold = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.creamLight.withValues(alpha: 0.08),
        border: Border.all(
          color: isGold
              ? AppColors.gold.withValues(alpha: 0.30)
              : AppColors.cream.withValues(alpha: 0.18),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            labelTriku,
            style: TextStyle(
              fontSize: 10,
              color: isGold
                  ? AppColors.gold
                  : AppColors.cream.withValues(alpha: 0.65),
              letterSpacing: 2.5,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              prefixIcon,
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  obscureText: obscureText,
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.creamLight,
                    letterSpacing: obscureText ? 5 : 0.8,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    hintText: hint,
                    hintStyle: TextStyle(
                      color: AppColors.cream.withValues(alpha: 0.35),
                      fontSize: 15,
                    ),
                    suffixIcon: suffixIcon != null
                        ? Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: suffixIcon,
                          )
                        : null,
                    suffixIconConstraints: const BoxConstraints(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
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
            border: Border.all(
              color: AppColors.cream.withValues(alpha: 0.18),
            ),
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
                  fontSize: 9,
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
