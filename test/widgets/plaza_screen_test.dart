// PlazaScreen（廣場動態）頁首的近期活動小卡何時重抓。
//
// 這支取代的人工測試：在活動分頁發起或刪除活動後切回廣場，看小卡有沒有跟著變；
// 點小卡進詳情只看不改就返回，小卡不該重抓；在詳情報名或按讚後返回才重抓。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/screens/plaza/plaza_screen.dart';
import 'package:flutter_application_1/screens/plaza/widgets/plaza_cards.dart';
import 'package:flutter_application_1/services/event_service.dart';
import 'package:flutter_application_1/services/notification_summary_service.dart';

import '../helpers/flow_test_helpers.dart';
import '../helpers/widget_test_helpers.dart';

Map<String, dynamic> _event({int id = 1, String title = '部落豐年祭'}) => {
  'id': id,
  'title': title,
  'starts_at': '2099-12-01T10:00:00Z',
  'category': '其他',
  'status': 'active',
  'effective_status': 'active',
  'registration_open': true,
  'description': '說明',
  'like_count': 0,
  'is_liked': false,
};

/// 記下 /api/events（列表）被打幾次；[events] 決定每次回什麼。
class _Backend {
  _Backend(this.events);

  List<Map<String, dynamic>> Function() events;
  var eventListCalls = 0;

  /// 設定後，列表請求要等測試完成對應的 Completer 才回（依送出順序排隊）。
  List<Completer<List<Map<String, dynamic>>>>? held;

  void install() {
    ApiClient.httpClient = MockClient((r) async {
      if (r.url.path == '/api/events' && held != null) {
        eventListCalls++;
        final completer = Completer<List<Map<String, dynamic>>>();
        held!.add(completer);
        return jsonResponse({'events': await completer.future});
      }
      final Object body = switch (r.url.path) {
        '/api/events' => () {
          eventListCalls++;
          return {'events': events()};
        }(),
        '/api/forum/boards' => {'boards': <dynamic>[]},
        '/api/forum/posts' => {'posts': <dynamic>[], 'total': 0},
        '/api/notifications/summary' => {
          'forum_unread': 0,
          'event_unread': 0,
          'friend_requests': 0,
        },
        '/api/me' => {'uid': 1, 'created_at': '2026-01-01T00:00:00Z'},
        '/api/shop/items' => {'items': <dynamic>[]},
        '/api/events/1' => _event(),
        '/api/events/1/reminders' => {'reminders': <dynamic>[]},
        '/api/events/1/like' => {'liked': true, 'like_count': 1},
        // 用來觸發 EventService.eventsChanged。
        '/api/events/9' => {'success': true, 'notified': 0},
        _ => fail('沒準備 ${r.url.path}'),
      };
      return body is http.Response ? body : jsonResponse(body);
    });
  }
}

Widget _app() => const MaterialApp(home: Scaffold(body: PlazaScreen()));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    stubCommonChannels();
    NotificationSummaryService.clear();
  });

  tearDown(() {
    restoreHttp();
    NotificationSummaryService.clear();
  });

  testWidgets('別處刪除活動（eventsChanged）：小卡重抓，刪掉的那場消失', (tester) async {
    var events = [_event(), _event(id: 9, title: '要刪的活動')];
    final backend = _Backend(() => events)..install();

    await tester.pumpWidget(_app());
    await pumpFrames(tester);
    expect(find.text('要刪的活動'), findsOneWidget);

    events = [_event()];
    await EventService.deleteEvent(9);
    await pumpFrames(tester);

    expect(backend.eventListCalls, 2);
    expect(find.text('要刪的活動'), findsNothing);
    expect(find.text('部落豐年祭'), findsOneWidget);
  });

  group('兩次重抓同時在路上：只採用晚送出的那次', () {
    Future<List<Completer<List<Map<String, dynamic>>>>> twoInFlight(
      WidgetTester tester,
    ) async {
      final backend = _Backend(() => [_event(title: '最初')])..install();
      await tester.pumpWidget(_app());
      await pumpFrames(tester);
      final held = backend.held = [];
      // 例如連刪兩張照片，各觸發一次 eventsChanged。
      await EventService.deleteEvent(9);
      await EventService.deleteEvent(9);
      await pumpFrames(tester, times: 2);
      expect(held, hasLength(2));
      return held;
    }

    testWidgets('晚送出的先回來：早送出的晚回來時不蓋掉', (tester) async {
      final held = await twoInFlight(tester);

      held[1].complete([_event(title: '較新')]);
      await pumpFrames(tester, times: 2);
      held[0].complete([_event(title: '較舊')]);
      await pumpFrames(tester, times: 2);

      expect(find.text('較新'), findsOneWidget);
      expect(find.text('較舊'), findsNothing);
    });

    testWidgets('晚送出的後回來：最後顯示晚送出的結果', (tester) async {
      final held = await twoInFlight(tester);

      held[0].complete([_event(title: '較舊')]);
      await pumpFrames(tester, times: 2);
      held[1].complete([_event(title: '較新')]);
      await pumpFrames(tester, times: 2);

      expect(find.text('較新'), findsOneWidget);
      expect(find.text('較舊'), findsNothing);
    });
  });

  testWidgets('點小卡進詳情只看不改就返回：不重抓', (tester) async {
    final backend = _Backend(() => [_event()])..install();

    await tester.pumpWidget(_app());
    await pumpFrames(tester);
    await tester.tap(find.byType(PlazaMiniEventCard));
    await pumpFrames(tester, times: 10);
    await tester.binding.handlePopRoute();
    await pumpFrames(tester, times: 10);

    expect(backend.eventListCalls, 1);
  });

  testWidgets('在詳情按讚後返回：重抓', (tester) async {
    final backend = _Backend(() => [_event()])..install();

    await tester.pumpWidget(_app());
    await pumpFrames(tester);
    await tester.tap(find.byType(PlazaMiniEventCard));
    await pumpFrames(tester, times: 10);
    await tester.tap(find.byIcon(Icons.favorite_border));
    await pumpFrames(tester);
    await tester.binding.handlePopRoute();
    await pumpFrames(tester, times: 10);

    expect(backend.eventListCalls, 2);
  });

  testWidgets('離開畫面後不再回應 eventsChanged', (tester) async {
    final backend = _Backend(() => [_event()])..install();

    await tester.pumpWidget(_app());
    await pumpFrames(tester);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));

    await EventService.deleteEvent(9);
    await pumpFrames(tester);

    expect(backend.eventListCalls, 1);
  });
}
