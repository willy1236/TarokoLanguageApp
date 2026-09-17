/// 圖示尺寸 tokens — 實機回報預設 20~24 太小、不好按且容易誤觸鄰近按鈕，
/// 統一由此放大，並以 [tapTarget] 保證觸控熱區。
abstract class AppIconSize {
  /// 標題列／工具列上的可點圖示（IconButton 為主）。
  static double action(bool seniorMode) => seniorMode ? 34 : 28;

  /// 卡片或列內的可點小圖示。
  static double inline(bool seniorMode) => seniorMode ? 30 : 22;

  /// 列尾的指示箭頭等次要圖示。
  static double chevron(bool seniorMode) => seniorMode ? 26 : 20;

  /// 最小觸控熱區（Material a11y 建議 48dp）。
  static const double tapTarget = 48;
}
