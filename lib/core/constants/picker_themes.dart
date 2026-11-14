import 'package:flutter/material.dart';

import 'app_colors.dart';

/// 日期／時間選擇器的主題。
///
/// 選擇器是深色對話框（與 AppDialog 同一套深色卡片），全域主題是 light，
/// 所以用 [builder] 在選擇器範圍內換成深色主題，不波及其他元件。
/// dark ColorScheme 的 primary 是深酒紅、onPrimary 預設是黑，選擇器的按鈕、
/// 選中日期、時鐘指針直接吃這兩個色，壓在深色底上幾乎看不見，
/// 所以另外在選擇器專屬的主題欄位改色。
abstract class PickerThemes {
  /// 給 `showDatePicker`／`showTimePicker` 的 `builder`。
  static Widget builder(BuildContext context, Widget? child) {
    final base = Theme.of(context);
    return Theme(
      data: base.copyWith(
        brightness: Brightness.dark,
        // 鍵盤輸入模式的輸入框字色取自 textTheme，light 主題的是 ink，壓在深底上看不到。
        textTheme: base.textTheme.apply(
          bodyColor: AppColors.creamLight,
          displayColor: AppColors.creamLight,
        ),
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primary,
          secondary: AppColors.surfaceVariant,
          surface: AppColors.surface,
        ),
        dialogTheme: const DialogThemeData(backgroundColor: AppColors.surface),
        datePickerTheme: date,
        timePickerTheme: time,
      ),
      child: child!,
    );
  }

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
    // 今天未選中：金色半透明底＋粗金框，壓在深色底上不用找；選中時與其他日子同為酒紅底。
    // 今天不在可選範圍（disabled）時交回預設的淡化樣式。
    todayForegroundColor: WidgetStateProperty.resolveWith(
      (states) =>
          states.contains(WidgetState.disabled) ? null : AppColors.creamLight,
    ),
    todayBackgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return AppColors.primaryLight;
      if (states.contains(WidgetState.disabled)) return null;
      return AppColors.gold.withValues(alpha: 0.3);
    }),
    todayBorder: const BorderSide(color: AppColors.gold, width: 1.5),
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
