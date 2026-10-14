// CategoryService（T-21）：分類清單的快取、共用進行中的請求、失敗重試，以及 labelOf 的查找順序。

import 'dart:async';
import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/models/content_category.dart';
import 'package:flutter_application_1/services/category_service.dart';

import '../helpers/widget_test_helpers.dart';

Map<String, dynamic> _cat(String value, String label, int sort, int count) => {
  'value': value,
  'label': label,
  'sort_order': sort,
  'count': count,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<http.BaseRequest> seen;

  void respondWith(FutureOr<http.Response> Function() respond) {
    seen = [];
    ApiClient.httpClient = MockClient((r) async {
      seen.add(r);
      return respond();
    });
  }

  setUp(() {
    stubCommonChannels();
    CategoryService.reset();
  });
  tearDown(() {
    CategoryService.reset();
    restoreHttp();
  });

  group('fetch', () {
    test('解析 { categories: [...] }，照後端順序、含 count 0', () async {
      respondWith(
        () => jsonResponse({
          'categories': [_cat('族語', '族語', 10, 3), _cat('其他', '其他', 1000, 0)],
        }),
      );

      final list = await CategoryService.fetch(CategoryModule.events);

      expect(seen.single.url.path, '/api/events/categories');
      expect(list.map((c) => c.value), ['族語', '其他']);
      expect(list.first.label, '族語');
      expect(list.first.sortOrder, 10);
      expect(list.first.count, 3);
      expect(list.last.count, 0);
    });

    test('三個模組各打自己的端點', () async {
      respondWith(() => jsonResponse({'categories': []}));

      for (final m in CategoryModule.values) {
        await CategoryService.fetch(m);
      }

      expect(seen.map((r) => r.url.path), [
        '/api/events/categories',
        '/api/articles/categories',
        '/api/videos/categories',
      ]);
    });

    test('第二次不打 API，refresh: true 才重打', () async {
      respondWith(
        () => jsonResponse({
          'categories': [_cat('cultural', '文化紀錄', 20, 1)],
        }),
      );

      await CategoryService.fetch(CategoryModule.articles);
      await CategoryService.fetch(CategoryModule.articles);
      expect(seen, hasLength(1));

      await CategoryService.fetch(CategoryModule.articles, refresh: true);
      expect(seen, hasLength(2));
    });

    test('同時兩個呼叫只發一次請求', () async {
      final gate = Completer<void>();
      respondWith(() async {
        await gate.future;
        return jsonResponse({
          'categories': [_cat('走讀', '走讀', 20, 2)],
        });
      });

      final a = CategoryService.fetch(CategoryModule.events);
      final b = CategoryService.fetch(CategoryModule.events);
      gate.complete();
      final results = await Future.wait([a, b]);

      expect(seen, hasLength(1));
      expect(results[0].single.value, '走讀');
      expect(results[1].single.value, '走讀');
    });

    // 管理員新增分類後 refresh，不能拿到改動前發出、還沒回來的舊請求結果。
    test('refresh: true 不共用進行中的請求，較早發出的結果晚回來也不蓋掉新的', () async {
      final gates = <Completer<void>>[];
      final bodies = [
        {
          'categories': [_cat('族語', '族語', 10, 0)],
        },
        {
          'categories': [_cat('族語', '族語', 10, 0), _cat('祭儀', '祭儀', 100, 0)],
        },
      ];
      respondWith(() async {
        final i = gates.length;
        final gate = Completer<void>();
        gates.add(gate);
        await gate.future;
        return jsonResponse(bodies[i]);
      });

      final old = CategoryService.fetch(CategoryModule.events);
      await pumpEventQueue();
      final fresh = CategoryService.fetch(CategoryModule.events, refresh: true);
      await pumpEventQueue();
      final joiner = CategoryService.fetch(CategoryModule.events);
      expect(seen, hasLength(2), reason: 'refresh 要發新請求');

      gates[1].complete();
      expect((await fresh).map((c) => c.value), ['族語', '祭儀']);
      expect((await joiner).map((c) => c.value), [
        '族語',
        '祭儀',
      ], reason: '之後的一般呼叫共用最新的請求');

      gates[0].complete();
      expect((await old).map((c) => c.value), [
        '族語',
        '祭儀',
      ], reason: '舊請求晚回來時回傳較新的快取');
      final cached = await CategoryService.fetch(CategoryModule.events);
      expect(cached.map((c) => c.value), ['族語', '祭儀']);
      expect(seen, hasLength(2));
    });

    test('失敗時丟出例外、不寫入快取，下一次會重打', () async {
      var fail = true;
      respondWith(
        () => fail
            ? errorResponse('INTERNAL', status: 500)
            : jsonResponse({
                'categories': [_cat('education', '教學延伸', 40, 0)],
              }),
      );

      await expectLater(
        CategoryService.fetch(CategoryModule.videos),
        throwsA(isA<ApiException>()),
      );
      expect(
        CategoryService.labelOf(CategoryModule.videos, '新分類'),
        '新分類',
        reason: '失敗不應留下快取',
      );

      fail = false;
      final list = await CategoryService.fetch(CategoryModule.videos);
      expect(seen, hasLength(2));
      expect(list.single.value, 'education');
    });

    test('回應少了 categories 視為失敗，不把空清單寫進快取', () async {
      var body = <String, dynamic>{};
      respondWith(() => jsonResponse(body));

      await expectLater(
        CategoryService.fetch(CategoryModule.events),
        throwsA(anything),
      );

      body = {
        'categories': [_cat('工藝', '工藝', 30, 1)],
      };
      final list = await CategoryService.fetch(CategoryModule.events);
      expect(seen, hasLength(2));
      expect(list.single.value, '工藝');
    });
  });

  group('labelOf', () {
    test('還沒抓過清單時，預設 5 個文章／影音 value 回中文名稱', () {
      const expected = {
        'tribal_intro': '部落宣傳',
        'cultural': '文化紀錄',
        'event': '活動紀錄',
        'education': '教學延伸',
        'other': '其他',
      };
      for (final m in [CategoryModule.articles, CategoryModule.videos]) {
        for (final MapEntry(:key, :value) in expected.entries) {
          expect(CategoryService.labelOf(m, key), value, reason: '$m $key');
        }
      }
    });

    test('清單裡有的回後端 label（含改過名的預設分類）', () async {
      respondWith(
        () => jsonResponse({
          'categories': [
            _cat('cultural', '文化記錄（新名）', 20, 1),
            _cat('祭儀', '祭儀', 100, 0),
          ],
        }),
      );
      await CategoryService.fetch(CategoryModule.articles);

      expect(
        CategoryService.labelOf(CategoryModule.articles, 'cultural'),
        '文化記錄（新名）',
      );
      expect(CategoryService.labelOf(CategoryModule.articles, '祭儀'), '祭儀');
      expect(
        CategoryService.labelOf(CategoryModule.articles, 'education'),
        '教學延伸',
        reason: '清單沒有的仍走內建對照',
      );
      expect(
        CategoryService.labelOf(CategoryModule.videos, 'cultural'),
        '文化紀錄',
        reason: '模組之間不共用快取',
      );
    });

    test('都找不到時回 value 本身', () {
      expect(CategoryService.labelOf(CategoryModule.articles, '祭儀'), '祭儀');
      expect(CategoryService.labelOf(CategoryModule.events, '族語'), '族語');
      expect(
        CategoryService.labelOf(CategoryModule.events, 'cultural'),
        'cultural',
        reason: '活動沒有內建對照',
      );
    });
  });

  group('colorOf', () {
    test('只查快取：有設顏色回該色，沒設、格式不對、清單沒有、沒抓過都回 null', () async {
      expect(CategoryService.colorOf(CategoryModule.events, '族語'), isNull);

      respondWith(
        () => jsonResponse({
          'categories': [
            {..._cat('族語', '族語', 10, 3), 'color': '#7A1F1A'},
            {..._cat('打獵', '打獵', 100, 1), 'color': null},
            {..._cat('壞色', '壞色', 100, 1), 'color': 'red'},
          ],
        }),
      );
      await CategoryService.fetch(CategoryModule.events);

      expect(
        CategoryService.colorOf(CategoryModule.events, '族語'),
        const Color(0xFF7A1F1A),
      );
      expect(CategoryService.colorOf(CategoryModule.events, '打獵'), isNull);
      expect(CategoryService.colorOf(CategoryModule.events, '壞色'), isNull);
      expect(CategoryService.colorOf(CategoryModule.events, '工藝'), isNull);
      expect(
        CategoryService.colorOf(CategoryModule.articles, '族語'),
        isNull,
        reason: '模組之間不共用快取',
      );
    });
  });

  test('ContentCategory.fromJson 缺 label 時退回 value，數字缺少當 0', () {
    final c = ContentCategory.fromJson({'value': '音樂'});
    expect(c.label, '音樂');
    expect(c.sortOrder, 0);
    expect(c.count, 0);
  });
}
