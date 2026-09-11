// 發文畫面的附圖區。編輯模式與新增模式是兩套不同的東西：編輯時附圖是
// 後端的網址且不能改（唯讀），新增時是本機選的圖（可預覽、移除、再加）。

import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../services/forum_service.dart';

/// 編輯模式：唯讀顯示既有附圖。
class ForumComposeEditImages extends StatelessWidget {
  final List<String> urls;
  final bool seniorMode;

  const ForumComposeEditImages({
    super.key,
    required this.urls,
    required this.seniorMode,
  });

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) return const SizedBox.shrink();
    final size = seniorMode ? 104.0 : 88.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '附圖無法在編輯時變更',
          style: TextStyle(
            fontSize: seniorMode ? AppTypography.body : 12,
            color: AppColors.fog,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: size,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: urls.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) => ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: urls[i],
                width: size,
                height: size,
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(
                  width: size,
                  height: size,
                  color: AppColors.creamDeep,
                ),
                errorWidget: (_, _, _) => Container(
                  width: size,
                  height: size,
                  color: AppColors.creamDeep,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: AppColors.fog,
                    size: seniorMode ? 26 : 20,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 新增模式：本機選取的圖，可點縮圖預覽、右上角移除、未達上限時可再加。
class ForumComposePickedImages extends StatelessWidget {
  final List<Uint8List> images;
  final bool seniorMode;
  final ValueChanged<int> onPreview;
  final ValueChanged<int> onRemove;
  final VoidCallback onAdd;

  const ForumComposePickedImages({
    super.key,
    required this.images,
    required this.seniorMode,
    required this.onPreview,
    required this.onRemove,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final thumbSize = seniorMode ? 100.0 : 80.0;
    final deleteBadgeSize = seniorMode ? 28.0 : 18.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < images.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      GestureDetector(
                        // 點縮圖看原圖：縮圖只有 80px，選錯圖在這個尺寸下看不出來。
                        onTap: () => onPreview(i),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.memory(
                            images[i],
                            width: thumbSize,
                            height: thumbSize,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => onRemove(i),
                          child: Container(
                            width: deleteBadgeSize,
                            height: deleteBadgeSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black.withValues(alpha: 0.6),
                            ),
                            child: Icon(
                              Icons.close,
                              size: seniorMode ? 16 : 10,
                              color: AppColors.creamLight,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (images.length < ForumService.imageMaxCount)
                GestureDetector(
                  onTap: onAdd,
                  child: Container(
                    width: thumbSize,
                    height: thumbSize,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.fog.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      Icons.add,
                      color: AppColors.fog,
                      size: seniorMode ? 28 : 22,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${images.length}/${ForumService.imageMaxCount} 張',
          style: TextStyle(
            fontSize: seniorMode ? AppTypography.body : 11,
            color: AppColors.fog,
          ),
        ),
      ],
    );
  }
}
