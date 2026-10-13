// 聊天室清單項目：訊息與通話依時間混排，之間依本地日期插分隔，往上分頁前後同一天不重複。

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/models/friend_message_model.dart';
import 'package:flutter_application_1/screens/chat/chat_items.dart';

FriendCall call(
  int id,
  DateTime at, {
  FriendCallKind kind = FriendCallKind.completed,
  int? durationSec,
}) => FriendCall(
  id: id,
  kind: kind,
  mine: true,
  createdAt: at,
  durationSec: durationSec,
);

FriendMessage msg(int id, DateTime at) =>
    FriendMessage(id: id, mine: id.isEven, body: 'm$id', createdAt: at);

/// 項目轉成好比對的字串：訊息是 id，分隔是「|月/日」。
List<String> describe(List<ChatItem> items) => [
  for (final item in items)
    switch (item) {
      ChatMessageItem(:final message) => '${message.id}',
      ChatCallItem(:final call) => 'c${call.id}',
      ChatDayDivider(:final day) =>
        '|${day.toLocal().month}/${day.toLocal().day}',
    },
];

void main() {
  // 新到舊：10/12 兩則、10/11 一則。
  final messages = [
    msg(3, DateTime(2026, 10, 12, 9)),
    msg(2, DateTime(2026, 10, 12, 8)),
    msg(1, DateTime(2026, 10, 11, 23, 59)),
  ];

  test('跨日時在較新那天的最舊一則之後（畫面上方）插分隔', () {
    expect(describe(buildChatItems(messages, const [], reachedOldest: true)), [
      '3',
      '2',
      '|10/12',
      '1',
      '|10/11',
    ]);
  });

  test('還沒載到最早：最舊一則上方不插，載入下一頁後才在正確位置出現一次', () {
    final firstPage = messages.sublist(0, 2);
    expect(
      describe(buildChatItems(firstPage, const [], reachedOldest: false)),
      ['3', '2'],
    );
    // 下一頁同一天還有一則：10/12 的分隔移到它上方，不重複。
    final more = [
      ...firstPage,
      msg(1, DateTime(2026, 10, 12, 7)),
      msg(0, DateTime(2026, 10, 10, 7)),
    ];
    expect(describe(buildChatItems(more, const [], reachedOldest: false)), [
      '3',
      '2',
      '1',
      '|10/12',
      '0',
    ]);
  });

  test('UTC 時間以本地日期分天：台灣凌晨的訊息不跟前一天併在一起', () {
    final items = buildChatItems(
      [
        msg(2, DateTime(2026, 10, 12, 0, 30).toUtc()),
        msg(1, DateTime(2026, 10, 11, 23, 30).toUtc()),
      ],
      const [],
      reachedOldest: false,
    );
    expect(describe(items), ['2', '|10/12', '1']);
  });

  test('沒有訊息時沒有項目', () {
    expect(buildChatItems(const [], const [], reachedOldest: true), isEmpty);
  });

  test('通話與訊息依時間混排，跨日分隔照樣插；只有通話也有項目', () {
    final items = buildChatItems(messages, [
      call(9, DateTime(2026, 10, 12, 8, 30)),
      call(8, DateTime(2026, 10, 10, 20)),
    ], reachedOldest: true);
    expect(describe(items), [
      '3',
      'c9',
      '2',
      '|10/12',
      '1',
      '|10/11',
      'c8',
      '|10/10',
    ]);
    expect(
      describe(
        buildChatItems(const [], [
          call(1, DateTime(2026, 10, 12, 8)),
        ], reachedOldest: true),
      ),
      ['c1', '|10/12'],
    );
  });

  test('同一秒：訊息排在較新那側，同類依 id，排序穩定', () {
    final at = DateTime(2026, 10, 12, 8);
    final items = buildChatItems(
      [msg(5, at), msg(6, at)],
      [call(2, at), call(3, at)],
      reachedOldest: false,
    );
    expect(describe(items), ['6', '5', 'c3', 'c2']);
  });

  test('通話文字：秒數轉分:秒，滿 1 小時為時:分:秒', () {
    final at = DateTime(2026, 10, 12);
    expect(callLabel(call(1, at, durationSec: 332)), '視訊通話 05:32');
    expect(callLabel(call(1, at, durationSec: 0)), '視訊通話 00:00');
    expect(callLabel(call(1, at, durationSec: 3723)), '視訊通話 1:02:03');
    expect(callLabel(call(1, at, kind: FriendCallKind.cancelled)), '已取消');
    expect(callLabel(call(1, at, kind: FriendCallKind.missed)), '未接視訊通話');
    expect(callLabel(call(1, at, kind: FriendCallKind.declined)), '已拒接');
  });
}
