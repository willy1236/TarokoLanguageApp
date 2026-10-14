// 活動列表一般列的日期方塊與分類標籤底色（分類顏色 T-02）：
// 分類清單有 color 時用後端的顏色，沒抓到或 color 為 null 時沿用內建對照。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/models/content_category.dart';
import 'package:flutter_application_1/models/event_model.dart';
import 'package:flutter_application_1/screens/events/widgets/event_cards.dart';
import 'package:flutter_application_1/services/category_service.dart';

import '../helpers/widget_test_helpers.dart';

EventSummary _event(String category) => EventSummary.fromJson({
  'id': 1,
  'title': '苧麻織布',
  'starts_at': '2099-12-01T10:00:00Z',
  'status': 'active',
  'effective_status': 'active',
  'registration_open': true,
  'category': category,
});

/// 後端預設分類的顏色（API/活動提醒.md §1.0），應與內建對照相同。
const _serverDefaults = {
  '走讀': '#3D5A3D',
  '線上': '#3D5A3D',
  '工藝': '#8E7234',
  '族語': '#7A1F1A',
  '音樂': '#7A1F1A',
  '其他': '#3A2520',
};

Future<void> _loadCategories(Map<String, String?> colors) async {
  installMockClient({
    '/api/events/categories': {
      'categories': [
        for (final MapEntry(:key, :value) in colors.entries)
          {
            'value': key,
            'label': key,
            'sort_order': 10,
            'count': 1,
            'color': value,
          },
      ],
    },
  });
  await CategoryService.fetch(CategoryModule.events, refresh: true);
}

/// 渲染一般列（EventList 跳過第一筆精選大卡，所以放兩筆），回傳日期方塊與分類標籤的底色。
Future<({Color dateBox, Color chip})> _colors(
  WidgetTester tester,
  String category,
) async {
  final e = _event(category);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: EventList(events: [e, e], seniorMode: false, onTap: (_) {}),
        ),
      ),
    ),
  );
  BoxDecoration decorationAround(Finder f) => tester
      .widgetList<Container>(
        find.ancestor(of: f, matching: find.byType(Container)),
      )
      .map((c) => c.decoration)
      .whereType<BoxDecoration>()
      .first;
  final chip = decorationAround(find.text(category)).color!;
  // 日期方塊裡的「日」是米白字，往上第一個有底色的 Container 就是方塊。
  final day = find.byWidgetPredicate(
    (w) => w is Text && w.style?.color == AppColors.creamLight,
  );
  final dateBox = decorationAround(day.first).color!;
  return (dateBox: dateBox, chip: chip);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    stubCommonChannels();
    CategoryService.reset();
  });

  tearDown(() {
    restoreHttp();
    CategoryService.reset();
  });

  testWidgets('分類有 color 時日期方塊與分類標籤用後端的顏色', (tester) async {
    await _loadCategories({'工藝': '#1F3220'});

    final c = await _colors(tester, '工藝');

    expect(c.dateBox, AppColors.mossDeep);
    expect(c.chip, AppColors.mossDeep.withValues(alpha: 0.1));
  });

  testWidgets('新分類設了顏色就不再是 inkSoft', (tester) async {
    await _loadCategories({'打獵': '#4A0F0C'});

    expect((await _colors(tester, '打獵')).dateBox, AppColors.primaryDeep);
  });

  testWidgets('清單還沒抓到：沿用內建對照', (tester) async {
    expect((await _colors(tester, '工藝')).dateBox, AppColors.goldDeep);
    expect((await _colors(tester, '打獵')).dateBox, AppColors.inkSoft);
  });

  testWidgets('分類 color 為 null：沿用內建對照，新分類為 inkSoft', (tester) async {
    await _loadCategories({'工藝': null, '打獵': null});

    expect((await _colors(tester, '工藝')).dateBox, AppColors.goldDeep);
    expect((await _colors(tester, '打獵')).dateBox, AppColors.inkSoft);
  });

  testWidgets('後端預設分類的顏色與改動前的內建對照完全相同', (tester) async {
    final before = <String, ({Color dateBox, Color chip})>{};
    for (final category in _serverDefaults.keys) {
      before[category] = await _colors(tester, category);
    }

    await _loadCategories(_serverDefaults);

    for (final category in _serverDefaults.keys) {
      expect(
        await _colors(tester, category),
        before[category],
        reason: category,
      );
    }
  });
}
