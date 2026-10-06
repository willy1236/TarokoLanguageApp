// 影音、文章標題列的排序字：長輩點得到。
// 取代的人工重測：「在影音／文章總覽點『最新／熱門／本週熱門』，點字旁邊的空白也要能切換」。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/screens/culture/widgets/culture_cards.dart';

import '../../helpers/widget_test_helpers.dart';

const _options = [
  ('latest', '最新'),
  ('popular', '熱門'),
  ('weekly_popular', '本週熱門'),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<List<String>> pumpLabels(
    WidgetTester tester, {
    bool seniorMode = false,
  }) async {
    final changes = <String>[];
    await tester.pumpWidget(
      wrap(
        Center(
          child: CultureSortLabels(
            options: _options,
            selected: 'latest',
            seniorMode: seniorMode,
            onChanged: changes.add,
          ),
        ),
      ),
    );
    return changes;
  }

  /// 排序字外層那塊可點的範圍。
  Rect hitBox(WidgetTester tester, String label) => tester.getRect(
    find
        .ancestor(of: find.text(label), matching: find.byType(GestureDetector))
        .first,
  );

  for (final senior in [false, true]) {
    testWidgets('${senior ? '精簡' : '一般'}模式每個排序字的點擊範圍至少 44×44', (tester) async {
      await pumpLabels(tester, seniorMode: senior);
      for (final (_, label) in _options) {
        final box = hitBox(tester, label);
        expect(box.width, greaterThanOrEqualTo(44), reason: '「$label」太窄');
        expect(box.height, greaterThanOrEqualTo(44), reason: '「$label」太矮');
      }
    });
  }

  testWidgets('點字旁邊的空白也能切換排序', (tester) async {
    final changes = await pumpLabels(tester);
    final box = hitBox(tester, '熱門');
    final text = tester.getRect(find.text('熱門'));
    // 點範圍左上角：在字的外面、但仍在可點範圍內。
    final corner = box.topLeft + const Offset(1, 1);
    expect(text.contains(corner), isFalse);

    await tester.tapAt(corner);
    expect(changes, ['popular']);
  });

  testWidgets('點目前已選的排序不會觸發切換', (tester) async {
    final changes = await pumpLabels(tester);
    await tester.tap(find.text('最新'));
    expect(changes, isEmpty);
  });
}
