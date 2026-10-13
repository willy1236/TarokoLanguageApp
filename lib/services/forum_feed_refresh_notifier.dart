import 'package:flutter/foundation.dart';

/// 論壇動態重載版本號。取消隱藏成功後 [bump]，廣場監聽後整份重抓。
///
/// 取消隱藏的通常是舊貼文，廣場下拉刷新只補比第一篇更新的貼文，抓不回來；
/// 廣場又活在 IndexedStack 內不會自己重抓，只能靠這條訂閱。
class ForumFeedRefreshNotifier {
  static final ValueNotifier<int> revision = ValueNotifier(0);

  static void bump() => revision.value++;
}
