// 好友相關推播以好友碼辨識對方（payload 格式見 Truku_backend 好友模組.md「推播通知格式」，
// FRIEND_CODE_ENFORCE 開啟後不再帶 from_uid／uid／caller_uid）。

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/services/fcm_service.dart';

void main() {
  test('邀請、私訊以 from_friend_code 找人', () {
    expect(
      FcmService.parseFriendPush({
        'type': 'friend_request',
        'from_friend_code': 'AAAA2345',
      }),
      (type: 'friend_request', friendCode: 'AAAA2345'),
    );
    expect(
      FcmService.parseFriendPush({
        'type': 'friend_message',
        'from_friend_code': 'BBBB2345',
        'message_id': '18',
      }),
      (type: 'friend_message', friendCode: 'BBBB2345'),
    );
  });

  test('邀請被接受、羈絆展示以 friend_code 找人', () {
    for (final type in [
      'friend_accepted',
      'friend_bond_showcase_requested',
      'friend_bond_showcase_confirmed',
    ]) {
      expect(
        FcmService.parseFriendPush({'type': type, 'friend_code': 'BBBB2345'}),
        (type: type, friendCode: 'BBBB2345'),
      );
    }
  });

  test('只帶舊的 uid 欄位時沒有可用的好友碼', () {
    expect(
      FcmService.parseFriendPush({'type': 'friend_message', 'from_uid': '7'}),
      (type: 'friend_message', friendCode: null),
    );
  });

  test('非好友類推播回 null', () {
    expect(
      FcmService.parseFriendPush({
        'type': 'friend_call_incoming',
        'call_id': '123',
        'caller_friend_code': 'BBBB2345',
      }),
      isNull,
    );
  });
}
