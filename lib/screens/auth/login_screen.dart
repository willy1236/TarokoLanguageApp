import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() {
    // 略過驗證，直接跳轉主頁
    Navigator.pushReplacementNamed(context, '/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo / 標題
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(30),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.language_rounded,
                    size: 44,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'KARI TRUKU',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '太魯閣族語傳承',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 48),

                // Email 輸入框
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: '電子郵件',
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(
                      Icons.email_outlined,
                      color: Colors.white38,
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceVariant,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 18,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 密碼輸入框
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: '密碼',
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(
                      Icons.lock_outline_rounded,
                      color: Colors.white38,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        color: Colors.white38,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceVariant,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 18,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // 忘記密碼
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {},
                    child: const Text(
                      '忘記密碼？',
                      style: TextStyle(color: Colors.white38, fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 登入按鈕
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 6,
                      textStyle: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child: const Text('登入'),
                  ),
                ),
                const SizedBox(height: 24),

                // 分隔線
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.white12)),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        '或',
                        style: TextStyle(color: Colors.white38, fontSize: 13),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.white12)),
                  ],
                ),
                const SizedBox(height: 24),

                // 註冊提示
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '還沒有帳號？',
                      style: TextStyle(color: Colors.white38),
                    ),
                    TextButton(
                      onPressed: () {},
                      child: const Text(
                        '立即註冊',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
