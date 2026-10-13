// 通話紀錄（聊天室 calls、對話列表 last_call）的解析，格式見 Truku_backend backend/callLog.ts。

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/models/friend_message_model.dart';

void main() {
  Map<String, dynamic> call(Map<String, dynamic> overrides) => {
    'id': 123,
    'kind': 'completed',
    'mine': true,
    'created_at': '2026-10-12T06:00:00Z',
    'duration_sec': 332,
    'is_unread': false,
    ...overrides,
  };

  test('四種 kind 解析成對應的列舉值', () {
    for (final kind in FriendCallKind.values) {
      expect(FriendCall.fromJson(call({'kind': kind.name}))!.kind, kind);
    }
  });

  test('created_at 解析不了回 null：沒有時間排不進清單', () {
    expect(FriendCall.fromJson(call({'created_at': 'not a date'})), isNull);
    expect(FriendCall.fromJson(call({'created_at': null})), isNull);
  });

  test('不認得的 kind 回 null，列表解析時略過', () {
    expect(FriendCall.fromJson(call({'kind': 'ringing'})), isNull);
    expect(FriendCall.fromJson(call({'kind': null})), isNull);
    final list = FriendCall.listFromJson([
      call({'id': 1, 'kind': 'video_group'}),
      call({'id': 2, 'kind': 'missed'}),
      'not a map',
    ]);
    expect(list.map((c) => c.id), [2]);
  });

  test('欄位照後端給的解析', () {
    final c = FriendCall.fromJson(
      call({'kind': 'missed', 'mine': false, 'is_unread': true}),
    )!;
    expect(c.id, 123);
    expect(c.mine, isFalse);
    expect(c.isUnread, isTrue);
    expect(c.durationSec, 332);
    expect(c.createdAt, DateTime.utc(2026, 10, 12, 6));
  });

  test('duration_sec 為 null 或缺欄位時為 null；is_unread 缺欄位時為 false', () {
    expect(
      FriendCall.fromJson(call({'duration_sec': null}))!.durationSec,
      isNull,
    );
    final missing = call({})
      ..remove('duration_sec')
      ..remove('is_unread');
    final c = FriendCall.fromJson(missing)!;
    expect(c.durationSec, isNull);
    expect(c.isUnread, isFalse);
  });

  test('id 為字串或數字都能解析', () {
    expect(FriendCall.fromJson(call({'id': '77'}))!.id, 77);
    expect(FriendCall.fromJson(call({'id': 77}))!.id, 77);
  });

  test('calls 不是陣列時回空清單', () {
    expect(FriendCall.listFromJson(null), isEmpty);
    expect(FriendCall.listFromJson({'id': 1}), isEmpty);
  });

  group('對話列表的 last_call、last_activity_at', () {
    Map<String, dynamic> conversation(Map<String, dynamic> overrides) => {
      'friend_code': 'BBBB2345',
      'unread_count': 1,
      'last_message': {
        'body': '在嗎',
        'created_at': '2026-10-12T05:00:00Z',
        'mine': false,
      },
      ...overrides,
    };

    test('通話比訊息晚：最後活動是通話', () {
      final c = Conversation.fromJson(
        conversation({
          'last_call': call({'created_at': '2026-10-12T06:00:00Z'}),
          'last_activity_at': '2026-10-12T06:00:00Z',
        }),
      );
      expect(c.lastCall!.id, 123);
      expect(c.lastIsCall, isTrue);
      expect(c.activityAt, DateTime.utc(2026, 10, 12, 6));
    });

    test('同一時間以訊息為準；只有通話沒有訊息時是通話', () {
      final same = Conversation.fromJson(
        conversation({
          'last_call': call({'created_at': '2026-10-12T05:00:00Z'}),
        }),
      );
      expect(same.lastIsCall, isFalse);
      final onlyCall = Conversation.fromJson(
        conversation({'last_message': null, 'last_call': call({})}),
      );
      expect(onlyCall.lastIsCall, isTrue);
      expect(onlyCall.activityAt, DateTime.utc(2026, 10, 12, 6));
    });

    test('舊回應沒有 last_call／last_activity_at：退回最後一則訊息的時間', () {
      final c = Conversation.fromJson(conversation({}));
      expect(c.lastCall, isNull);
      expect(c.lastActivityAt, isNull);
      expect(c.activityAt, DateTime.utc(2026, 10, 12, 5));
    });

    test('last_call 的 kind 不認得時當作沒有', () {
      final c = Conversation.fromJson(
        conversation({
          'last_call': call({'kind': 'future_kind'}),
        }),
      );
      expect(c.lastCall, isNull);
      expect(c.lastIsCall, isFalse);
    });
  });
}
