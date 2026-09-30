// 活動各列表改用 limit＋cursor＋page_info：不再送 page／page_size，游標原字串帶回。

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/services/event_service.dart';

import '../helpers/widget_test_helpers.dart';

Map<String, dynamic> _event(int id) => {
  'id': id,
  'title': '活動 $id',
  'starts_at': '2026-12-01T10:00:00Z',
  'status': 'active',
  'effective_status': 'active',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(stubCommonChannels);
  tearDown(restoreHttp);

  late List<http.BaseRequest> seen;

  void respondWith(Map<String, dynamic> body) {
    seen = [];
    ApiClient.httpClient = MockClient((r) async {
      seen.add(r);
      return jsonResponse(body);
    });
  }

  final listEndpoints = <String, Future<EventPage> Function(String? cursor)>{
    '/api/events': (c) => EventService.fetchEvents(cursor: c),
    '/api/events/search': (c) => EventService.searchEvents(q: '祭', cursor: c),
    '/api/events/mine': (c) => EventService.fetchMyEvents(cursor: c),
    '/api/events/joined': (c) =>
        EventService.fetchJoinedEvents(tab: 'active', cursor: c),
    '/api/events/likes': (c) => EventService.fetchLikedEvents(cursor: c),
    '/api/events/bookmarks': (c) =>
        EventService.fetchBookmarkedEvents(cursor: c),
  };

  for (final MapEntry(key: path, value: fetch) in listEndpoints.entries) {
    test('$path 帶 cursor／limit 並讀 page_info', () async {
      respondWith({
        'total': 99,
        'page': 2,
        'events': [_event(1)],
        'page_info': {'next_cursor': '40', 'has_more': true},
      });

      final page = await fetch('20');

      final query = seen.single.url.queryParameters;
      expect(seen.single.url.path, path);
      expect(query['cursor'], '20');
      expect(query['limit'], '20');
      expect(query.containsKey('page'), isFalse);
      expect(query.containsKey('page_size'), isFalse);
      expect(page.events.single.id, 1);
      expect(page.pageInfo.nextCursor, '40');
    });
  }

  test('第一頁不帶 cursor；搜尋與我參加的保留各自的篩選條件', () async {
    respondWith({
      'events': <dynamic>[],
      'page_info': {'next_cursor': null, 'has_more': false},
    });

    await EventService.searchEvents(q: ' 祭 ', range: '1m', tribeId: 3);
    await EventService.fetchJoinedEvents(tab: 'ended');

    expect(seen[0].url.queryParameters, {
      'q': '祭',
      'range': '1m',
      'tribe_id': '3',
      'limit': '20',
    });
    expect(seen[1].url.queryParameters, {'tab': 'ended', 'limit': '20'});
  });
}
