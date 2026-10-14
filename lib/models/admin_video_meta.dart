// 後台影片的資訊欄位（標題、說明、分類、部落），建立（YouTube／上傳檔案）與編輯共用。
// 規格：Truku_backend 說明文件/API/內部管理.md §6.2。
// 由 `AdminVideoMetaFields` 產生；送出時建立用 [AdminVideoMeta.toJson]，
// 編輯用 [AdminVideoMeta.patchFrom] 算出要 PATCH 的欄位。

/// 標題上限（UTF-16 單位）。
const int adminVideoTitleMax = 100;

/// 說明上限（UTF-16 單位）。
const int adminVideoDescriptionMax = 2000;

class AdminVideoMeta {
  /// null 代表沒填（YouTube 可嵌入影片可留空，由後端帶入 YouTube 標題）。
  final String? title;
  final String? description;

  /// 分類 value；可以是清單裡沒有的新名稱，後端會自動加進分類表。
  final String category;
  final int? tribeId;

  const AdminVideoMeta({
    this.title,
    this.description,
    required this.category,
    this.tribeId,
  });

  /// 建立用：只輸出有值的欄位，空白字串視同沒填。
  Map<String, Object?> toJson() {
    final title = _blankToNull(this.title);
    final description = _blankToNull(this.description);
    return {
      'title': ?title,
      'description': ?description,
      'category': category,
      'tribe_id': ?tribeId,
    };
  }

  /// 編輯用：和 [original] 比對，只輸出有改動的欄位；說明、部落被清掉時輸出 null。
  /// 標題不能清空（後端必填），這邊沒填就不送。沒有改動回空 Map。
  Map<String, Object?> patchFrom(AdminVideoMeta original) {
    final title = _blankToNull(this.title);
    final description = _blankToNull(this.description);
    return {
      if (title != null && title != _blankToNull(original.title))
        'title': title,
      if (description != _blankToNull(original.description))
        'description': description,
      if (category != original.category) 'category': category,
      if (tribeId != original.tribeId) 'tribe_id': tribeId,
    };
  }

  static String? _blankToNull(String? v) {
    final t = v?.trim();
    return t == null || t.isEmpty ? null : t;
  }
}
