// 貼文附圖。後端最多 4 張，1 張時滿版、2-4 張時九宮格。
//
// 點擊行為依情境不同：
//   * 貼文列表：整張卡片（含附圖）都是進詳情頁的入口，所以由呼叫端傳 onTap
//     覆蓋，不在列表就打開全螢幕檢視——列表上放大圖片會讓「點卡片進貼文」
//     這件事變得不一致。
//   * 貼文詳情：不傳 onTap，點圖進全螢幕檢視，可雙指縮放與左右滑動。

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class ForumImageGrid extends StatelessWidget {
  final List<String> urls;

  /// 給定時取代「開啟全螢幕檢視」的預設行為。
  final VoidCallback? onTap;

  /// 圖片載入失敗時觸發（多半是簽章網址已過期，15 分鐘效期）。
  /// 呼叫端可用它重新打貼文 API 拿新網址，而不是要求使用者手動下拉整頁。
  final VoidCallback? onImageExpired;

  const ForumImageGrid({
    super.key,
    required this.urls,
    this.onTap,
    this.onImageExpired,
  });

  void _open(BuildContext context, int index) {
    final override = onTap;
    if (override != null) {
      override();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ForumImageViewer(
          images: [for (final url in urls) CachedNetworkImageProvider(url)],
          initialIndex: index,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) return const SizedBox.shrink();
    if (urls.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: AspectRatio(
          aspectRatio: 16 / 10,
          child: _Thumb(
            url: urls.first,
            onTap: () => _open(context, 0),
            onExpired: onImageExpired,
          ),
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
            child: _Thumb(
              url: urls[i],
              onTap: () => _open(context, i),
              onExpired: onImageExpired,
            ),
          ),
      ],
    );
  }
}

class _Thumb extends StatelessWidget {
  final String url;
  final VoidCallback onTap;
  final VoidCallback? onExpired;

  const _Thumb({required this.url, required this.onTap, this.onExpired});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, _) => Container(color: AppColors.creamDeep),
      errorWidget: (_, _, _) => GestureDetector(
        onTap: onExpired,
        child: Container(
          color: AppColors.creamDeep,
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.broken_image_outlined,
                color: AppColors.fog,
                size: 20,
              ),
              if (onExpired != null) ...[
                const SizedBox(height: 4),
                const Icon(Icons.refresh, color: AppColors.fog, size: 16),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

/// 全螢幕檢視。深色底讓照片本身成為主體。
///
/// 收 [ImageProvider] 而非網址，因為發文畫面要預覽的是還沒上傳、只存在記憶體裡
/// 的圖片（MemoryImage），已發布的貼文則是網路圖（CachedNetworkImageProvider）。
///
/// 是 StatefulWidget 才能持有並釋放 PageController——建在 build() 裡會在每次
/// 重建（例如旋轉螢幕）時重來，畫面會跳回第一張。
class ForumImageViewer extends StatefulWidget {
  final List<ImageProvider> images;
  final int initialIndex;

  const ForumImageViewer({
    super.key,
    required this.images,
    this.initialIndex = 0,
  });

  @override
  State<ForumImageViewer> createState() => _ForumImageViewerState();
}

class _ForumImageViewerState extends State<ForumImageViewer> {
  late final PageController _controller = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.midnight,
    appBar: AppBar(
      backgroundColor: AppColors.midnight,
      elevation: 0,
      iconTheme: const IconThemeData(color: AppColors.creamLight),
      title: widget.images.length > 1
          ? Text(
              '${_index + 1} / ${widget.images.length}',
              style: const TextStyle(color: AppColors.creamLight, fontSize: 14),
            )
          : null,
      centerTitle: true,
    ),
    body: PageView.builder(
      controller: _controller,
      onPageChanged: (i) => setState(() => _index = i),
      itemCount: widget.images.length,
      itemBuilder: (_, i) => InteractiveViewer(
        minScale: 1,
        maxScale: 4,
        child: Center(
          child: Image(image: widget.images[i], fit: BoxFit.contain),
        ),
      ),
    ),
  );
}
