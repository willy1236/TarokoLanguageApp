import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 在 BirthDateField 開日期選擇器，選 [year] 年目前月份的 [day] 日後按確定。
/// 選擇器先開在年份清單（initialDatePickerMode: year）。
Future<void> pickBirthDate(
  WidgetTester tester, {
  int year = 2000,
  int day = 15,
}) async {
  await tester.tap(find.text('請選擇出生日期'));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.text('$year'),
    -100,
    scrollable: find.descendant(
      of: find.byType(YearPicker),
      matching: find.byType(Scrollable),
    ),
  );
  await tester.tap(find.text('$year'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('$day'));
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}
