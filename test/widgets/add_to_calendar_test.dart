// 活動「加入日曆」：系統日曆帶入的內容、Google Calendar 網址，以及打不開時的退路。

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/models/event_model.dart';
import 'package:flutter_application_1/screens/events/widgets/add_to_calendar.dart';

final _start = DateTime.utc(2026, 12, 1, 2, 30);

EventDetail _event({
  DateTime? endsAt,
  String? location = '部落活動中心',
  String? address = '秀林鄉富世村 12 號／部落活動中心',
  String? description = '一起來跳舞',
}) => EventDetail(
  id: 42,
  title: '部落豐年祭',
  description: description,
  startsAt: _start,
  endsAt: endsAt,
  location: location,
  address: address,
  status: 'active',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Google Calendar 網址', () {
    test('時間用 UTC、帶入標題地點說明', () {
      final uri = googleCalendarUri(
        _event(endsAt: DateTime.utc(2026, 12, 1, 5)),
      );
      expect(uri.host, 'calendar.google.com');
      expect(uri.path, '/calendar/render');
      final q = uri.queryParameters;
      expect(q['action'], 'TEMPLATE');
      expect(q['text'], '部落豐年祭');
      expect(q['dates'], '20261201T023000Z/20261201T050000Z');
      expect(q['location'], '秀林鄉富世村 12 號／部落活動中心');
      expect(q['details'], startsWith('一起來跳舞\n\n'));
      expect(q['details'], contains('活動編號 42'));
    });

    test('時區不同也是同一個 UTC 時間', () {
      final local = _event(endsAt: _start.add(const Duration(hours: 1)));
      final shifted = EventDetail(
        id: 42,
        title: '部落豐年祭',
        startsAt: _start.toLocal(),
        endsAt: local.endsAt!.toLocal(),
        status: 'active',
      );
      expect(
        googleCalendarUri(shifted).queryParameters['dates'],
        googleCalendarUri(local).queryParameters['dates'],
      );
    });

    test('沒有結束時間以開始後 2 小時為結束', () {
      expect(
        googleCalendarUri(_event()).queryParameters['dates'],
        '20261201T023000Z/20261201T043000Z',
      );
    });

    test('舊活動地點與地址互不包含時兩個都帶；都沒有就不帶', () {
      expect(
        googleCalendarUri(
          _event(location: '部落廣場', address: '秀林鄉中正路 1 號'),
        ).queryParameters['location'],
        '部落廣場 秀林鄉中正路 1 號',
      );
      expect(
        googleCalendarUri(
          _event(location: null, address: null),
        ).queryParameters.containsKey('location'),
        isFalse,
      );
    });

    test('說明太長時截斷，活動編號仍在', () {
      final details = googleCalendarUri(
        _event(description: '長' * 2000),
      ).queryParameters['details']!;
      expect(details, startsWith('${'長' * 500}…\n\n'));
      expect(details, contains('活動編號 42'));
    });

    test('沒有說明時只有回查文字', () {
      expect(
        googleCalendarUri(_event(description: null)).queryParameters['details'],
        startsWith('在「語見・太魯閣」App'),
      );
    });
  });

  test('已取消、已結束不提供加入日曆，進行中可以', () {
    EventDetail withStatus(String s) => EventDetail(
      id: 1,
      title: 't',
      startsAt: _start,
      status: s == 'cancelled' ? 'cancelled' : 'active',
      effectiveStatus: s,
    );
    expect(canAddToCalendar(withStatus('active')), isTrue);
    expect(canAddToCalendar(withStatus('ongoing')), isTrue);
    expect(canAddToCalendar(withStatus('cancelled')), isFalse);
    expect(canAddToCalendar(withStatus('ended')), isFalse);
  });

  group('按鈕', () {
    late List<MethodCall> calendarCalls;
    late List<MethodCall> launchCalls;
    late bool calendarResult;
    late bool launchResult;

    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const calendarChannel = MethodChannel('add_2_calendar');
    const launcherChannel = MethodChannel('plugins.flutter.io/url_launcher');

    setUp(() {
      calendarCalls = [];
      launchCalls = [];
      calendarResult = true;
      launchResult = true;
      messenger.setMockMethodCallHandler(calendarChannel, (call) async {
        calendarCalls.add(call);
        return calendarResult;
      });
      messenger.setMockMethodCallHandler(launcherChannel, (call) async {
        launchCalls.add(call);
        return launchResult;
      });
    });

    tearDown(() {
      messenger.setMockMethodCallHandler(calendarChannel, null);
      messenger.setMockMethodCallHandler(launcherChannel, null);
      debugDefaultTargetPlatformOverride = null;
    });

    Future<void> tapButton(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AddToCalendarButton(
              event: _event(endsAt: DateTime.utc(2026, 12, 1, 5)),
              seniorMode: false,
            ),
          ),
        ),
      );
      await tester.tap(find.text('加入日曆'));
      await tester.pumpAndSettle();
    }

    testWidgets('手機開系統日曆，帶入標題、時間、地點、說明', (tester) async {
      await tapButton(tester);
      final args = calendarCalls.single.arguments as Map;
      expect(args['title'], '部落豐年祭');
      expect(args['startDate'], _start.millisecondsSinceEpoch);
      expect(
        args['endDate'],
        DateTime.utc(2026, 12, 1, 5).millisecondsSinceEpoch,
      );
      expect(args['location'], '秀林鄉富世村 12 號／部落活動中心');
      expect(args['desc'], contains('活動編號 42'));
      expect(launchCalls, isEmpty);
    });

    testWidgets('Android 沒有日曆 App：改開 Google Calendar 網址', (tester) async {
      calendarResult = false;
      await tapButton(tester);
      final url = Uri.parse(launchCalls.single.arguments['url'] as String);
      expect(url.host, 'calendar.google.com');
      expect(url.queryParameters['text'], '部落豐年祭');
      expect(find.text('無法開啟日曆，請稍後再試'), findsNothing);
    });

    testWidgets('系統日曆與網頁都開不了：提示', (tester) async {
      calendarResult = false;
      launchResult = false;
      await tapButton(tester);
      expect(find.text('無法開啟日曆，請稍後再試'), findsOneWidget);
    });

    testWidgets('iOS 使用者在新增畫面按取消：不提示、不改開網頁', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      calendarResult = false;
      await tapButton(tester);
      expect(calendarCalls, hasLength(1));
      expect(launchCalls, isEmpty);
      expect(find.text('無法開啟日曆，請稍後再試'), findsNothing);
      debugDefaultTargetPlatformOverride = null;
    });
  });
}
