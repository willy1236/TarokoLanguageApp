// ContentCategory 的 color（分類顏色 T-01）：活動分類帶 `#RRGGBB`，null 或格式不對都退回預設色。

import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/models/content_category.dart';

import '../helpers/fixtures.dart';

Map<String, dynamic> _json([Map<String, dynamic> extra = const {}]) => {
  'value': '族語',
  'label': '族語',
  'sort_order': 10,
  'count': 3,
  ...extra,
};

void main() {
  test('color 為 #RRGGBB 時保留字串，displayColor 轉成不透明的 Color', () {
    final c = ContentCategory.fromJson(_json({'color': '#7A1F1A'}));

    expect(c.color, '#7A1F1A');
    expect(c.displayColor, const Color(0xFF7A1F1A));
  });

  test('color 為 null 或缺欄位時 displayColor 為 null', () {
    expect(ContentCategory.fromJson(_json({'color': null})).color, isNull);
    expect(
      ContentCategory.fromJson(_json({'color': null})).displayColor,
      isNull,
    );
    expect(ContentCategory.fromJson(_json()).color, isNull);
    expect(ContentCategory.fromJson(_json()).displayColor, isNull);
  });

  test('格式不對時保留原字串、displayColor 為 null，不丟例外', () {
    for (final bad in ['red', '#FFF', '7A1F1A', '#7A1F1AFF', '#GGGGGG', '']) {
      final c = ContentCategory.fromJson(_json({'color': bad}));
      expect(c.color, bad, reason: bad);
      expect(c.displayColor, isNull, reason: bad);
    }
    // 型別不對也當沒設，不讓整份清單失敗。
    expect(ContentCategory.fromJson(_json({'color': 123})).color, isNull);
  });

  test('parseHexColor 大小寫都收', () {
    expect(parseHexColor('#3d5a3d'), const Color(0xFF3D5A3D));
    expect(parseHexColor('#3D5A3D'), const Color(0xFF3D5A3D));
    expect(parseHexColor(null), isNull);
  });

  test('文章、影音清單沒有 color，其他欄位解析不變', () {
    for (final f in [
      'get_api_articles_categories.json',
      'get_api_videos_categories.json',
    ]) {
      final raw = loadFixtureMap(f)['categories'] as List<dynamic>;
      final list = raw
          .map((e) => ContentCategory.fromJson(e as Map<String, dynamic>))
          .toList();
      expect(list, isNotEmpty, reason: f);
      for (var i = 0; i < list.length; i++) {
        final json = raw[i] as Map<String, dynamic>;
        expect(list[i].value, json['value'], reason: f);
        expect(list[i].label, json['label'], reason: f);
        expect(list[i].sortOrder, json['sort_order'], reason: f);
        expect(list[i].color, isNull, reason: f);
        expect(list[i].displayColor, isNull, reason: f);
      }
    }
  });
}
