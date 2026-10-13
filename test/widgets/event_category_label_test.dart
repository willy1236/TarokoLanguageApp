// 活動卡片與詳情頁頂部顯示的是分類名稱（label），不是送出用的 value。
// 管理員在後台把分類改名後 value 不變、名稱會變，篩選列、發起頁、卡片、詳情要一致。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/models/content_category.dart';
import 'package:flutter_application_1/models/event_model.dart';
import 'package:flutter_application_1/screens/events/widgets/event_cards.dart';
import 'package:flutter_application_1/screens/events/widgets/event_detail_hero.dart';
import 'package:flutter_application_1/services/category_service.dart';

import '../helpers/widget_test_helpers.dart';

Map<String, Object?> _json({String category = '工藝'}) => {
  'id': 1,
  'title': '苧麻織布',
  'starts_at': '2099-12-01T10:00:00Z',
  'status': 'active',
  'effective_status': 'active',
  'registration_open': true,
  'category': category,
};

/// 後端分類表：value「工藝」已被改名為「傳統工藝」。
Future<void> _loadRenamedCategories() async {
  installMockClient({
    '/api/events/categories': {
      'categories': [
        {'value': '工藝', 'label': '傳統工藝', 'sort_order': 30, 'count': 1},
      ],
    },
  });
  await CategoryService.fetch(CategoryModule.events, refresh: true);
}

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

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

  group('活動列表的列', () {
    // EventList 跳過第一筆（第一筆是精選大卡），所以放兩筆。
    Widget list() {
      final e = EventSummary.fromJson(_json());
      return EventList(events: [e, e], seniorMode: false, onTap: (_) {});
    }

    testWidgets('分類改名後顯示新名稱', (tester) async {
      await _loadRenamedCategories();
      await tester.pumpWidget(_wrap(list()));

      expect(find.text('傳統工藝'), findsOneWidget);
      expect(find.text('工藝'), findsNothing);
    });

    testWidgets('分類清單還沒抓到：退回顯示 value', (tester) async {
      await tester.pumpWidget(_wrap(list()));

      expect(find.text('工藝'), findsOneWidget);
    });
  });

  group('詳情頁頂部', () {
    Widget hero() => _wrap(
      EventDetailHero(
        event: EventDetail.fromJson(_json()),
        seniorMode: false,
        onImagesChanged: (_) {},
      ),
    );

    testWidgets('分類改名後顯示新名稱', (tester) async {
      await _loadRenamedCategories();
      await tester.pumpWidget(hero());

      expect(find.text('傳統工藝'), findsOneWidget);
      expect(find.text('工藝'), findsNothing);
    });

    testWidgets('分類清單還沒抓到：退回顯示 value', (tester) async {
      await tester.pumpWidget(hero());

      expect(find.text('工藝'), findsOneWidget);
    });
  });
}
