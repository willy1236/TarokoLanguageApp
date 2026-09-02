import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 全域字體樣式 tokens — 太魯閣設計系統唯一字級/字族/字重來源
///
/// 兩種用法：
/// 1. Raw 字級常數（`caption`/`body`/.../`headline`）：既有畫面在
///    `seniorMode ? AppTypography.x : <原始字級數字>` 這種手動放大寫法中使用，
///    只替換 fontSize；main.dart 的全域 textTheme 也是以此為 fontSize 基準。
///    這組維持原樣，供既有程式碼相容使用。
/// 2. `*Style()` 方法（新增）：跟 [AppColors] 同等地位的全域可直接套用樣式，
///    內建字族＋字重＋（一般／精簡模式）雙字級，取代逐處手寫
///    `GoogleFonts.notoSerifTc(fontSize: ..., fontWeight: ...)` 的重複組合。
abstract class AppTypography {
  // ── 字級（由小到大）──────────────────────────────────────────
  static const double caption = 11; // 輔助說明文字
  static const double body = 13; // 內文次要
  static const double bodyLarge = 14; // 內文主要（畫面中最常見的基準字級）
  static const double subtitle = 16; // 次標題
  static const double title = 18; // 標題
  static const double headline = 22; // 大標題

  // ── 一般模式（非精簡）基準字級 ──────────────────────────────
  static const double _baseCaption = 10;
  static const double _baseBody = 11;
  static const double _baseBodyLarge = 13;
  static const double _baseSubtitle = 12;
  static const double _baseTitle = 15;
  static const double _baseHeadline = 20;
  static const double _baseRomanized = 10;
  static const double _seniorRomanized = 12;

  // ── 全域樣式（字族＋字重＋雙字級）──────────────────────────
  // notoSerifTc + w700：大標題／強調數字
  static TextStyle headlineStyle({bool seniorMode = false, Color? color}) => GoogleFonts.notoSerifTc(
    fontSize: seniorMode ? headline : _baseHeadline,
    fontWeight: FontWeight.w700,
    color: color,
  );

  // notoSerifTc + w600（大字）：畫面主標題
  static TextStyle titleStyle({bool seniorMode = false, Color? color}) => GoogleFonts.notoSerifTc(
    fontSize: seniorMode ? title : _baseTitle,
    fontWeight: FontWeight.w600,
    color: color,
  );

  // notoSerifTc + w600（小字）：次標題／tab 標籤，最常見的樣式群
  static TextStyle subtitleStyle({bool seniorMode = false, Color? color}) => GoogleFonts.notoSerifTc(
    fontSize: seniorMode ? subtitle : _baseSubtitle,
    fontWeight: FontWeight.w600,
    color: color,
  );

  // notoSansTc, regular：內文主要
  static TextStyle bodyLargeStyle({bool seniorMode = false, Color? color}) => GoogleFonts.notoSansTc(
    fontSize: seniorMode ? bodyLarge : _baseBodyLarge,
    color: color,
  );

  // notoSansTc, regular：內文次要
  static TextStyle bodyStyle({bool seniorMode = false, Color? color}) => GoogleFonts.notoSansTc(
    fontSize: seniorMode ? body : _baseBody,
    color: color,
  );

  // notoSansTc, regular（更小字）：輔助說明文字
  static TextStyle captionStyle({bool seniorMode = false, Color? color}) => GoogleFonts.notoSansTc(
    fontSize: seniorMode ? caption : _baseCaption,
    color: color,
  );

  // crimsonPro + italic：族語拉丁拼音專用
  static TextStyle romanized({bool seniorMode = false, Color? color}) => GoogleFonts.crimsonPro(
    fontSize: seniorMode ? _seniorRomanized : _baseRomanized,
    fontStyle: FontStyle.italic,
    color: color,
  );
}
