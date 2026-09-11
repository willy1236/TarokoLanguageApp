// 登出按鈕：先註銷 FCM token、清快取、登出，任一步失敗都不擋導回登入頁。

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../services/auth_service.dart';
import '../../../services/fcm_service.dart';
import '../../../services/user_service.dart';

import 'profile_rows.dart';

class ProfileLogoutButton extends StatelessWidget {
  const ProfileLogoutButton({super.key});

  @override
  Widget build(BuildContext context) => _buildLogout(context);

  Widget _buildLogout(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        children: [
          GestureDetector(
            onTap: () async {
              // 先移除本裝置 FCM token（需 JWT，故在 signOut 之前），再登出。
              // 註銷失敗（離線、後端錯誤）不該擋住登出——否則使用者卡在此頁
              // 且沒有任何錯誤提示。最壞情況是這台裝置仍留著 token，
              // 後端推播時會因 token 失效自行清除。
              try {
                await FcmService.unregisterDevice();
              } catch (e) {
                debugPrint('ProfileScreen: 註銷裝置 FCM token 失敗（忽略）：$e');
              }
              UserService.clearCache();
              try {
                await AuthService.signOut();
              } catch (e) {
                debugPrint('ProfileScreen: signOut 失敗，仍導回登入頁：$e');
              }
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login',
                  (_) => false,
                );
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CustomPaint(
                    size: const Size(16, 16),
                    painter: ProfileLogoutIconPainter(),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '登出',
                    style: GoogleFonts.notoSerifTc(
                      fontSize: AppTypography.body,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'v1.0.0 · MHUWAY SU',
            style: GoogleFonts.jetBrainsMono(
              fontSize: AppTypography.micro,
              color: AppColors.fog,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}
