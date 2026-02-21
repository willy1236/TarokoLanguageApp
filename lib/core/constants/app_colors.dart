import 'package:flutter/material.dart';

/// 全域色票 — 所有介面色彩的唯一來源
abstract class AppColors {
  // ── 背景層次 ──────────────────────────────────────────────
  /// 最底層 Scaffold 背景 (#020617)
  static const Color background = Color(0xFF020617);

  /// 卡片 / 面板背景 (#0F172A)
  static const Color surface = Color(0xFF0F172A);

  /// 輸入框 / 次要背景 (#1E293B)
  static const Color surfaceVariant = Color(0xFF1E293B);

  // ── 品牌色 ───────────────────────────────────────────────
  /// 主色：橙色 (#EA580C)
  static const Color primary = Color(0xFFEA580C);

  // ── 狀態色 ───────────────────────────────────────────────
  /// 危險 / 登出 (#EF4444)
  static const Color danger = Color(0xFFEF4444);

  /// 深紅 / 報名按鈕 (#B91C1C)
  static const Color dangerDark = Color(0xFFB91C1C);

  // ── 強調色（圖示 / 標籤 / 統計）────────────────────────────
  /// 玫瑰紅 — 祭典標籤 (#FB7185)
  static const Color rose = Color(0xFFFB7185);

  /// 淺橙 — 統計數字 (#FB923C)
  static const Color orangeLight = Color(0xFFFB923C);

  /// 琥珀 — 收藏圖示 (#F59E0B)
  static const Color amber = Color(0xFFF59E0B);

  /// 藍 — 進度圖示 (#3B82F6)
  static const Color blue = Color(0xFF3B82F6);

  /// 淺藍 — 統計數字 (#60A5FA)
  static const Color blueLight = Color(0xFF60A5FA);

  /// 紫 — 活動圖示 (#A855F7)
  static const Color purple = Color(0xFFA855F7);

  /// 淺綠 — 統計數字 (#4ADE80)
  static const Color greenLight = Color(0xFF4ADE80);
}
