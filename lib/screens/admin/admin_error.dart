// 後台共用的錯誤處理與導頁。
//
// 後台錯誤一律直接顯示後端 message：SELF_INVOLVED、SAME_ADMIN 等是給管理員看的
// 明確指示，不加「操作失敗：」前綴，也不當成一般錯誤吞掉。
// ADMIN_ONLY 代表這個帳號已不是管理員（角色被改、或入口是舊快取造成的）：
// 顯示訊息、重抓 /api/me（讓個人頁入口消失）並退出整個後台。

import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../main.dart';
import '../../services/user_service.dart';

/// 後台畫面的 route 名稱前綴：[handleAdminError] 靠它一次退出整個後台。
const String _adminRoutePrefix = 'admin/';

/// 開一個後台畫面。所有後台畫面都用它開，route 名稱才會帶前綴。
Future<T?> pushAdmin<T>(BuildContext context, Widget screen) =>
    Navigator.of(context).push<T>(
      MaterialPageRoute(
        settings: RouteSettings(
          name: '$_adminRoutePrefix${screen.runtimeType}',
        ),
        builder: (_) => screen,
      ),
    );

/// 是不是「非管理員」錯誤（403 ADMIN_ONLY）。
bool isAdminOnlyError(Object? error) =>
    error is ApiException && error.code == 'ADMIN_ONLY';

/// 顯示一則訊息。走全域 messenger：呼叫端畫面接著被 pop 時提示也不會消失。
void showAdminMessage(String message) {
  scaffoldMessengerKey.currentState
    ?..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// 後台請求失敗的統一出口，回傳 true 代表已離開後台（呼叫端不要再動畫面）。
///
/// [toast] 為 false 時只處理 ADMIN_ONLY，其他錯誤交給呼叫端自己呈現
/// （例如整頁載入失敗改顯示錯誤畫面）。
bool handleAdminError(BuildContext context, Object error, {bool toast = true}) {
  if (isAdminOnlyError(error)) {
    showAdminMessage(apiErrorMessage(error));
    UserService.fetchMe(forceRefresh: true).then<void>(
      (_) {},
      onError: (Object e) => debugPrint('ADMIN_ONLY 後重抓 /api/me 失敗：$e'),
    );
    Navigator.of(context).popUntil(
      (route) => !(route.settings.name?.startsWith(_adminRoutePrefix) ?? false),
    );
    return true;
  }
  if (toast) showAdminMessage(apiErrorMessage(error));
  return false;
}
