// 冷啟動時檢查有沒有新版本（規格：docs/app-update-prompt-spec.md）。
//
// 最新版本取「商店公開版本」與「Remote Config 版本」兩者較新的那個；
// 只提醒不強制，任何失敗都安靜略過。

import 'dart:async';
import 'dart:convert';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/platform/platform_features.dart';
import 'app_version.dart';

class AvailableUpdate {
  final AppVersion version;
  final String url;

  const AvailableUpdate({required this.version, required this.url});
}

/// 選出要提示的版本；不需提示時回傳 null。純函式，方便測試。
AppVersion? pickUpdateVersion({
  required AppVersion current,
  AppVersion? store,
  AppVersion? remote,
  String? skipped,
}) {
  AppVersion? latest;
  for (final v in [store, remote]) {
    if (v == null) continue;
    // 名稱相同時留有 build number 的那個，略過紀錄才分得出同名的不同 build。
    final c = latest == null ? 1 : v.compareTo(latest);
    if (c > 0 || (c == 0 && latest!.build == null)) latest = v;
  }
  if (latest == null || !(latest > current)) return null;
  if (skipped == latest.toString()) return null;
  return latest;
}

class AppUpdateService {
  AppUpdateService._();

  static const _skippedKey = 'app_update_skipped_version';
  static const _timeout = Duration(seconds: 10);

  // Remote Config 參數名稱（Firebase 主控台需建立同名參數）。
  static const _rcAndroidVersion = 'latest_version_android';
  static const _rcIosVersion = 'latest_version_ios';
  static const _rcAndroidUrl = 'update_url_android';
  static const _rcIosUrl = 'update_url_ios';

  /// 目前待提示的更新；由 App 最上層監聽並疊出提示。
  static final available = ValueNotifier<AvailableUpdate?>(null);

  static bool get _isIos => defaultTargetPlatform == TargetPlatform.iOS;

  /// 冷啟動呼叫一次。Web、Windows 不檢查；失敗一律吞掉。
  static Future<void> checkOnLaunch() async {
    if (!PlatformFeatures.isMobile) return;
    try {
      final update = await _check();
      if (update != null) available.value = update;
    } catch (e) {
      debugPrint('AppUpdateService.checkOnLaunch 略過：$e');
    }
  }

  static Future<AvailableUpdate?> _check() async {
    final info = await PackageInfo.fromPlatform();
    final current = AppVersion.tryParse('${info.version}+${info.buildNumber}');
    if (current == null) return null;

    // 兩個來源各自失敗不影響另一邊。
    final storeFuture = _orNull(_fetchStoreVersion(info.packageName), '商店版本查詢');
    final remoteFuture = _orNull(_fetchRemoteConfig(), 'Remote Config 讀取');
    final store = await storeFuture;
    final remote = await remoteFuture;

    final prefs = await SharedPreferences.getInstance();
    final version = pickUpdateVersion(
      current: current,
      store: store,
      remote: remote?.version,
      skipped: prefs.getString(_skippedKey),
    );
    if (version == null) return null;

    final url = (remote?.url.isNotEmpty ?? false)
        ? remote!.url
        : _defaultStoreUrl(info.packageName);
    if (url == null) return null;
    return AvailableUpdate(version: version, url: url);
  }

  /// 按「略過此版本」：這一版不再提醒，之後更新的版本照常提醒。
  static Future<void> skip(AvailableUpdate update) async {
    available.value = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_skippedKey, update.version.toString());
  }

  static Future<T?> _orNull<T>(Future<T> future, String label) async {
    try {
      return await future;
    } catch (e) {
      debugPrint('AppUpdateService $label失敗：$e');
      return null;
    }
  }

  static void dismiss() => available.value = null;

  // iOS 測試期沒有 App Store 頁面，連結一定要由 Remote Config 提供。
  static String? _defaultStoreUrl(String packageName) => _isIos
      ? null
      : 'https://play.google.com/store/apps/details?id=$packageName';

  static Future<_RemoteValues> _fetchRemoteConfig() async {
    final rc = FirebaseRemoteConfig.instance;
    await rc.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: _timeout,
        minimumFetchInterval: kDebugMode
            ? Duration.zero
            : const Duration(hours: 1),
      ),
    );
    await rc.setDefaults(const {
      _rcAndroidVersion: '',
      _rcIosVersion: '',
      _rcAndroidUrl: '',
      _rcIosUrl: '',
    });
    await rc.fetchAndActivate();
    return _RemoteValues(
      version: AppVersion.tryParse(
        rc.getString(_isIos ? _rcIosVersion : _rcAndroidVersion),
      ),
      url: rc.getString(_isIos ? _rcIosUrl : _rcAndroidUrl).trim(),
    );
  }

  static Future<AppVersion?> _fetchStoreVersion(String packageName) => _isIos
      ? _fetchAppStoreVersion(packageName)
      : _fetchPlayVersion(packageName);

  static Future<AppVersion?> _fetchAppStoreVersion(String bundleId) async {
    final uri = Uri.https('itunes.apple.com', '/lookup', {
      'bundleId': bundleId,
      'country': 'tw',
    });
    final res = await http.get(uri).timeout(_timeout);
    if (res.statusCode != 200) return null;
    final results = (jsonDecode(res.body) as Map<String, dynamic>)['results'];
    if (results is! List || results.isEmpty) return null;
    return AppVersion.tryParse(results.first['version'] as String?);
  }

  // Play 沒有公開 API，只能從商店頁面內嵌的資料擷取版本名稱。
  // 頁面格式一變就會查不到，此時等同「商店查不到」，只剩 Remote Config。
  static Future<AppVersion?> _fetchPlayVersion(String packageName) async {
    final uri = Uri.https('play.google.com', '/store/apps/details', {
      'id': packageName,
      'hl': 'en',
    });
    final res = await http.get(uri).timeout(_timeout);
    if (res.statusCode != 200) return null;
    final match = RegExp(
      r'\[\[\["(\d+(?:\.\d+)+)"\]\],\[\[\[',
    ).firstMatch(res.body);
    return AppVersion.tryParse(match?.group(1));
  }
}

class _RemoteValues {
  final AppVersion? version;
  final String url;

  const _RemoteValues({required this.version, required this.url});
}
