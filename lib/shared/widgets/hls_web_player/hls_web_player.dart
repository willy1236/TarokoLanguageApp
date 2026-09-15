// Web 版 HLS 內嵌播放器。只有 Web 有實作，其他平台匯入 stub；呼叫端應先以
// PlatformFeatures.supportsWebHlsPlayer 判斷再使用。
export 'hls_web_player_stub.dart'
    if (dart.library.js_interop) 'hls_web_player_web.dart';
