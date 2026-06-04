import 'package:flutter/material.dart';

/// 全域色票 — 太魯閣設計系統唯一顏色來源（對應 design-tokens.jsx TRUKU_COLORS）
abstract class AppColors {
  // ── 主色：苧麻染紅 / 太魯閣紅褐 ────────────────────────────
  static const Color primary = Color(0xFF7A1F1A);
  static const Color primaryDeep = Color(0xFF4A0F0C);
  static const Color primaryLight = Color(0xFFA8463E);

  // ── 黑（織布經線）───────────────────────────────────────────
  static const Color ink = Color(0xFF1C0F0D);
  static const Color inkSoft = Color(0xFF3A2520);

  // ── 米白（苧麻原色）─────────────────────────────────────────
  static const Color cream = Color(0xFFF2E8D5);
  static const Color creamLight = Color(0xFFFAF5EA);
  static const Color creamDeep = Color(0xFFE8DBC0);

  // ── 山林苔綠 ─────────────────────────────────────────────────
  static const Color moss = Color(0xFF3D5A3D);
  static const Color mossDeep = Color(0xFF1F3220);

  // ── 傳統珠飾金 ───────────────────────────────────────────────
  static const Color gold = Color(0xFFC9A961);
  static const Color goldDeep = Color(0xFF8E7234);

  // ── 深底（暗色畫面背景）──────────────────────────────────────
  static const Color midnight = Color(0xFF1C0F0D);
  static const Color midnightSoft = Color(0xFF2A1A15);

  // ── 灰階 ─────────────────────────────────────────────────────
  static const Color fog = Color(0xFFA89C88);
  static const Color mist = Color(0xFFD4C9B5);

  // ── 相容別名（暗色主題佈局用）───────────────────────────────
  static const Color background = midnight;
  static const Color surface = midnightSoft;
  static const Color surfaceVariant = inkSoft;

  // ── 狀態色 ───────────────────────────────────────────────────
  static const Color danger = Color(0xFFEF4444);
  static const Color dangerDark = Color(0xFFB91C1C);

  // ── 強調色（圖示 / 標籤 / 統計）────────────────────────────
  static const Color rose = Color(0xFFFB7185);
  static const Color orangeLight = Color(0xFFFB923C);
  static const Color amber = Color(0xFFF59E0B);
  static const Color blue = Color(0xFF3B82F6);
  static const Color blueLight = Color(0xFF60A5FA);
  static const Color purple = Color(0xFFA855F7);
  static const Color greenLight = Color(0xFF4ADE80);

  // ── 線上狀態 ─────────────────────────────────────────────────
  static const Color online = Color(0xFF5BC97D);
  static const Color offline = fog;
  static const Color recording = Color(0xFFFF4444);
}
