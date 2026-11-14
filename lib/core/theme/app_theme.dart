import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';
import '../constants/app_typography.dart';

/// App 全域主題。
///
/// 絕大多數畫面是米白底（[AppColors.creamLight]／[AppColors.cream]），所以主題是
/// light：沒寫顏色的 Text、TextField、Switch、Chip、對話框都會落在米白底配深字。
/// 深色區塊（今日進度卡、個人頁 header、學習影音 header、[AppDialog]、視訊、登入、
/// splash）都明確寫了自己的顏色，不吃主題預設。
abstract class AppTheme {
  static ThemeData get light => build();

  /// [useGoogleFonts] 只給測試關掉，避免測試期間去抓字型。
  static ThemeData build({bool useGoogleFonts = true}) {
    const scheme = ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: AppColors.creamLight,
      secondary: AppColors.inkSoft,
      onSecondary: AppColors.creamLight,
      // FilterChip 選中、SegmentedButton 選中等「選取」狀態用的容器色。
      secondaryContainer: AppColors.primary,
      onSecondaryContainer: AppColors.creamLight,
      error: AppColors.dangerDark,
      onError: AppColors.creamLight,
      surface: AppColors.creamLight,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.inkMuted,
      outline: AppColors.inkMuted,
      outlineVariant: AppColors.mist,
      inverseSurface: AppColors.inkSoft,
      onInverseSurface: AppColors.creamLight,
      surfaceContainerHighest: AppColors.creamDeep,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.creamLight,
      canvasColor: AppColors.creamLight,
      primaryColor: AppColors.primary,
      hintColor: AppColors.inkMuted,
      dividerColor: AppColors.mist,
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.creamLight,
        surfaceTintColor: Colors.transparent,
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: AppColors.creamLight,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.creamLight,
        surfaceTintColor: Colors.transparent,
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.primary,
        selectionColor: AppColors.mist,
        selectionHandleColor: AppColors.primary,
      ),
      textTheme: useGoogleFonts
          ? GoogleFonts.notoSansTcTextTheme(_textTheme)
          : _textTheme,
    );
  }

  static const _textTheme = TextTheme(
    bodySmall: TextStyle(fontSize: AppTypography.caption, color: AppColors.ink),
    bodyMedium: TextStyle(fontSize: AppTypography.body, color: AppColors.ink),
    bodyLarge: TextStyle(
      fontSize: AppTypography.bodyLarge,
      color: AppColors.ink,
    ),
    titleSmall: TextStyle(
      fontSize: AppTypography.subtitle,
      color: AppColors.ink,
    ),
    titleMedium: TextStyle(fontSize: AppTypography.title, color: AppColors.ink),
    titleLarge: TextStyle(
      fontSize: AppTypography.headline,
      color: AppColors.ink,
    ),
  );
}
