import 'package:flutter/foundation.dart';

/// 封鎖版本號。封鎖成功後 [bump]，好友列表與論壇頁監聽後重抓。
///
/// 封鎖會雙向切斷好友關係並移除彼此的留言與讚（後端 2026-09-26 起），
/// 但好友分頁與論壇頁活在 IndexedStack 內不會自己重抓，只能靠這條訂閱。
class BlockRefreshNotifier {
  static final ValueNotifier<int> revision = ValueNotifier(0);

  static void bump() => revision.value++;
}
