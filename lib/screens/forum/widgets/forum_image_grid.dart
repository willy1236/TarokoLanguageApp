// 貼文附圖。後端最多 4 張，1 張時滿版、2-4 張時九宮格。
// 點任一張進入全螢幕檢視，可左右滑動切換。

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class ForumImageGrid extends StatelessWidget {
  final List<String> urls;

  const ForumImageGrid({super.key, required this.urls});

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) return const SizedBox.shrink();
    if (urls.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: AspectRatio(
          aspectRatio: 16 / 10,
          child: _Thumb(urls: urls, index: 0),
        ),
      );
    }
    return GridView.count(
      crossAxisCount: urls.length == 2 ? 2 : 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      children: [
        for (var i = 0; i < urls.length; i++)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _Thumb(urls: urls, index: i),
          ),
      ],
    );
  }
}

class _Thumb extends StatelessWidget {
  final List<String> urls;
  final int index;

  const _Thumb({required this.urls, required this.index});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ForumImageViewer(urls: urls, initialIndex: index),
          ),
        ),
        child: CachedNetworkImage(
          imageUrl: urls[index],
          fit: BoxFit.cover,
          placeholder: (_, _) => Container(color: AppColors.creamDeep),
          errorWidget: (_, _, _) => Container(
            color: AppColors.creamDeep,
            alignment: Alignment.center,
            child: const Icon(
              Icons.broken_image_outlined,
              color: AppColors.fog,
              size: 20,
            ),
          ),
        ),
      );
}

/// 全螢幕檢視。深色底讓照片本身成為主體。
class ForumImageViewer extends StatelessWidget {
  final List<String> urls;
  final int initialIndex;

  const ForumImageViewer({
    super.key,
    required this.urls,
    required this.initialIndex,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.midnight,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: AppColors.creamLight),
        ),
        extendBodyBehindAppBar: true,
        body: PageView.builder(
          controller: PageController(initialPage: initialIndex),
          itemCount: urls.length,
          itemBuilder: (_, i) => InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: Center(
              child: CachedNetworkImage(imageUrl: urls[i], fit: BoxFit.contain),
            ),
          ),
        ),
      );
}
