// 取代的人工重測：
//   「從活動列表點進一場活動、填 email 報名、按返回，
//     看列表上的參加人數有沒有跟著更新」
//
// 這是最常人工重測、也最容易出錯的一條：報名成功但列表沒同步，
// 使用者會以為沒報到而重按。守護的實作是 events_screen.dart:126-133
//   Navigator.push(...).then((_) { if (mounted) _load(); });
// 這一行被拿掉或改寫，人工測才看得出來——現在測得出來了。
//
// 資料形狀取自實機錄製的 fixture（get_api_events_scope_all / get_api_event_detail），
// 只覆寫「開放報名」「參加人數」這幾個測試要操控的欄位；不自己憑空捏一份假結構。
// fixture 裡那筆活動已經 ended，直接用的話報名鈕根本不會 render。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/main.dart' show scaffoldMessengerKey;
import 'package:flutter_application_1/screens/events/events_screen.dart';
import 'package:flutter_application_1/screens/events/event_detail_screen.dart';
import 'package:flutter_application_1/screens/events/widgets/event_detail_dialogs.dart';

import '../helpers/fixtures.dart';
import '../helpers/flow_test_helpers.dart';
import '../helpers/widget_test_helpers.dart';

const int _eventId = 41;

/// fixture 第一筆（id=41）改成「還沒開始、開放報名」。
Map<String, dynamic> _openedUp(
  Map<String, dynamic> base,
  int participantCount,
) => {
  ...base,
  'title': '部落豐年祭',
  'starts_at': '2099-12-01T10:00:00Z',
  'registration_deadline': '2099-11-30T10:00:00Z',
  'effective_status': 'active',
  'registration_open': true,
  'participant_count': participantCount,
};

Map<String, dynamic> _list(int participantCount) {
  final base = loadFixtureMap('get_api_events_scope_all.json');
  final first = loadFixtureList(
    'get_api_events_scope_all.json',
    'events',
  ).first;
  return {
    ...base,
    'total': 1,
    'events': [_openedUp(first, participantCount)],
  };
}

Map<String, dynamic> _detail(int participantCount) =>
    _openedUp(loadFixtureMap('get_api_event_detail.json'), participantCount)
      ..['is_joined'] = false;

Map<String, dynamic> _me() => {
  'uid': 1,
  'display_name': '測試使用者',
  'created_at': '2026-01-01T00:00:00Z',
  'email': 'me@example.com',
  'profile_completed': true,
};

Widget _app() => MaterialApp(
  scaffoldMessengerKey: scaffoldMessengerKey,
  home: const Scaffold(body: EventsScreen()),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    stubCommonChannels(token: 'test-token');
    resetGlobals();
  });

  tearDown(() {
    restoreHttp();
    resetGlobals();
  });

  testWidgets('列表 → 詳情 → 報名 → 返回，列表會重新載入且參加人數同步', (tester) async {
    var listCalls = 0;
    var joinPosted = false;

    // installMockClient 會在每次請求時才去查這個 map，
    // 所以報名成功後直接改 map，就能模擬「後端人數變了」。
    final routes = <String, Object?>{
      '/api/events': _list(5),
      '/api/events/$_eventId': _detail(5),
      '/api/events/$_eventId/reminders': {'reminders': <dynamic>[]},
      '/api/events/$_eventId/join': {'ok': true},
      '/api/me': _me(),
    };

    installMockClient(
      routes,
      onRequest: (r) {
        if (r.url.path == '/api/events') listCalls++;
        if (r.url.path == '/api/events/$_eventId/join' && r.method == 'POST') {
          joinPosted = true;
          // 報名成功，之後查到的人數都變 6。
          routes['/api/events'] = _list(6);
          routes['/api/events/$_eventId'] = _detail(6)..['is_joined'] = true;
        }
      },
    );

    usePhoneSurface(tester);
    await tester.pumpWidget(_app());
    await pumpFrames(tester, times: 10);

    expect(listCalls, 1);
    expect(find.text('部落豐年祭'), findsWidgets);
    // 卡片上的人數文字（event_cards.dart:240）。報名後要看到它變成 6。
    expect(find.textContaining('5 人報名'), findsWidgets);

    await tester.tap(find.text('部落豐年祭').first);
    await pumpFrames(tester, times: 10);
    expect(find.byType(EventDetailScreen), findsOneWidget);

    await tester.tap(find.text('我要參加'));
    await pumpFrames(tester, times: 5);
    expect(find.byType(JoinEmailDialog), findsOneWidget);

    await tester.tap(find.text('確認報名'));
    await pumpFrames(tester, times: 10);
    expect(joinPosted, isTrue, reason: '報名對話框確認後應該送出 POST join');

    // 詳情頁成功狀態沒有 AppBar，返回鈕是 hero 上的自繪箭頭（event_detail_hero.dart:67），
    // 所以 tester.pageBack() / BackButton 都找不到。
    await tester.tap(find.byIcon(Icons.arrow_back));
    await pumpFrames(tester, times: 10);

    expect(find.byType(EventsScreen), findsOneWidget);
    expect(listCalls, 2, reason: '從詳情頁返回後列表應該重新載入，否則報名完的參加人數不會同步');
    expect(
      find.textContaining('6 人報名'),
      findsWidgets,
      reason: '列表重載了，卡片上的人數也要跟著換成後端的新值',
    );
    expect(find.textContaining('5 人報名'), findsNothing);
  });
}
