// 分類清單讀取與名稱對照（T-21）。活動頁、發起頁、文化頁、後台都從這裡拿，
// 不各自寫死、不各自打 API。
// 端點：GET /api/{events,articles,videos}/categories（需登入），
// 回 { categories: [{ value, label, sort_order, count, color }] }，含 count 0、已排序；
// color 只有活動分類有。

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;

import '../core/network/api_client.dart';
import '../models/content_category.dart';

class CategoryService {
  static final Map<CategoryModule, List<ContentCategory>> _cache = {};

  /// 每個模組最新發出的請求。非 refresh 的呼叫共用它，不重複打 API。
  static final Map<CategoryModule, Future<List<ContentCategory>>> _inflight =
      {};

  /// 請求序號：每發一次請求加一。[_cachedSeq] 記快取內容來自哪一個序號，
  /// 較早發出、較晚回來的請求不能蓋掉較新的結果。
  static int _seq = 0;
  static final Map<CategoryModule, int> _cachedSeq = {};

  /// [reset] 前發出的請求（序號不大於它）回來時不寫快取。
  static int _discardUpTo = 0;

  /// 文章、影音的預設分類對照，清單還沒抓回來時用，避免先閃出 `tribal_intro` 這種代碼。
  /// 活動分類的 value 本身就是中文，不需要預設對照。
  static const Map<String, String> _defaultArticleVideoLabels = {
    'tribal_intro': '部落宣傳',
    'cultural': '文化紀錄',
    'event': '活動紀錄',
    'education': '教學延伸',
    'other': '其他',
  };

  /// 照後端順序回全部分類（含 count 0）。
  ///
  /// 有快取且不是 [refresh] 時直接回快取；沒有快取時共用進行中的請求。
  /// [refresh] 一律發新請求、不共用進行中的：管理員剛新增或改名分類後呼叫時，
  /// 進行中的舊請求可能是改動前發出的，拿到的清單不會有新分類。
  /// 失敗時丟出例外、不寫入快取，下一次呼叫會重打。
  static Future<List<ContentCategory>> fetch(
    CategoryModule m, {
    bool refresh = false,
  }) {
    if (!refresh) {
      final cached = _cache[m];
      if (cached != null) return Future.value(cached);
      final pending = _inflight[m];
      if (pending != null) return pending;
    }
    final seq = ++_seq;
    final request = _load(m, seq);
    _inflight[m] = request;
    request.then<void>((_) {}, onError: (_) {}).whenComplete(() {
      if (identical(_inflight[m], request)) _inflight.remove(m);
    });
    return request;
  }

  static Future<List<ContentCategory>> _load(CategoryModule m, int seq) async {
    final json = await ApiClient.get(m.path);
    // 少了 categories 就當格式錯誤丟出，不把空清單寫進快取當成「沒有分類」。
    final raw = json['categories'] as List<dynamic>;
    final list = List<ContentCategory>.unmodifiable(
      raw.map((e) => ContentCategory.fromJson(e as Map<String, dynamic>)),
    );
    if (seq <= _discardUpTo) return list;
    if (seq > (_cachedSeq[m] ?? 0)) {
      _cache[m] = list;
      _cachedSeq[m] = seq;
      return list;
    }
    // 較新的請求已經先回來了：回傳較新的結果，讓呼叫端不會拿到過時的清單。
    return _cache[m] ?? list;
  }

  /// 同步取顯示名稱：快取 → 內建預設對照（文章、影音）→ [value] 本身。
  static String labelOf(CategoryModule m, String value) {
    for (final c in _cache[m] ?? const <ContentCategory>[]) {
      if (c.value == value) return c.label;
    }
    if (m != CategoryModule.events) {
      final fallback = _defaultArticleVideoLabels[value];
      if (fallback != null) return fallback;
    }
    return value;
  }

  /// 同步取後端設定的分類顏色：只查快取，清單沒抓到、沒這個分類、或沒設顏色都回 null。
  /// 沒有預設對照：預設色屬於各畫面的視覺，由呼叫端決定。
  static Color? colorOf(CategoryModule m, String value) {
    for (final c in _cache[m] ?? const <ContentCategory>[]) {
      if (c.value == value) return c.displayColor;
    }
    return null;
  }

  @visibleForTesting
  static void reset() {
    _cache.clear();
    _inflight.clear();
    _cachedSeq.clear();
    _discardUpTo = _seq;
  }
}
