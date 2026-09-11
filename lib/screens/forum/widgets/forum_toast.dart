import 'package:flutter/material.dart';

/// 論壇共用的輕提示：先清掉前一則再顯示，連續操作（按讚、留言、檢舉）時
/// 不會把 SnackBar 排成一長串。
void showForumToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(message)));
}
