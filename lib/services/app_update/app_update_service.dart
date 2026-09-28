// 冷啟動時檢查有沒有新版本（規格：docs/app-update-prompt-spec.md）。
//
// 最新版本取「商店公開版本」與「Remote Config 版本」兩者較新的那個，平常只提醒；
// 目前版本低於 Remote Config 的最低版本時改成強制更新。任何失敗都安靜略過，不擋人。

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

  /// 商店／TestFlight 連結。只有強制更新時可能為 null（iOS 沒設 update_url_ios），
  /// 此時提示改請使用者自己到 TestFlight 或 App Store 更新。
  final String? url;

  /// 低於最低版本：不能略過或稍後，從商店回來也繼續擋著。
  final bool required;

  const AvailableUpdate({
    required this.version,
    required this.url,
    this.required = false,
  });
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

/// 目前版本低於最低版本時必須更新。沒設最低版本（Remote Config 留空）就不強制。
bool isUpdateRequired({required AppVersion current, AppVersion? minimum}) =>
    minimum != null && minimum > current;

/// 決定要不要提示、提示成哪一種；不需提示時回傳 null。純函式，方便測試。
///
/// 低於 [minimum] 時強制更新，不看 [skipped]，沒有連結也照樣擋；
/// 否則照 [pickUpdateVersion] 提醒，沒有連結就不提示。
AvailableUpdate? decideUpdate({
  required AppVersion current,
  AppVersion? store,
  AppVersion? remote,
  AppVersion? minimum,
  String? skipped,
  String? url,
}) {
  if (minimum != null && isUpdateRequired(current: current, minimum: minimum)) {
    // 最新版本查不到、或比最低版本還舊（設定有誤）時，至少要升到最低版本。
    final latest = pickUpdateVersion(
      current: current,
      store: store,
      remote: remote,
    );
    return AvailableUpdate(
      version: latest != null && latest > minimum ? latest : minimum,
      url: url,
      required: true,
    );
  }
  final version = pickUpdateVersion(
    current: current,
    store: store,
    remote: remote,
    skipped: skipped,
  );
  if (version == null || url == null) return null;
  return AvailableUpdate(version: version, url: url);
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
  static const _rcAndroidMinVersion = 'min_version_android';
  static const _rcIosMinVersion = 'min_version_ios';

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
    final remote = await _orNull(_fetchRemoteConfig(), 'Remote Config 讀取');
    final url = (remote?.url.isNotEmpty ?? false)
        ? remote!.url
        : _defaultStoreUrl(info.packageName);

    // 強制更新只看 Remote Config：商店查詢最長要等逾時，不能讓太舊的 App
    // 趁這段時間走完登入與條款流程。
    if (isUpdateRequired(current: current, minimum: remote?.minimum)) {
      return decideUpdate(
        current: current,
        remote: remote?.version,
        minimum: remote?.minimum,
        url: url,
      );
    }

    final store = await storeFuture;
    final prefs = await SharedPreferences.getInstance();
    return decideUpdate(
      current: current,
      store: store,
      remote: remote?.version,
      minimum: remote?.minimum,
      skipped: prefs.getString(_skippedKey),
      url: url,
    );
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
      _rcAndroidMinVersion: '',
      _rcIosMinVersion: '',
    });
    await rc.fetchAndActivate();
    return _RemoteValues(
      version: AppVersion.tryParse(
        rc.getString(_isIos ? _rcIosVersion : _rcAndroidVersion),
      ),
      url: rc.getString(_isIos ? _rcIosUrl : _rcAndroidUrl).trim(),
      minimum: AppVersion.tryParse(
        rc.getString(_isIos ? _rcIosMinVersion : _rcAndroidMinVersion),
      ),
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
  final AppVersion? minimum;

  const _RemoteValues({
    required this.version,
    required this.url,
    required this.minimum,
  });
}
