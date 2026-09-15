// Web 版 HLS 播放：HtmlElementView 內嵌原生 <video>（瀏覽器自帶控制列與全螢幕）。
// Safari 原生支援 HLS 直接設 src；Chrome/Edge/Firefox 交給 hls.js
// （web/index.html 載入 vendor/hls.min.js）以 MSE 播放。

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

@JS('Hls')
extension type _Hls._(JSObject _) implements JSObject {
  external _Hls();
  external static bool isSupported();
  external void loadSource(String url);
  external void attachMedia(web.HTMLVideoElement media);
  external void on(String event, JSFunction callback);
  external void destroy();
}

extension type _HlsErrorData._(JSObject _) implements JSObject {
  external bool get fatal;
  external String? get details;
}

/// Hls.Events.ERROR 的事件名稱。
const _hlsErrorEvent = 'hlsError';

class HlsWebPlayer extends StatefulWidget {
  final String url;

  /// 無法播放（瀏覽器不支援或串流致命錯誤）時呼叫，讓呼叫端改顯示降級畫面。
  final VoidCallback? onError;

  const HlsWebPlayer({super.key, required this.url, this.onError});

  @override
  State<HlsWebPlayer> createState() => _HlsWebPlayerState();
}

class _HlsWebPlayerState extends State<HlsWebPlayer> {
  web.HTMLVideoElement? _video;
  _Hls? _hls;

  void _onVideoCreated(Object element) {
    final video = element as web.HTMLVideoElement
      ..controls = true
      ..autoplay = true
      ..playsInline = true;
    video.style
      ..width = '100%'
      ..height = '100%'
      ..objectFit = 'contain'
      ..backgroundColor = 'black';
    _video = video;

    if (video.canPlayType('application/vnd.apple.mpegurl').isNotEmpty) {
      video.src = widget.url;
      return;
    }
    if (!globalContext.has('Hls') || !_Hls.isSupported()) {
      _reportError('瀏覽器不支援 HLS（hls.js 未載入或無 MSE）');
      return;
    }
    final hls = _Hls();
    hls.on(
      _hlsErrorEvent,
      ((JSAny? _, _HlsErrorData data) {
        if (data.fatal) _reportError('hls.js fatal error: ${data.details}');
      }).toJS,
    );
    hls.loadSource(widget.url);
    hls.attachMedia(video);
    _hls = hls;
  }

  void _reportError(String reason) {
    debugPrint('HlsWebPlayer: $reason');
    // 可能在 platform view 建立途中觸發，延到下一幀再讓呼叫端 setState。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onError?.call();
    });
  }

  @override
  void dispose() {
    _hls?.destroy();
    // 離開頁面後 <video> 可能仍掛在 DOM 上一小段時間，先停掉避免聲音持續。
    final video = _video;
    if (video != null) {
      video.pause();
      video.removeAttribute('src');
      video.load();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView.fromTagName(
      tagName: 'video',
      onElementCreated: _onVideoCreated,
    );
  }
}
