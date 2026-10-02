// 活動詳情點地址開 Google 地圖：有座標用座標，沒有用地址文字。

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/models/event_model.dart';
import 'package:flutter_application_1/screens/events/widgets/event_map_link.dart';

EventDetail _event({
  String? location = '部落活動中心',
  String? address = '花蓮縣秀林鄉富世村 12 號',
  double? lat,
  double? lng,
}) => EventDetail(
  id: 1,
  title: '走讀',
  startsAt: DateTime.utc(2026, 12, 1),
  location: location,
  address: address,
  latitude: lat,
  longitude: lng,
  status: 'active',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('eventMapsUri', () {
    test('有座標用座標定位', () {
      final uri = eventMapsUri(_event(lat: 24.15, lng: 121.62))!;
      expect(uri.host, 'www.google.com');
      expect(uri.path, '/maps/search/');
      expect(uri.queryParameters['api'], '1');
      expect(uri.queryParameters['query'], '24.15,121.62');
    });

    test('沒有座標用地址文字，沒有地址用地點', () {
      expect(
        eventMapsUri(_event())!.queryParameters['query'],
        '花蓮縣秀林鄉富世村 12 號',
      );
      expect(
        eventMapsUri(_event(address: null))!.queryParameters['query'],
        '部落活動中心',
      );
      expect(eventMapsUri(_event(address: null, location: null)), isNull);
    });
  });

  testWidgets('點地址開外部地圖，開不了時提示', (tester) async {
    final calls = <MethodCall>[];
    var result = true;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return result;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EventMapLink(
            event: _event(lat: 24.15, lng: 121.62),
            seniorMode: false,
            child: const Text('花蓮縣秀林鄉富世村 12 號'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('花蓮縣秀林鄉富世村 12 號'));
    await tester.pumpAndSettle();
    final url = Uri.parse(calls.single.arguments['url'] as String);
    expect(url.queryParameters['query'], '24.15,121.62');
    expect(calls.single.arguments['useWebView'], isFalse);
    expect(find.text('無法開啟地圖，請稍後再試'), findsNothing);

    result = false;
    await tester.tap(find.text('花蓮縣秀林鄉富世村 12 號'));
    await tester.pumpAndSettle();
    expect(find.text('無法開啟地圖，請稍後再試'), findsOneWidget);
  });
}
