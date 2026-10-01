import 'package:flutter/material.dart';

/// 共用的輕提示：先清掉前一則再顯示，連續操作（按讚、留言、檢舉）時
/// 不會把 SnackBar 排成一長串。
void showAppToast(BuildContext context, String message) =>
    ScaffoldMessenger.of(context).showAppToast(message);

extension AppToast on ScaffoldMessengerState {
  /// 同 [showAppToast]；呼叫端的 context 可能在 await 後失效時，
  /// 先取好 messenger 再用這個。
  void showAppToast(String message) {
    clearSnackBars();
    showSnackBar(SnackBar(content: Text(message)));
  }
}
