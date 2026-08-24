/// 精簡模式資訊密度上限 tokens — 定義精簡畫面允許同時呈現的資料量上限，
/// 而非只是把既有版面等比放大。
abstract class AppDensity {
  /// 列表卡片（如論壇貼文卡、活動卡）在精簡模式下最多顯示的欄位數。
  static const int maxListCardFields = 3;

  /// 首頁在精簡模式下最多顯示的區塊數。
  static const int maxHomeSections = 4;
}
