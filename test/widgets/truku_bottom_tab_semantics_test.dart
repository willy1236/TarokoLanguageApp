// 底部導覽的無障礙語意與觸控範圍。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/shared/widgets/truku_bottom_tab.dart';

Widget _tab({
  int current = 0,
  Map<int, int> badges = const {},
  bool senior = false,
}) => MaterialApp(
  home: Scaffold(
    bottomNavigationBar: TrukuBottomTab(
      currentIndex: current,
      onTap: (_) {},
      seniorMode: senior,
      badges: badges,
    ),
  ),
);

void main() {
  testWidgets('每格是 button，選中那格 selected，未讀數寫進 label', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_tab(current: 3, badges: {3: 5}));

    expect(
      tester.getSemantics(find.text('好友')),
      containsSemantics(
        label: '好友，5 則未讀',
        isButton: true,
        isSelected: true,
        hasTapAction: true,
      ),
    );
    expect(
      tester.getSemantics(find.text('首頁')),
      containsSemantics(
        label: '首頁',
        isButton: true,
        isSelected: false,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  for (final senior in [false, true]) {
    testWidgets('${senior ? '精簡' : '一般'}模式每格觸控範圍不小於 ${senior ? 56 : 48}dp', (
      tester,
    ) async {
      await tester.pumpWidget(_tab(senior: senior));
      final min = senior ? 56.0 : 48.0;
      for (final label in ['首頁', '學習影音', '廣場活動', '好友', '我的']) {
        final box = find
            .ancestor(
              of: find.text(label),
              matching: find.byType(GestureDetector),
            )
            .first;
        final size = tester.getSize(box);
        expect(size.width, greaterThanOrEqualTo(min), reason: label);
        expect(size.height, greaterThanOrEqualTo(min), reason: label);
      }
    });
  }
}
