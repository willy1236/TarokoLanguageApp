// 整合測試共用登入 helper。
//
// 策略：靜默優先＋互動備援。
//   1. 已有有效 token → 直接沿用。
//   2. 否則靜默登入（重用裝置上已授權過的 Google 帳號，無 UI）。
//   3. 仍失敗 → 叫出原生帳號選擇，測試者手動點一次帳號。
//
// 首次在裝置授權一次後，之後測試即可全自動靜默登入。
//
// 需先 Firebase.initializeApp(...) 才能呼叫。

import 'package:flutter_application_1/services/auth_service.dart';

/// 確保測試前處於已登入狀態。回傳是否成功登入。
Future<bool> ensureLoggedIn() async {
  // 1. 沿用現有有效 token
  if (await AuthService.isLoggedIn()) return true;

  // 2. 靜默登入
  if (await AuthService.signInSilently() != null) return true;

  // 3. 互動備援（需手動點一次帳號）
  try {
    await AuthService.signInWithGoogle();
    return true;
  } on AuthException {
    return false;
  }
}
