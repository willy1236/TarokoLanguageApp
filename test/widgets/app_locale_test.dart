// App 語系要讓日期格式對到 zh_TW：一週從週日開始、星期寫「週」不是簡體「周」。
// 語系若帶 Hant（zh_Hant_TW），intl 找不到這組日期格式會退回 zh（簡體、週一開頭）。

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/main.dart' show appLocale;

void main() {
  Future<void> openDatePicker(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: appLocale,
        supportedLocales: const [appLocale],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDatePicker(
              context: context,
              // 2026/10/02 是週五。
              initialDate: DateTime(2026, 10, 2),
              firstDate: DateTime(2026, 1, 1),
              lastDate: DateTime(2026, 12, 31),
            ),
            child: const Text('OPEN'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
  }

  testWidgets('一週從週日開始', (tester) async {
    await openDatePicker(tester);
    final context = tester.element(find.byType(CalendarDatePicker));
    final l10n = MaterialLocalizations.of(context);
    expect(l10n.firstDayOfWeekIndex, 0);

    // 星期列由左到右，第一格是「日」。
    final headers = ['日', '一', '二', '三', '四', '五', '六'];
    final xs = [
      for (final h in headers)
        tester
            .getCenter(
              find.descendant(
                of: find.byType(CalendarDatePicker),
                matching: find.text(h),
              ),
            )
            .dx,
    ];
    final sorted = [...xs]..sort();
    expect(xs, sorted);
  });

  testWidgets('日期選擇器標題的星期寫「週」，不是簡體「周」', (tester) async {
    await openDatePicker(tester);
    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .where((s) => s.contains('10月2日'));
    expect(texts, isNotEmpty);
    expect(texts.any((s) => s.contains('週')), isTrue, reason: '$texts');
    expect(texts.any((s) => s.contains('周')), isFalse, reason: '$texts');
  });
}
