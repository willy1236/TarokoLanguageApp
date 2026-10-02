// 日期選擇器的「今天」配色：未選中要有看得到的底色，選中時與其他日子一樣是酒紅底。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/picker_themes.dart';

void main() {
  final theme = PickerThemes.date;

  test('今天未選中：金色半透明底、米白字、1.5 粗金框', () {
    final bg = theme.todayBackgroundColor!.resolve({})!;
    expect(bg.a, closeTo(0.3, 0.01));
    expect(bg.withValues(alpha: 1), AppColors.gold);
    expect(theme.todayForegroundColor!.resolve({}), AppColors.creamLight);
    expect(theme.todayBorder!.width, 1.5);
  });

  test('今天選中：與選中其他日子同底色', () {
    const selected = {WidgetState.selected};
    expect(
      theme.todayBackgroundColor!.resolve(selected),
      theme.dayBackgroundColor!.resolve(selected),
    );
  });

  test('今天不可選：交回預設樣式', () {
    const disabled = {WidgetState.disabled};
    expect(theme.todayBackgroundColor!.resolve(disabled), isNull);
    expect(theme.todayForegroundColor!.resolve(disabled), isNull);
  });
}
