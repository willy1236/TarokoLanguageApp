// 限時簽章網址的圖片（官方公告圖片、檢舉當時的頭像複本，約 15 分鐘有效）。
//
// 用 Image.network：只留在記憶體，不像 cached_network_image 會寫進本機磁碟。
// 網址過期後載入失敗，顯示佔位與提示；重抓列表拿到新網址就會重新載入。

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_radius.dart';
import '../../core/constants/app_typography.dart';

class EphemeralNetworkImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;

  /// 載入失敗時佔位圖示下方的說明；null 時只顯示圖示（縮圖用）。
  final String? failedHint;

  const EphemeralNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.failedHint,
  });

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(AppRadius.sm),
    child: Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : _placeholder(loading: true),
      errorBuilder: (context, error, stack) => _placeholder(loading: false),
    ),
  );

  Widget _placeholder({required bool loading}) => Container(
    width: width,
    height: height ?? 120,
    color: AppColors.creamDeep,
    alignment: Alignment.center,
    child: loading
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.broken_image_outlined, color: AppColors.fog),
              if (failedHint != null) ...[
                const SizedBox(height: 4),
                Text(
                  failedHint!,
                  textAlign: TextAlign.center,
                  style: AppTypography.captionStyle(color: AppColors.fog),
                ),
              ],
            ],
          ),
  );
}
