// Google Maps Platform 金鑰（活動地圖選點）。三個平台各一把，在 Google Cloud 主控台分別
// 限制：Android 套件名＋SHA-1、iOS bundle id、Web 網址，外流也只能在本 App 使用，所以跟
// firebase_options.dart 一樣放在原始碼。地圖本身另外讀平台設定，換金鑰時要一起改：
// Android `AndroidManifest.xml` 的 com.google.android.geo.API_KEY、iOS `Info.plist` 的 GMSApiKey。
// 還沒填的平台不顯示地圖選點（見 PlatformFeatures.supportsMapPicker）。

import 'package:flutter/foundation.dart';

class MapsConfig {
  MapsConfig._();

  static const _androidKey = '';
  static const _iosKey = '';
  static const _webKey = '';

  /// 目前平台的金鑰；空字串＝這個平台還沒設定。
  static String get apiKey {
    if (kIsWeb) return _webKey;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => _androidKey,
      TargetPlatform.iOS => _iosKey,
      _ => '',
    };
  }
}
