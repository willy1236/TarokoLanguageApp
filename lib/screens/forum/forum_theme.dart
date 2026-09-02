// 論壇畫面共用的淺色主題。
//
// App 的全域主題是為深色畫面設計的：colorScheme 是 ColorScheme.dark，textTheme 的
// bodyMedium 是 AppColors.creamLight（近白）。論壇整組畫面用的是 creamLight 米色底，
// 直接繼承會讓沒寫死顏色的文字、輸入提示、Chip、對話框全部變成白字或深色底，在米色
// 上看不清楚。
//
// 與其在每個畫面逐一補 style，這裡集中定義一次，由各論壇畫面包在最外層。
// 已經寫死顏色的元件（活動小卡、貼文卡片等）不受影響。

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';

ThemeData forumTheme(BuildContext context) {
  final base = Theme.of(context);
  return base.copyWith(
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: AppColors.creamLight,
      secondary: AppColors.moss,
      onSecondary: AppColors.creamLight,
      surface: AppColors.creamLight,
      onSurface: AppColors.ink,
      error: AppColors.danger,
    ),
    scaffoldBackgroundColor: AppColors.creamLight,
    canvasColor: AppColors.creamLight,
    hintColor: AppColors.fog,
    textTheme: GoogleFonts.notoSansTcTextTheme(
      base.textTheme,
    ).apply(bodyColor: AppColors.inkSoft, displayColor: AppColors.ink),
    inputDecorationTheme: const InputDecorationTheme(
      hintStyle: TextStyle(color: AppColors.fog),
      labelStyle: TextStyle(color: AppColors.fog),
      counterStyle: TextStyle(color: AppColors.fog, fontSize: 11),
      helperStyle: TextStyle(color: AppColors.fog),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: AppColors.creamLight,
      contentTextStyle: TextStyle(color: AppColors.inkSoft, fontSize: 15),
    ),
    popupMenuTheme: const PopupMenuThemeData(
      color: AppColors.creamLight,
      textStyle: TextStyle(color: AppColors.inkSoft, fontSize: 14),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.primary),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.primary,
      selectionColor: AppColors.mist,
      selectionHandleColor: AppColors.primary,
    ),
  );
}
