// 搜尋功能的時間區間選項，對應後端 backend/searchQuery.ts 的 RANGE_VALUES。
// 影音/文章/活動/論壇四個模組的搜尋端點共用同一組值。
class SearchRange {
  static const values = ['7d', '1m', '3m', '6m', '1y'];

  static String label(String range) => switch (range) {
    '7d' => '最近 7 天',
    '1m' => '最近 1 個月',
    '3m' => '最近 3 個月',
    '6m' => '最近半年',
    '1y' => '最近 1 年',
    _ => range,
  };
}
