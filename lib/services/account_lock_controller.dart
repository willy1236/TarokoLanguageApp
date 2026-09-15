// 帳號唯讀（moderation 鎖帳號，users.status='locked'）的全域狀態。
//
// 進入點：登入回應 account_state == 'locked'、冷啟動查 /api/account/status、
// 重新啟用回 status: 'locked'、任一寫入端點回 403 ACCOUNT_LOCKED。
// 只存記憶體：每次冷啟動由 status 端點刷新，登出時歸零。
// 後端刻意不透露封鎖原因，前端文案也不寫原因。
// 規格：Truku_backend 說明文件/API/內部管理.md §8.4、帳號刪除.md §3.4／§3.5

import 'package:flutter/material.dart';

import '../main.dart';

const String readOnlyMessage = '您的帳號目前為唯讀狀態，暫時無法執行此操作';

class AccountLockController extends ChangeNotifier {
  bool _locked = false;
  bool get locked => _locked;

  void setLocked(bool value) {
    if (_locked == value) return;
    _locked = value;
    notifyListeners();
  }
}

final accountLockController = AccountLockController();

/// 唯讀時顯示統一提示並回 true，給被擋動作的 onTap 開頭用：
/// `if (blockIfReadOnly()) return;`
bool blockIfReadOnly() {
  if (!accountLockController.locked) return false;
  showReadOnlyToast();
  return true;
}

void showReadOnlyToast() {
  scaffoldMessengerKey.currentState
    ?..clearSnackBars()
    ..showSnackBar(const SnackBar(content: Text(readOnlyMessage)));
}
