// 各平台可用功能的集中判斷。App 以 Android/iOS 為主，Web/桌面版部分套件
// 沒有實作（FCM、better_player_plus、Agora 權限流程…），畫面與 service 只查
// 這裡決定要不要啟用或改顯示降級提示，不要在各處自己寫 kIsWeb 判斷。

import 'package:flutter/foundation.dart';

class PlatformFeatures {
  PlatformFeatures._();

  static bool get isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// FCM 推播 + 系統通知列。Web 需另設 service worker，桌面版 FCM 無實作。
  static bool get supportsPush => isMobile;

  /// Agora 視訊通話（含相機/麥克風權限流程）。
  static bool get supportsVideoCall => isMobile;

  static const videoCallUnsupportedMessage = '視訊通話目前僅支援手機 App';

  /// better_player_plus HLS 播放器。
  static bool get supportsHlsPlayer => isMobile;

  /// 有本機檔案系統可寫暫存檔（Web 沒有，改傳 bytes）。
  static bool get hasFileSystem => !kIsWeb;

  /// 後端 POST /api/devices 的 platform 欄位。只在 [supportsPush] 為 true
  /// 時有意義；Web/桌面沒有對應值，呼叫前必須先確認 [supportsPush]。
  static String get devicePlatform {
    assert(isMobile, 'devicePlatform 只能在行動平台使用（先檢查 supportsPush）');
    return defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
  }
}
