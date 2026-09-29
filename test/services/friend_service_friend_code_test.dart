// 指定其他使用者一律用好友碼：路徑與 body 都不再帶 uid。

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/services/friend_service.dart';

import '../helpers/widget_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<http.Request> seen;

  setUp(() {
    stubCommonChannels();
    seen = [];
  });
  tearDown(restoreHttp);

  void respond(Map<String, Object?> routes) =>
      installMockClient(routes, onRequest: seen.add);

  test('加好友只送好友碼', () async {
    respond({
      '/api/friends/requests': jsonResponse({'status': 'pending'}, status: 201),
    });

    await FriendService.sendRequest('BBBB2345');

    expect(jsonDecode(seen.single.body), {'friend_code': 'BBBB2345'});
  });

  test('接受、拒絕邀請打好友碼路徑', () async {
    respond({
      '/api/friends/requests/AAAA2345/accept': {'status': 'accepted'},
      '/api/friends/requests/AAAA2345/decline': {'ok': true},
      '/api/notifications/summary': {},
    });

    await FriendService.acceptRequest('AAAA2345');
    await FriendService.declineRequest('AAAA2345');

    expect(
      seen.map((r) => r.url.path),
      containsAll([
        '/api/friends/requests/AAAA2345/accept',
        '/api/friends/requests/AAAA2345/decline',
      ]),
    );
  });

  test('400 FRIEND_CODE_REQUIRED 帶出後端 message', () async {
    respond({
      '/api/friends/requests': errorResponse(
        'FRIEND_CODE_REQUIRED',
        message: '請改用好友碼指定對象（請更新 App）',
      ),
    });

    final error = await FriendService.sendRequest(
      'BBBB2345',
    ).then<Object?>((_) => null, onError: (Object e) => e);

    expect(error, isA<ApiException>());
    expect(apiErrorMessage(error), '請改用好友碼指定對象（請更新 App）');
  });
}
