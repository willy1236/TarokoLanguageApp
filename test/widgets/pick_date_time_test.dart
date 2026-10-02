// pickDateTime：日期、時間依序選；時間固定 24 小時制，不受手機 12／24 小時設定影響。

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/main.dart' show appLocale;
import 'package:flutter_application_1/shared/utils/pick_date_time.dart';

void main() {
  DateTime? result;

  Widget app(DateTime initial) => MaterialApp(
    locale: appLocale,
    supportedLocales: const [appLocale],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    // 模擬手機設成 12 小時制。
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
      child: child!,
    ),
    home: Builder(
      builder: (context) => TextButton(
        onPressed: () async {
          result = await pickDateTime(
            context,
            initial: initial,
            firstDate: DateTime(2026, 9, 1),
            lastDate: DateTime(2026, 12, 31),
            dateHelp: '選擇日期',
            timeHelp: '選擇時間',
          );
        },
        child: const Text('OPEN'),
      ),
    ),
  );

  setUp(() => result = null);

  testWidgets('手機設 12 小時制，時間選擇器仍是 24 小時制、沒有上午下午', (tester) async {
    await tester.pumpWidget(app(DateTime(2026, 10, 2, 14, 5)));
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('確定'));
    await tester.pumpAndSettle();

    expect(find.text('選擇時間'), findsOneWidget);
    expect(find.text('14'), findsWidgets);
    expect(find.text('上午'), findsNothing);
    expect(find.text('下午'), findsNothing);

    await tester.tap(find.text('確定'));
    await tester.pumpAndSettle();
    expect(result, DateTime(2026, 10, 2, 14, 5));
  });

  testWidgets('取消日期：回 null，不開時間選擇器', (tester) async {
    await tester.pumpWidget(app(DateTime(2026, 10, 2, 14, 5)));
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(find.text('選擇時間'), findsNothing);
    expect(result, isNull);
  });

  testWidgets('初始日期早於可選範圍：日曆停在第一天，時間仍帶初始時分', (tester) async {
    await tester.pumpWidget(app(DateTime(2026, 8, 20, 9, 30)));
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('確定'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('確定'));
    await tester.pumpAndSettle();

    expect(result, DateTime(2026, 9, 1, 9, 30));
  });
}
