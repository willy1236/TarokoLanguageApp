// 私訊歷史往上翻：帶上一頁 page_info.next_cursor 的原字串，到最早一則就停。

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/services/friend_service.dart';

import '../helpers/fixtures.dart';
import '../helpers/widget_test_helpers.dart';

Map<String, dynamic> _message(int id) => {
  'id': '$id',
  'mine': false,
  'body': '訊息 $id',
  'created_at': '2026-09-28T07:47:27.622Z',
  'read_at': null,
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

  test('最新一頁不帶 cursor，limit 照舊 30，讀 page_info 的字串游標', () async {
    respondWith({
      'messages': [_message(15)],
      'next_cursor': 15,
      'page_info': {'next_cursor': 'm:15', 'has_more': true},
    });

    final page = await FriendService.getMessages('BBBB2345');

    expect(seen.single.url.path, '/api/friends/BBBB2345/messages');
    expect(seen.single.url.queryParameters, {'limit': '30'});
    expect(page.messages.single.body, '訊息 15');
    expect(page.nextCursor, 'm:15');
  });

  test('往上翻時原樣帶回游標；has_more 為 false 就沒有下一頁', () async {
    respondWith({
      'messages': [_message(3)],
      'page_info': {'next_cursor': null, 'has_more': false},
    });

    final page = await FriendService.getMessages('BBBB2345', cursor: 'm:15');

    expect(seen.single.url.queryParameters, {'cursor': 'm:15', 'limit': '30'});
    expect(page.nextCursor, isNull);
  });

  test('partner：對象暫時無法使用時 unavailable 為 true，歷史訊息照給', () async {
    respondWith(loadSpecFixtureMap('get_api_friend_messages_unavailable.json'));

    final page = await FriendService.getMessages('CCCC2345');

    expect(page.partner!.unavailable, isTrue);
    expect(page.partner!.nickname, '暫時無法使用');
    expect(page.messages, hasLength(1));
  });

  test('partner：回應沒有 partner（封鎖關係）或沒有 unavailable 欄位時照常可用', () async {
    respondWith({
      'partner': null,
      'messages': [],
      'page_info': {'next_cursor': null, 'has_more': false},
    });
    expect((await FriendService.getMessages('BBBB2345')).partner, isNull);

    respondWith({
      'partner': {'nickname': '阿華', 'friend_code': 'BBBB2345'},
      'messages': [],
      'page_info': {'next_cursor': null, 'has_more': false},
    });
    final page = await FriendService.getMessages('BBBB2345');
    expect(page.partner!.unavailable, isFalse);
  });
}
