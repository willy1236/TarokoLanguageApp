import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 全域字體樣式 tokens — 太魯閣設計系統唯一字級/字族/字重來源
///
/// 字級規則：
/// - 字級常數（`micro`/`caption`/.../`headline`）一律是**一般模式**字級，
///   全部為偶數、級距 2，一般模式最小 10。
/// - 精簡模式 = 一般模式 + [seniorStep]（2），因此精簡模式最小 12。
///   用 [size] 取得依模式換算後的字級，不要再手寫 `seniorMode ? 16 : 13`。
///
/// 兩種用法：
/// 1. `AppTypography.size(AppTypography.body, seniorMode: seniorMode)`：只需要 fontSize 時。
/// 2. `*Style()` 方法：跟 [AppColors] 同等地位的全域可直接套用樣式，
///    內建字族＋字重＋雙字級，取代逐處手寫
///    `GoogleFonts.notoSerifTc(fontSize: ..., fontWeight: ...)` 的重複組合。
abstract class AppTypography {
  // ── 一般模式字級（由小到大，偶數、級距 2）──────────────────────
  static const double micro = 10; // 徽章、日期方塊等極小標籤
  static const double caption = 12; // 輔助說明文字
  static const double body = 14; // 內文次要
  static const double bodyLarge = 16; // 內文主要
  static const double subtitle = 18; // 次標題
  static const double title = 20; // 標題
  static const double headline = 22; // 大標題

  // ── 展示字級（特例視覺：emoji、分數、頭像字母等大字，不套 seniorStep）──
  static const double display24 = 24;
  static const double display26 = 26;
  static const double display28 = 28;
  static const double display30 = 30;
  static const double display32 = 32;
  static const double display36 = 36;
  static const double display40 = 40;
  static const double display44 = 44;

  /// 精簡模式相對一般模式放大的字級
  static const double seniorStep = 2;

  /// 依模式換算字級：精簡模式 = [base] + [seniorStep]
  static double size(double base, {bool seniorMode = false}) => seniorMode ? base + seniorStep : base;

  // ── 字族 builder ─────────────────────────────────────────
  // 沒有對應 *Style() 角色的組合用這組，參數與 GoogleFonts 同名；字級請傳代幣。
  /// notoSerifTc：標題、強調文字
  static TextStyle serif({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
    FontStyle? fontStyle,
    List<Shadow>? shadows,
  }) => GoogleFonts.notoSerifTc(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
    fontStyle: fontStyle,
    shadows: shadows,
  );

  /// notoSansTc：內文
  static TextStyle sans({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
    FontStyle? fontStyle,
    List<Shadow>? shadows,
  }) => GoogleFonts.notoSansTc(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
    fontStyle: fontStyle,
    shadows: shadows,
  );

  /// crimsonPro：族語拼音／拉丁展示字
  static TextStyle latin({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
    FontStyle? fontStyle,
    List<Shadow>? shadows,
  }) => GoogleFonts.crimsonPro(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
    fontStyle: fontStyle,
    shadows: shadows,
  );

  /// jetBrainsMono：數字、代碼等等寬字
  static TextStyle mono({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
    FontStyle? fontStyle,
    List<Shadow>? shadows,
  }) => GoogleFonts.jetBrainsMono(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
    fontStyle: fontStyle,
    shadows: shadows,
  );

  // ── 全域樣式（字族＋字重＋雙字級）──────────────────────────
  // 方法名稱代表字族／字重的「角色」，不代表字級排名；各角色的一般模式字級沿用
  // 原設計（標在各方法註解），精簡模式同樣 +[seniorStep]。
  // notoSerifTc + w700：大標題／強調數字（20）
  static TextStyle headlineStyle({bool seniorMode = false, Color? color}) => GoogleFonts.notoSerifTc(
    fontSize: size(title, seniorMode: seniorMode),
    fontWeight: FontWeight.w700,
    color: color,
  );

  // notoSerifTc + w600（大字）：畫面主標題（16）
  static TextStyle titleStyle({bool seniorMode = false, Color? color}) => GoogleFonts.notoSerifTc(
    fontSize: size(bodyLarge, seniorMode: seniorMode),
    fontWeight: FontWeight.w600,
    color: color,
  );

  // notoSerifTc + w600（小字）：次標題／tab 標籤，最常見的樣式群（12）
  static TextStyle subtitleStyle({bool seniorMode = false, Color? color}) => GoogleFonts.notoSerifTc(
    fontSize: size(caption, seniorMode: seniorMode),
    fontWeight: FontWeight.w600,
    color: color,
  );

  // notoSansTc, regular：內文主要（14）
  static TextStyle bodyLargeStyle({bool seniorMode = false, Color? color}) => GoogleFonts.notoSansTc(
    fontSize: size(body, seniorMode: seniorMode),
    color: color,
  );

  // notoSansTc, regular：內文次要（12）
  static TextStyle bodyStyle({bool seniorMode = false, Color? color}) => GoogleFonts.notoSansTc(
    fontSize: size(caption, seniorMode: seniorMode),
    color: color,
  );

  // notoSansTc, regular（更小字）：輔助說明文字（10）
  static TextStyle captionStyle({bool seniorMode = false, Color? color}) => GoogleFonts.notoSansTc(
    fontSize: size(micro, seniorMode: seniorMode),
    color: color,
  );

  // crimsonPro + italic：族語拉丁拼音專用（10）
  static TextStyle romanized({bool seniorMode = false, Color? color}) => GoogleFonts.crimsonPro(
    fontSize: size(micro, seniorMode: seniorMode),
    fontStyle: FontStyle.italic,
    color: color,
  );
}
