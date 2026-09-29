// 「活動通知」頁齒輪 → 部落新活動推播開關。進頁面不查設定，打開底板才 GET。

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/screens/events/event_notifications_screen.dart';

import '../helpers/widget_test_helpers.dart';

const _settingsPath = '/api/me/notification-settings';

final _notificationsPage = {
  'notifications': <dynamic>[],
  'unread_count': 0,
  'page_info': {'next_cursor': null, 'has_more': false},
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<http.Request> seen;

  setUp(() {
    stubCommonChannels();
    seen = [];
  });
  tearDown(restoreHttp);

  void install(Map<String, Object?> settingsByMethod) {
    ApiClient.httpClient = MockClient((request) async {
      seen.add(request);
      if (request.url.path == '/api/events/notifications') {
        return jsonResponse(_notificationsPage);
      }
      if (request.url.path != _settingsPath) {
        fail('沒有準備 ${request.method} ${request.url.path} 的假回應');
      }
      final route = settingsByMethod[request.method];
      if (route is Future<http.Response> Function()) return route();
      return route is http.Response ? route : jsonResponse(route);
    });
  }

  List<http.Request> settingsRequests() =>
      seen.where((r) => r.url.path == _settingsPath).toList();

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.byTooltip('推播設定'));
    await tester.pumpAndSettle();
  }

  Switch switchOf(WidgetTester tester) =>
      tester.widget<Switch>(find.byType(Switch));

  testWidgets('進頁面不查推播設定，打開底板才 GET 並反映後端值', (tester) async {
    install({
      'GET': {'tribe_events': false},
    });
    await tester.pumpWidget(wrapScreen(const EventNotificationsScreen()));
    await tester.pumpAndSettle();

    expect(settingsRequests(), isEmpty);

    await openSheet(tester);

    expect(settingsRequests().single.method, 'GET');
    expect(find.text('接收「你的部落有新活動」推播'), findsOneWidget);
    expect(find.text('活動提醒不受影響'), findsOneWidget);
    expect(switchOf(tester).value, isFalse);
  });

  testWidgets('載入中顯示轉圈，不先顯示預設開關', (tester) async {
    final pending = Completer<http.Response>();
    install({'GET': () => pending.future});
    await tester.pumpWidget(wrapScreen(const EventNotificationsScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('推播設定'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(Switch), findsNothing);

    pending.complete(jsonResponse({'tribe_events': true}));
    await tester.pumpAndSettle();
    expect(switchOf(tester).value, isTrue);
  });

  testWidgets('切換開關送 PATCH，畫面跟著變', (tester) async {
    install({
      'GET': {'tribe_events': true},
      'PATCH': {'tribe_events': false},
    });
    await tester.pumpWidget(wrapScreen(const EventNotificationsScreen()));
    await tester.pumpAndSettle();
    await openSheet(tester);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    final patch = settingsRequests().last;
    expect(patch.method, 'PATCH');
    expect(jsonDecode(patch.body), {'tribe_events': false});
    expect(switchOf(tester).value, isFalse);
  });

  testWidgets('PATCH 失敗時開關復原並提示', (tester) async {
    install({
      'GET': {'tribe_events': true},
      'PATCH': errorResponse('INTERNAL_ERROR', status: 500),
    });
    await tester.pumpWidget(wrapScreen(const EventNotificationsScreen()));
    await tester.pumpAndSettle();
    await openSheet(tester);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(switchOf(tester).value, isTrue);
    expect(find.text('儲存失敗，請稍後再試'), findsOneWidget);
  });

  testWidgets('GET 失敗時顯示錯誤與重試，不顯示假的預設值', (tester) async {
    var fail = true;
    install({
      'GET': () async => fail
          ? errorResponse('INTERNAL_ERROR', status: 500, message: '伺服器錯誤')
          : jsonResponse({'tribe_events': true}),
    });
    await tester.pumpWidget(wrapScreen(const EventNotificationsScreen()));
    await tester.pumpAndSettle();
    await openSheet(tester);

    expect(find.byType(Switch), findsNothing);
    expect(find.text('重試'), findsOneWidget);

    fail = false;
    await tester.tap(find.text('重試'));
    await tester.pumpAndSettle();

    expect(switchOf(tester).value, isTrue);
  });

  testWidgets('回應缺 tribe_events 欄位時視為開啟', (tester) async {
    install({'GET': <String, dynamic>{}});
    await tester.pumpWidget(wrapScreen(const EventNotificationsScreen()));
    await tester.pumpAndSettle();
    await openSheet(tester);

    expect(switchOf(tester).value, isTrue);
  });
}
