// 文章、影音、活動的分類（後端決策紀錄 A53，2026-10-13 起由後端分類表提供）。
// 規格：Truku_backend 說明文件/API/活動提醒.md §1.0、文章模組.md §0.1、
// 影音模組.md §0.1、內部管理.md §6.1（後台清單格式相同，只是 count 算全部狀態）。

import 'dart:ui' show Color;

import '../core/constants/api.dart';

/// 分類名稱上限（後端 categories.ts `CATEGORY_LABEL_MAX`，以 UTF-16 單位計）。
/// 後台分類管理、文章表單、發起活動頁的新增分類共用。
const int categoryLabelMax = 20;

/// 分類清單的一筆。[value] 送出（發起、篩選）用，[label] 顯示用。
class ContentCategory {
  final String value;
  final String label;

  /// 後端已依它排好，照回傳順序顯示即可。
  final int sortOrder;

  /// 這個分類目前看得到的筆數。篩選列只顯示大於 0 的。
  final int count;

  /// 後端存的 `#RRGGBB`（大寫）；null＝用 App 預設色。只有活動分類會有值
  /// （決策紀錄 A56）。格式不對時照原樣保留，後台編輯時才能比對出「沒改」。
  final String? color;

  const ContentCategory({
    required this.value,
    required this.label,
    required this.sortOrder,
    required this.count,
    this.color,
  });

  /// [color] 轉成 [Color]；null 或不是 `#RRGGBB` 時回 null，由呼叫端用預設色。
  Color? get displayColor => parseHexColor(color);

  /// label 缺少時退回 value；數字欄位缺少時當 0，不因單筆壞資料讓整份清單失敗。
  factory ContentCategory.fromJson(Map<String, dynamic> json) {
    final value = json['value'] as String;
    return ContentCategory(
      value: value,
      label: json['label'] as String? ?? value,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      count: (json['count'] as num?)?.toInt() ?? 0,
      // 型別不對也當沒設，不讓整份清單失敗。
      color: json['color'] is String ? json['color'] as String : null,
    );
  }
}

final _hexColor = RegExp(r'^#[0-9A-Fa-f]{6}$');

/// `#RRGGBB`（大小寫皆可）轉成不透明的 [Color]；null 或格式不對回 null。
/// 後台色碼欄的格式檢查也用它。
Color? parseHexColor(String? hex) {
  if (hex == null || !_hexColor.hasMatch(hex)) return null;
  return Color(0xFF000000 | int.parse(hex.substring(1), radix: 16));
}

/// 有分類表的模組，各自一張表、彼此獨立。
enum CategoryModule {
  events(ApiConfig.eventCategories),
  articles(ApiConfig.articleCategories),
  videos(ApiConfig.videoCategories);

  /// 一般使用者的分類清單端點，例如 `/api/events/categories`。
  final String path;

  const CategoryModule(this.path);
}
