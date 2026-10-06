// Web 版的 Maps JS：自己載入（才能指定繁中與台灣地區），以及用它的 Geocoder 做反向
// 地理編碼（Geocoding 的 REST 端點不接受限網址的金鑰）。只有 Web 有實作，其他平台匯入 stub。
export 'web_maps_stub.dart' if (dart.library.js_interop) 'web_maps_web.dart';
