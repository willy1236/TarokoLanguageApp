// 文章、影音的分類名稱（T-23）：清單抓回來前用內建對照，抓回來後用後端的 label，
// 後端新增、內建沒有的分類不再一律顯示「其他」。

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/models/article_models.dart';
import 'package:flutter_application_1/models/content_category.dart';
import 'package:flutter_application_1/models/video_models.dart';
import 'package:flutter_application_1/services/category_service.dart';
import 'package:http/testing.dart';

import '../helpers/widget_test_helpers.dart';

Map<String, dynamic> _cat(String value, String label) => {
  'value': value,
  'label': label,
  'sort_order': 10,
  'count': 1,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    stubCommonChannels();
    CategoryService.reset();
  });
  tearDown(CategoryService.reset);

  const defaults = {
    'tribal_intro': '部落宣傳',
    'cultural': '文化紀錄',
    'event': '活動紀錄',
    'education': '教學延伸',
    'other': '其他',
  };

  test('清單還沒抓回來時，預設 5 個分類名稱不變', () {
    for (final e in defaults.entries) {
      expect(ArticleCategory.label(e.key), e.value);
      expect(VideoCategory.label(e.key), e.value);
    }
  });

  test('清單還沒抓回來時，不認得的分類顯示 value 本身而不是「其他」', () {
    expect(ArticleCategory.label('language'), 'language');
    expect(VideoCategory.label('language'), 'language');
  });

  test('清單抓回來後用後端的 label，文章與影音各查各的', () async {
    ApiClient.httpClient = MockClient((r) async {
      if (r.url.path == '/api/articles/categories') {
        return jsonResponse({
          'categories': [
            _cat('language', '族語教學'),
            _cat('cultural', '文化記錄（新）'),
          ],
        });
      }
      return jsonResponse({
        'categories': [_cat('music', '音樂')],
      });
    });
    await CategoryService.fetch(CategoryModule.articles);
    await CategoryService.fetch(CategoryModule.videos);

    expect(ArticleCategory.label('language'), '族語教學');
    expect(ArticleCategory.label('cultural'), '文化記錄（新）');
    expect(ArticleCategory.label('music'), 'music');
    expect(VideoCategory.label('music'), '音樂');
    expect(VideoCategory.label('language'), 'language');
    // 快取裡沒有、內建有的仍用內建對照。
    expect(VideoCategory.label('education'), '教學延伸');
  });
}
