// 官方公告內容頁：標題、發布時間、圖片、內文。從收件匣點公告進來。

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_typography.dart';
import '../../core/utils/date_format.dart';
import '../../models/inbox_models.dart';
import '../../services/senior_mode_controller.dart';
import '../../shared/widgets/app_back_button.dart';
import '../../shared/widgets/ephemeral_network_image.dart';

class AnnouncementDetailScreen extends StatelessWidget {
  final InboxItem item;

  const AnnouncementDetailScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: seniorModeController,
    builder: (context, _) => _buildScaffold(seniorModeController.enabled),
  );

  Widget _buildScaffold(bool seniorMode) {
    final imageUrl = item.imageUrl;
    final body = item.body ?? '';
    return Scaffold(
      backgroundColor: AppColors.creamLight,
      appBar: AppBar(
        leading: const AppBackButton(),
        backgroundColor: AppColors.creamLight,
        elevation: 0,
        foregroundColor: AppColors.ink,
        title: Text(
          '官方公告',
          style: AppTypography.titleStyle(
            seniorMode: seniorMode,
            color: AppColors.ink,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, AppSpacing.sm, 20, 32),
          children: [
            Text(
              item.title,
              style: AppTypography.headlineStyle(
                seniorMode: seniorMode,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              formatDateTime(item.createdAt),
              style: AppTypography.captionStyle(
                seniorMode: seniorMode,
                color: AppColors.fog,
              ),
            ),
            if (imageUrl != null && imageUrl.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              EphemeralNetworkImage(
                url: imageUrl,
                fit: BoxFit.fitWidth,
                failedHint: '圖片載入失敗，請回收件匣下拉重新整理',
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            SelectableText(
              body,
              style: AppTypography.bodyLargeStyle(
                seniorMode: seniorMode,
                color: AppColors.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
