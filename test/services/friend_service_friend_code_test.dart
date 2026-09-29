// 指定其他使用者一律用好友碼：路徑與 body 都不再帶 uid。

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/services/directed_call_service.dart';
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

  test('解除好友、封鎖、解除封鎖、羈絆展示都以好友碼指定', () async {
    respond({
      '/api/friends/BBBB2345': {'ok': true},
      '/api/friends/blocks': jsonResponse({'blocked': true}, status: 201),
      '/api/friends/blocks/BBBB2345': {'ok': true},
      '/api/friends/BBBB2345/showcase': {
        'mine': true,
        'theirs': false,
        'mutual': false,
      },
    });

    await FriendService.removeFriend('BBBB2345');
    await FriendService.blockUser('BBBB2345');
    await FriendService.unblockUser('BBBB2345');
    await FriendService.setShowcase('BBBB2345');
    await FriendService.unsetShowcase('BBBB2345');

    expect(seen.map((r) => '${r.method} ${r.url.path}'), [
      'DELETE /api/friends/BBBB2345',
      'POST /api/friends/blocks',
      'DELETE /api/friends/blocks/BBBB2345',
      'POST /api/friends/BBBB2345/showcase',
      'DELETE /api/friends/BBBB2345/showcase',
    ]);
    expect(jsonDecode(seen[1].body), {'friend_code': 'BBBB2345'});
  });

  test('撥給好友打好友碼路徑', () async {
    respond({
      '/api/friends/BBBB2345/call': jsonResponse({
        'call_id': 123,
        'status': 'ringing',
      }, status: 201),
    });

    final callId = await DirectedCallService.callFriend('BBBB2345');

    expect(callId, 123);
    expect(seen.single.url.path, '/api/friends/BBBB2345/call');
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
