// 好友分頁的最後活動：右側時間、通話預覽、依最後活動排序，只有通話紀錄的
// 無法使用好友也能點進聊天室；舊回應沒有 last_call／last_activity_at 不閃退。

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/utils/date_format.dart';
import 'package:flutter_application_1/models/friend_message_model.dart';
import 'package:flutter_application_1/models/friend_model.dart';
import 'package:flutter_application_1/screens/chat/chat_screen.dart';
import 'package:flutter_application_1/screens/friends/friends_list_screen.dart';
import 'package:flutter_application_1/services/chat_socket_service.dart';

import '../helpers/fixtures.dart';
import '../helpers/flow_test_helpers.dart';
import '../helpers/widget_test_helpers.dart';

/// 規格範例的好友，換好友碼與暱稱。
Map<String, dynamic> friendJson(String code, String nickname) => {
  ...(loadSpecFixtureMap('get_api_friends.json')['friends'] as List).first
      as Map<String, dynamic>,
  'friend_code': code,
  'nickname': nickname,
  'unavailable': false,
};

Map<String, dynamic> conversation(
  String code, {
  Map<String, dynamic>? lastMessage,
  Map<String, dynamic>? lastCall,
  String? lastActivityAt,
  int unread = 0,
  bool unavailable = false,
}) => {
  'nickname': unavailable ? '暫時無法使用' : code,
  'friend_code': code,
  'unread_count': unread,
  'unavailable': unavailable,
  'last_message': lastMessage,
  'last_call': lastCall,
  'last_activity_at': lastActivityAt,
};

Map<String, dynamic> missedCall(String at) => {
  'id': 120,
  'kind': 'missed',
  'mine': false,
  'created_at': at,
  'duration_sec': null,
  'is_unread': true,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(stubCommonChannels);
  tearDown(() {
    chatController.disconnect();
    restoreHttp();
  });

  Future<void> open(
    WidgetTester tester, {
    required List<Map<String, dynamic>> friends,
    required List<Map<String, dynamic>> conversations,
    Map<String, Object?> extra = const {},
  }) async {
    installMockClient({
      '/api/friends': {'friends': friends},
      '/api/friends/messages': {'conversations': conversations},
      '/api/shop/items': {'items': []},
      ...extra,
    });
    await tester.pumpWidget(wrapScreen(const FriendsListScreen()));
    await pumpFrames(tester);
  }

  double rowY(WidgetTester tester, String nickname) => tester
      .getCenter(find.textContaining(nickname, findRichText: true).first)
      .dy;

  testWidgets('依最後活動新到舊排在前面，沒有活動的排在後面且維持原順序', (tester) async {
    await open(
      tester,
      // 後端依成為好友時間新到舊。
      friends: [
        friendJson('AAAA2345', '甲'),
        friendJson('BBBB2345', '乙'),
        friendJson('CCCC2345', '丙'),
        friendJson('DDDD2345', '丁'),
      ],
      conversations: [
        conversation(
          'CCCC2345',
          lastMessage: {
            'body': '早',
            'created_at': '2026-10-12T01:00:00Z',
            'mine': true,
          },
          lastActivityAt: '2026-10-12T01:00:00Z',
        ),
        conversation(
          'DDDD2345',
          lastCall: missedCall('2026-10-12T05:00:00Z'),
          lastActivityAt: '2026-10-12T05:00:00Z',
          unread: 1,
        ),
      ],
    );

    final order = ['丁', '丙', '甲', '乙'].map((n) => rowY(tester, n)).toList();
    expect(order, [...order]..sort());
  });

  testWidgets('預覽：未接來電紅字、其他通話「[視訊通話]」、訊息照舊加「你：」；右側顯示最後活動時間', (tester) async {
    await open(
      tester,
      friends: [
        friendJson('AAAA2345', '甲'),
        friendJson('BBBB2345', '乙'),
        friendJson('CCCC2345', '丙'),
      ],
      conversations: [
        conversation(
          'AAAA2345',
          lastCall: missedCall('2026-10-12T05:00:00Z'),
          lastActivityAt: '2026-10-12T05:00:00Z',
          unread: 1,
        ),
        conversation(
          'BBBB2345',
          // 通話比訊息晚：預覽是通話。
          lastMessage: {
            'body': '等等打給你',
            'created_at': '2026-10-11T05:00:00Z',
            'mine': true,
          },
          lastCall: {
            ...missedCall('2026-10-11T06:00:00Z'),
            'kind': 'completed',
            'mine': true,
            'duration_sec': 60,
            'is_unread': false,
          },
          lastActivityAt: '2026-10-11T06:00:00Z',
        ),
        // 舊回應：沒有 last_call／last_activity_at，時間退回最後一則訊息。
        {
          'nickname': '丙',
          'friend_code': 'CCCC2345',
          'unread_count': 0,
          'last_message': {
            'body': '晚安',
            'created_at': '2026-10-10T13:00:00Z',
            'mine': true,
          },
        },
      ],
    );

    expect(find.text('未接視訊通話'), findsOneWidget);
    expect(find.text('[視訊通話]'), findsOneWidget);
    expect(find.text('你：等等打給你'), findsNothing);
    expect(find.text('你：晚安'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    for (final at in [
      '2026-10-12T05:00:00Z',
      '2026-10-11T06:00:00Z',
      '2026-10-10T13:00:00Z',
    ]) {
      expect(find.text(formatActivityTime(DateTime.parse(at))), findsOneWidget);
    }
  });

  testWidgets('無法使用的好友只有通話紀錄、沒有訊息，仍可點進聊天室', (tester) async {
    await open(
      tester,
      friends: [friendJson('CCCC2345', '阿華')],
      conversations: [
        conversation(
          'CCCC2345',
          unavailable: true,
          lastCall: missedCall('2026-10-12T05:00:00Z'),
          lastActivityAt: '2026-10-12T05:00:00Z',
        ),
      ],
      extra: {
        '/api/friends/CCCC2345/messages': loadSpecFixtureMap(
          'get_api_friend_messages_unavailable.json',
        ),
        '/api/friends/CCCC2345/messages/read': {'ok': true, 'marked': 0},
      },
    );

    await tester.tap(find.text('暫時無法使用'));
    await pumpFrames(tester);

    expect(find.byType(ChatScreen), findsOneWidget);
  });

  group('sortFriendsByActivity', () {
    Friendship friend(String code) =>
        Friendship.fromJson(friendJson(code, code));

    test('時間相同時維持原順序；不改動傳入的清單', () {
      final friends = [friend('A'), friend('B'), friend('C')];
      final at = DateTime.utc(2026, 10, 12);
      final sorted = sortFriendsByActivity(friends, {
        'B': Conversation(friendCode: 'B', unreadCount: 0, lastActivityAt: at),
        'C': Conversation(friendCode: 'C', unreadCount: 0, lastActivityAt: at),
      });
      expect(sorted.map((f) => f.friendCode), ['B', 'C', 'A']);
      expect(friends.map((f) => f.friendCode), ['A', 'B', 'C']);
    });
  });
}
