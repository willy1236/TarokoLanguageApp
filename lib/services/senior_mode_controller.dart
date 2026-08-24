import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 精簡模式開關的持久化與全域狀態。對外只暴露 [enabled] 與 [setEnabled]，
/// 讀寫 SharedPreferences 與非同步載入的細節都封裝在內部。
class SeniorModeController extends ChangeNotifier {
  static const _prefsKey = 'senior_mode_enabled';

  bool _enabled = false;
  bool get enabled => _enabled;

  /// App 啟動時呼叫一次，從本機還原上次的開關狀態。
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_prefsKey) ?? false;
    notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    if (_enabled == value) return;
    _enabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, value);
  }
}

final seniorModeController = SeniorModeController();
