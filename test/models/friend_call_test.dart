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
}
