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
import '../../../core/constants/app_typography.dart';

class ForumImageGrid extends StatelessWidget {
  final List<String> urls;

  /// 給定時取代「開啟全螢幕檢視」的預設行為。
  final VoidCallback? onTap;

  /// 圖片載入失敗時**自動**觸發（多半是簽章網址已過期，15 分鐘效期）。
  /// 呼叫端可用它重新打貼文 API 拿新網址，而不是要求使用者手動下拉整頁。
  /// 每張圖對同一個網址只會回報一次，重新整理的次數上限由呼叫端決定。
  final VoidCallback? onImageExpired;

  /// 使用者**手動**點擊破圖佔位時觸發。和 [onImageExpired] 分開是因為呼叫端
  /// 會限制自動重試的次數，但手動重試是明確的使用者意圖，不該被那個上限擋掉。
  final VoidCallback? onRetryTap;

  const ForumImageGrid({
    super.key,
    required this.urls,
    this.onTap,
    this.onImageExpired,
    this.onRetryTap,
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
            onRetryTap: onRetryTap,
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
              onRetryTap: onRetryTap,
            ),
          ),
      ],
    );
  }
}

// 破圖時回報一次「網址可能過期」給呼叫端。是 StatefulWidget 才能記住「這個
// 網址已經回報過了」——寫在 errorWidget 裡的話每次 rebuild 都會再排一次
// callback，呼叫端就算有次數上限也擋不住連環重打（實際造成過 429）。
class _Thumb extends StatefulWidget {
  final String url;
  final VoidCallback onTap;
  final VoidCallback? onExpired;
  final VoidCallback? onRetryTap;

  const _Thumb({
    required this.url,
    required this.onTap,
    this.onExpired,
    this.onRetryTap,
  });

  @override
  State<_Thumb> createState() => _ThumbState();
}

class _ThumbState extends State<_Thumb> {
  bool _reported = false;

  @override
  void didUpdateWidget(_Thumb old) {
    super.didUpdateWidget(old);
    // 換了新網址（呼叫端重新簽章成功）才重新開放回報。
    if (old.url != widget.url) _reported = false;
  }

  void _reportExpiredOnce() {
    if (_reported) return;
    final expired = widget.onExpired;
    if (expired == null) return;
    _reported = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) expired();
    });
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: widget.onTap,
    child: CachedNetworkImage(
      imageUrl: widget.url,
      fit: BoxFit.cover,
      placeholder: (_, _) => Container(color: AppColors.creamDeep),
      errorWidget: (_, _, _) {
        _reportExpiredOnce();
        final retry = widget.onRetryTap;
        return GestureDetector(
          onTap: retry,
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
                if (retry != null) ...[
                  const SizedBox(height: 4),
                  const Icon(Icons.refresh, color: AppColors.fog, size: 16),
                ],
              ],
            ),
          ),
        );
      },
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
              style: const TextStyle(color: AppColors.creamLight, fontSize: AppTypography.body),
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
