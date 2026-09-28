// 重連後補抓訊息的合併規則（chat_screen.dart 的 _catchUp）。

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/models/friend_message_model.dart';

FriendMessage msg(int id, {DateTime? readAt}) => FriendMessage(
  id: id,
  senderUid: 1,
  recipientUid: 2,
  body: 'm$id',
  createdAt: DateTime(2026, 9, 28),
  readAt: readAt,
);

List<int> ids(List<FriendMessage>? list) => list!.map((m) => m.id).toList();

void main() {
  test('補上斷線期間的新訊息，往上捲載入的舊訊息保留', () {
    // 已載入 10..1（含往上捲的舊頁），重抓的最新一頁是 13..8。
    final loaded = [for (var i = 10; i >= 1; i--) msg(i)];
    final latest = [for (var i = 13; i >= 8; i--) msg(i)];

    expect(ids(mergeLatestMessages(loaded, latest)), [
      for (var i = 13; i >= 1; i--) i,
    ]);
  });

  test('同 id 以重抓的為準（已讀狀態更新）', () {
    final readAt = DateTime(2026, 9, 28, 12);
    final merged = mergeLatestMessages(
      [msg(2), msg(1)],
      [msg(3), msg(2, readAt: readAt)],
    );
    expect(merged!.firstWhere((m) => m.id == 2).readAt, readAt);
  });

  test('接不起來（離線期間超過一頁）回 null，改整頁替換', () {
    expect(mergeLatestMessages([msg(2), msg(1)], [msg(40), msg(39)]), isNull);
  });

  test('尚未載入任何訊息時直接用重抓的', () {
    expect(ids(mergeLatestMessages([], [msg(2), msg(1)])), [2, 1]);
  });
}
