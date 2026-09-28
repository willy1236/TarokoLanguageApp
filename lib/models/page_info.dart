// 列表分頁的共用型別。
// 規格：Truku_backend 說明文件/API/00_核心與認證.md §0「列表分頁」
//
// 請求帶 `limit`（1–50，預設 20）與上一頁的 `page_info.next_cursor`（第一頁不帶）；
// 回應的 `page_info` 描述還有沒有下一頁。游標一律是不透明字串，原樣帶回，不解析也不自組。

class PageInfo {
  /// 下一頁要帶的游標。沒有下一頁時一定是 null，畫面可以只存這個欄位。
  final String? nextCursor;

  const PageInfo({required this.nextCursor});

  bool get hasMore => nextCursor != null;

  /// 沒有下一頁。用在只抓第一頁的呼叫端，或測試的假資料。
  static const PageInfo end = PageInfo(nextCursor: null);

  /// 讀列表回應的 `page_info`。`has_more` 不是 true、或欄位缺少時都當作沒有下一頁：
  /// 寧可少載一頁，也不要拿不到游標還一直重打第一頁。
  factory PageInfo.fromResponse(Map<String, dynamic> json) {
    final info = json['page_info'];
    if (info is! Map<String, dynamic>) return end;
    final cursor = info['next_cursor'];
    if (info['has_more'] != true || cursor == null) return end;
    return PageInfo(nextCursor: '$cursor');
  }

  /// 請求參數：[cursor] 為 null 代表第一頁，不送出。
  static Map<String, String> query({String? cursor, int? limit}) => {
    'cursor': ?cursor,
    if (limit != null) 'limit': '$limit',
  };
}
