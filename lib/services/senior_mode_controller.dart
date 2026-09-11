import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 精簡模式開關的持久化與全域狀態。對外只暴露 [enabled] 與 [setEnabled]，
/// 讀寫 SharedPreferences 與非同步載入的細節都封裝在內部。
class SeniorModeController extends ChangeNotifier {
  static const _prefsKey = 'senior_mode_enabled';

  /// 已做精簡版的路由白名單。頁面做完精簡版後把路由名加進來即可，
  /// 呼叫端（[hasCustomLayout]）邏輯不用改。
  static const Set<String> _customLayoutRoutes = {
    'profile',
    'forum',
    'culture',
    'events',
  };

  bool _enabled = false;
  bool get enabled => _enabled;

  /// 該路由是否有專屬精簡版畫面；沒有則呼叫端應 fallback 回正常模式畫面。
  bool hasCustomLayout(String routeName) =>
      _customLayoutRoutes.contains(routeName);

  /// App 啟動時呼叫一次，從本機還原上次的開關狀態。
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_prefsKey) ?? false;
    notifyListeners();
  }

  int _writeGen = 0;

  Future<void> setEnabled(bool value) async {
    if (_enabled == value) return;
    _enabled = value;
    notifyListeners();
    // 快速連續切換時，只讓最後一次呼叫寫入，避免較早的寫入晚完成而蓋掉新值
    final gen = ++_writeGen;
    final prefs = await SharedPreferences.getInstance();
    if (gen != _writeGen) return;
    await prefs.setBool(_prefsKey, value);
  }
}

final seniorModeController = SeniorModeController();
