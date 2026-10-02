import 'package:flutter/material.dart';
import 'app_colors.dart';

/// 日期／時間選擇器的主題。
///
/// 全域 ColorScheme 的 primary 是深酒紅、onPrimary 沿用 dark 預設的黑，
/// 選擇器的按鈕、選中日期、時鐘指針直接吃這兩個色，壓在深色對話框底上幾乎看不見。
/// 只在選擇器專屬的主題欄位改色，不動 ColorScheme，免得波及其他元件。
abstract class PickerThemes {
  // 確認鈕：米白底酒紅字，與只有文字的取消鈕拉開主次。
  static final ButtonStyle _confirm = TextButton.styleFrom(
    backgroundColor: AppColors.creamLight,
    foregroundColor: AppColors.primary,
    padding: const EdgeInsets.symmetric(horizontal: 20),
  );

  static final ButtonStyle _cancel = TextButton.styleFrom(
    foregroundColor: AppColors.creamLight,
  );

  static WidgetStateProperty<Color?> _whenSelected(
    Color selected, [
    Color? other,
  ]) => WidgetStateProperty.resolveWith(
    (states) => states.contains(WidgetState.selected) ? selected : other,
  );

  static final DatePickerThemeData date = DatePickerThemeData(
    confirmButtonStyle: _confirm,
    cancelButtonStyle: _cancel,
    dayForegroundColor: _whenSelected(AppColors.creamLight),
    dayBackgroundColor: _whenSelected(AppColors.primaryLight),
    todayForegroundColor: _whenSelected(AppColors.creamLight, AppColors.gold),
    todayBackgroundColor: _whenSelected(AppColors.primaryLight),
    todayBorder: const BorderSide(color: AppColors.gold),
    yearForegroundColor: _whenSelected(AppColors.creamLight),
    yearBackgroundColor: _whenSelected(AppColors.primaryLight),
  );

  // 時間選擇器的色欄位型別是 Color，要分狀態得傳 WidgetStateColor。
  static Color _timeWhenSelected(Color selected, Color other) =>
      WidgetStateColor.resolveWith(
        (states) => states.contains(WidgetState.selected) ? selected : other,
      );

  static final TimePickerThemeData time = TimePickerThemeData(
    confirmButtonStyle: _confirm,
    cancelButtonStyle: _cancel,
    hourMinuteColor: _timeWhenSelected(
      AppColors.primaryLight,
      AppColors.inkSoft,
    ),
    hourMinuteTextColor: AppColors.creamLight,
    dialBackgroundColor: AppColors.inkSoft,
    dialHandColor: AppColors.primaryLight,
    dialTextColor: AppColors.creamLight,
    dayPeriodColor: _timeWhenSelected(
      AppColors.primaryLight,
      Colors.transparent,
    ),
    dayPeriodTextColor: _timeWhenSelected(AppColors.creamLight, AppColors.mist),
    dayPeriodBorderSide: const BorderSide(color: AppColors.fog),
  );
}
