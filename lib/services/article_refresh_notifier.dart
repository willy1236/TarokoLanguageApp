import 'package:flutter/foundation.dart';

/// 文章列表版本號。管理員在 App 內編輯或下架文章後 [bump]，文化頁的文章分頁
/// 與精選輪播監聽後重抓——它們活在 IndexedStack 內不會自己重抓。
class ArticleRefreshNotifier {
  static final ValueNotifier<int> revision = ValueNotifier(0);

  static void bump() => revision.value++;
}
