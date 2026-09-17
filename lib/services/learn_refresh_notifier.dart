import 'package:flutter/foundation.dart';

/// 測驗資料版本號。任何會改變測驗紀錄或等級狀態的動作（交卷、分級測驗完成）
/// 成功後 [bump]，測驗紀錄頁與等級選擇頁監聽後重抓。
///
/// 用全域 notifier 而非 `Navigator.pop` 回傳值，是因為聽力訂正頁與分級結果頁
/// 走 `popUntil((r) => r.isFirst)`：中間頁在返回前就被 dispose，`.then` 回呼
/// 一定會卡在 `if (mounted)` 而失效。
class LearnRefreshNotifier {
  static final ValueNotifier<int> revision = ValueNotifier(0);

  static void bump() => revision.value++;
}
