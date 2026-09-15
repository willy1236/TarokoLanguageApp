// 登出按鈕：先註銷 FCM token、清快取、登出，任一步失敗都不擋導回登入頁。

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../services/session_service.dart';

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
              await SessionService.signOut();
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
                    style: AppTypography.serif(
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
            style: AppTypography.mono(
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
