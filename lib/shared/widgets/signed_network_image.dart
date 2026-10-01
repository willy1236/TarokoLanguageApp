// 後端限時簽章網址（15 分鐘到期）的網路圖。活動圖片與活動封面共用。
//
// 快取以去掉簽章參數的網址為鍵：同一張圖換了新簽章不必重新下載，詳情頁的第一張
// 與列表封面也共用同一份快取。網址過期而且還沒快取到時會破圖，這時回報一次
// [SignedNetworkImage.onExpired]，由呼叫端重新取得網址。

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// 簽章網址的快取鍵：去掉 query string（簽章與到期時間），只留物件路徑。
String signedUrlCacheKey(String url) {
  final query = url.indexOf('?');
  return query < 0 ? url : url.substring(0, query);
}

/// 全螢幕檢視等需要 [ImageProvider] 的地方用，與 [SignedNetworkImage] 共用快取。
ImageProvider signedImageProvider(String url) =>
    CachedNetworkImageProvider(url, cacheKey: signedUrlCacheKey(url));

class SignedNetworkImage extends StatefulWidget {
  final String url;

  /// 載入中與破圖時顯示；破圖時呼叫端的版面就退回沒有圖的樣子。
  final Widget placeholder;

  /// 破圖時**自動**觸發，同一個網址只回報一次；換了新網址才會再回報。
  final VoidCallback? onExpired;

  /// 給了才在破圖上疊一顆重試鈕。手動重試是明確的使用者意圖，呼叫端不該拿自動
  /// 重試的次數上限擋它。
  final VoidCallback? onRetryTap;

  const SignedNetworkImage({
    super.key,
    required this.url,
    required this.placeholder,
    this.onExpired,
    this.onRetryTap,
  });

  @override
  State<SignedNetworkImage> createState() => _SignedNetworkImageState();
}

// 是 StatefulWidget 才能記住「這個網址已經回報過了」——寫在 errorWidget 裡的話
// 每次 rebuild 都會再排一次 callback，論壇附圖曾因此連環重打到 429。
class _SignedNetworkImageState extends State<SignedNetworkImage> {
  bool _reported = false;

  /// 手動重試時加一，換掉圖片元件讓它重新下載——網址沒變（後端簽章還沒到期）
  /// 時，不這樣做會一直停在破圖。
  int _attempt = 0;

  @override
  void didUpdateWidget(SignedNetworkImage old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) _reported = false;
  }

  void _reportExpiredOnce() {
    final expired = widget.onExpired;
    if (_reported || expired == null) return;
    _reported = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) expired();
    });
  }

  void _retry() {
    setState(() => _attempt++);
    widget.onRetryTap?.call();
  }

  @override
  Widget build(BuildContext context) => CachedNetworkImage(
    key: ValueKey(_attempt),
    imageUrl: widget.url,
    cacheKey: signedUrlCacheKey(widget.url),
    fit: BoxFit.cover,
    placeholder: (_, _) => widget.placeholder,
    errorWidget: (_, _, _) {
      _reportExpiredOnce();
      if (widget.onRetryTap == null) return widget.placeholder;
      return Stack(
        fit: StackFit.expand,
        children: [
          widget.placeholder,
          Center(
            child: IconButton.filled(
              onPressed: _retry,
              tooltip: '重新載入照片',
              style: IconButton.styleFrom(
                backgroundColor: AppColors.ink.withValues(alpha: 0.55),
              ),
              icon: const Icon(Icons.refresh, color: AppColors.creamLight),
            ),
          ),
        ],
      );
    },
  );
}
