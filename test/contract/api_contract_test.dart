// 後端格式契約的離線防線。
//
// 做什麼：把 api_inspector 錄下來的「真實後端回應」餵進對應的 model.fromJson，
// 確認解析不丟例外。後端改欄位名或型別 → 重錄 fixture → 這裡就紅在確切的 model 上，
// 不必等實機點一遍才發現。
//
// 不需要裝置、不需要網路，可進 CI。
//
// fixture 還沒錄製時，該筆會 skip 而不是通過 —— 不要讓沒錄的端點看起來像有防護。
// 錄製方式見 integration_test/api_inspector_test.dart 檔頭。

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/models/article_models.dart';
import 'package:flutter_application_1/models/event_model.dart';
import 'package:flutter_application_1/models/forum_models.dart';
import 'package:flutter_application_1/models/level_info.dart';
import 'package:flutter_application_1/models/listening_models.dart';
import 'package:flutter_application_1/models/quiz_models.dart';
import 'package:flutter_application_1/models/shop_item.dart';
import 'package:flutter_application_1/models/terms_models.dart';
import 'package:flutter_application_1/models/user_model.dart';
import 'package:flutter_application_1/models/video_models.dart';
import 'package:flutter_application_1/services/account_service.dart';
import 'package:flutter_application_1/services/notification_summary_service.dart';

import '../helpers/fixtures.dart';

/// 一筆契約：fixture 檔名 + 怎麼把它解析成 model。
/// [parse] 丟例外就代表 app 在真實資料上會炸。
class _Contract {
  final String fixture;
  final String model;
  final void Function(Map<String, dynamic> json) parse;

  const _Contract(this.fixture, this.model, this.parse);
}

/// 把清單型回應的每一筆都解析一次。空清單不算通過也不算失敗（見下方 test）。
void Function(Map<String, dynamic>) _each(
  String key,
  void Function(Map<String, dynamic>) parseItem,
) {
  return (json) {
    final list = json[key] as List<dynamic>? ?? const [];
    for (final item in list) {
      parseItem(item as Map<String, dynamic>);
    }
  };
}

/// 部分端點包了 {data: {...}} 信封（service 端用 ApiClient.unwrapData 拆）。
Map<String, dynamic> _unwrap(Map<String, dynamic> json) =>
    (json['data'] as Map<String, dynamic>?) ?? json;

final List<_Contract> _contracts = [
  _Contract('get_api_me.json', 'UserModel', UserModel.fromJson),
  _Contract('get_api_levels.json', 'LevelInfo',
      _each('levels', LevelInfo.fromJson)),
  _Contract('get_api_shop_items.json', 'ShopItem',
      _each('items', ShopItem.fromJson)),
  _Contract('get_api_videos.json', 'VideoListResponse',
      VideoListResponse.fromJson),
  _Contract('get_api_videos_sort_popular.json', 'VideoListResponse(popular)',
      VideoListResponse.fromJson),
  _Contract('get_api_video_detail.json', 'VideoDetail', VideoDetail.fromJson),
  _Contract('get_api_video_detail_youtube.json', 'VideoDetail(youtube)',
      VideoDetail.fromJson),
  _Contract('get_api_videos_search_q_a_range_1m.json', 'VideoListResponse(search)',
      VideoListResponse.fromJson),
  _Contract('get_api_articles_search_q_a_range_1m.json', 'ArticleListResponse',
      ArticleListResponse.fromJson),
  _Contract('get_api_events_scope_all.json', 'EventSummary',
      _each('events', EventSummary.fromJson)),
  _Contract('get_api_events_search_q_a_range_1m.json', 'EventSummary(search)',
      _each('events', EventSummary.fromJson)),
  _Contract('get_api_event_detail.json', 'EventDetail', EventDetail.fromJson),
  _Contract('get_api_forum_search_q_a_range_1m.json', 'ForumPostPage',
      ForumPostPage.fromJson),
  _Contract('get_api_terms.json', 'TermsStatus', TermsStatus.fromJson),
  _Contract('get_api_account_status.json', 'AccountStatus',
      AccountStatus.fromJson),
  _Contract('get_api_notifications_summary.json', 'NotificationSummary',
      NotificationSummary.fromJson),
  _Contract('post_api_quiz_start.json', 'QuizSession',
      (json) => QuizSession.fromJson(_unwrap(json))),
  _Contract('post_api_listening_start.json', 'ListeningSession',
      (json) => ListeningSession.fromJson(_unwrap(json))),
];

void main() {
  group('後端回應契約（離線回放錄製的真實回應）', () {
    for (final c in _contracts) {
      test('${c.fixture} → ${c.model}', () {
        if (!hasFixture(c.fixture)) {
          markTestSkipped(
            '尚未錄製 ${c.fixture} —— 見 integration_test/api_inspector_test.dart 檔頭',
          );
          return;
        }
        // 解析丟例外 = 真實資料會讓 app 炸掉，讓例外原樣往上拋比包裝更好讀。
        c.parse(loadFixtureMap(c.fixture));
      });
    }
  });

  test('至少錄過一個 fixture（全空代表錄製流程沒跑或沒接上）', () {
    final recorded = _contracts.where((c) => hasFixture(c.fixture)).length;
    if (recorded == 0) {
      markTestSkipped(
        '尚未錄製任何 fixture。第一次請跑：\n'
        '  flutter test integration_test/api_inspector_test.dart -d <device> '
        '--dart-define=RECORD_FIXTURES=true > fixtures.log\n'
        '  dart run tool/extract_fixtures.dart fixtures.log',
      );
      return;
    }
    expect(recorded, greaterThan(0));
  });
}
