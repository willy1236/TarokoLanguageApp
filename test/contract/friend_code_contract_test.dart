// 後端開關 FRIEND_CODE_ENFORCE 開啟後的回應格式契約：回應不再帶其他使用者的
// uid，App 一律以好友碼與 mine／is_host／is_caller 等旗標辨識對象。
//
// 開關還沒開、錄不到這個格式，fixture 取自規格文件的範例（test/fixtures/api_spec/）。

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/models/friend_model.dart';
import 'package:flutter_application_1/models/video_call_model.dart';

import '../helpers/fixtures.dart';

/// 開關開啟後回應裡不會再出現的「他人 uid」欄位（規格 00_核心與認證.md §0）。
const _removedUidKeys = {
  'uid',
  'peer_uid',
  'caller_uid',
  'callee_uid',
  'partner_uid',
  'sender_uid',
  'recipient_uid',
  'host_uid',
  'from_uid',
  'by_uid',
};

/// fixture 本身不能含他人 uid，否則測不出 App 是否還依賴它。
void expectNoOthersUid(Object? json) {
  if (json is Map) {
    for (final entry in json.entries) {
      expect(
        _removedUidKeys.contains(entry.key),
        isFalse,
        reason: 'fixture 不該帶 ${entry.key}',
      );
      expectNoOthersUid(entry.value);
    }
  } else if (json is List) {
    json.forEach(expectNoOthersUid);
  }
}

List<Map<String, dynamic>> _items(Map<String, dynamic> json, String key) =>
    (json[key] as List).cast<Map<String, dynamic>>();

void main() {
  test('好友列表：以好友碼辨識，「暫時無法使用」的好友也有好友碼', () {
    final json = loadSpecFixtureMap('get_api_friends.json');
    expectNoOthersUid(json);

    final friends = _items(json, 'friends').map(Friendship.fromJson).toList();

    expect(friends.map((f) => f.friendCode), ['BBBB2345', 'CCCC2345']);
    expect(friends.last.unavailable, isTrue);
  });

  test('好友邀請列表：以好友碼辨識邀請人', () {
    final json = loadSpecFixtureMap('get_api_friends_requests.json');
    expectNoOthersUid(json);

    final requests = _items(
      json,
      'requests',
    ).map(FriendRequest.fromJson).toList();

    expect(requests.single.friendCode, 'AAAA2345');
  });

  test('封鎖名單：以好友碼辨識被封鎖的人', () {
    final json = loadSpecFixtureMap('get_api_friends_blocks.json');
    expectNoOthersUid(json);

    final blocks = _items(json, 'blocks').map(BlockedUser.fromJson).toList();

    expect(blocks.single.friendCode, 'BBBB2345');
  });

  test('隨機配對：session 不帶 peer_uid 也能解析，Agora 用回應的 uid', () {
    final json = loadSpecFixtureMap('post_api_video_queue_matched.json');
    expectNoOthersUid(json['session']);

    final result = QueueJoinResult.fromJson(json);

    expect(result.session!.peerFriendCode, 'CCCC2345');
    expect(result.credentials!.uid, 1);
  });

  test('好友通話狀態：以 is_caller 與 peer_friend_code 辨識', () {
    final json = loadSpecFixtureMap('get_api_friends_call_detail.json');
    expectNoOthersUid(json);

    final status = DirectedCallStatus.fromJson(json);

    expect(status.isCaller, isTrue);
    expect(status.peerFriendCode, 'BBBB2345');
    expect(status.sessionId, 12);
  });

  test('來電列表：以 caller_friend_code 辨識來電者', () {
    final json = loadSpecFixtureMap('get_api_friends_calls_incoming.json');
    expectNoOthersUid(json);

    final calls = _items(json, 'incoming').map(IncomingCall.fromJson).toList();

    expect(calls.single.callerFriendCode, 'BBBB2345');
  });

  test('接聽好友來電：session 以好友碼表示對方，Agora 用回應的 uid', () {
    final json = loadSpecFixtureMap('post_api_friends_call_accept.json');
    expectNoOthersUid(json['session']);

    final session = VideoSession.fromJson(
      json['session'] as Map<String, dynamic>,
    );
    final credentials = AgoraCallCredentials.fromJson(json);

    expect(session.peerFriendCode, 'BBBB2345');
    expect(credentials.uid, 2);
  });
}
