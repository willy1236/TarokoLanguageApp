// 測驗紀錄頁：往下捲帶游標翻頁、到底看 has_more、依類型＋session_id 去重，
// 切換類型篩選後從第一頁重來。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/screens/history/history_screen.dart';
import 'package:flutter_application_1/services/history_service.dart';

import '../helpers/flow_test_helpers.dart';
import '../helpers/widget_test_helpers.dart';

Map<String, dynamic> _record(int n, {String type = 'quiz'}) => {
  'type': type,
  'type_label': type == 'quiz' ? '單字學習' : '聽力測驗',
  'session_id': 'session-$n',
  'status': 'completed',
  'status_label': '已完成',
  'level': '紀錄 $n',
  'score': 8,
  'answered_count': 10,
  'total_questions': 10,
  'started_at': '2026-09-17T11:15:59.658Z',
  'last_active_at': '2026-09-17T11:16:07.243Z',
  'completed_at': '2026-09-17T11:16:07.670Z',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(stubCommonChannels);
  tearDown(restoreHttp);

  Future<void> scrollToBottom(WidgetTester tester) async {
    await tester.fling(find.byType(ListView), const Offset(0, -5000), 3000);
    await pumpFrames(tester, times: 10);
  }

  testWidgets('往下捲帶游標翻到底，重複的紀錄只出現一次，到底後不再請求', (tester) async {
    final requests = <http.BaseRequest>[];
    ApiClient.httpClient = MockClient((r) async {
      requests.add(r);
      final cursor = r.url.queryParameters['cursor'];
      return jsonResponse(
        cursor == null
            ? {
                'records': [for (var i = 1; i <= 20; i++) _record(i)],
                'page_info': {'next_cursor': '20', 'has_more': true},
              }
            : {
                'records': [for (var i = 20; i <= 24; i++) _record(i)],
                'page_info': {'next_cursor': null, 'has_more': false},
              },
      );
    });

    await tester.pumpWidget(const MaterialApp(home: HistoryScreen()));
    await pumpFrames(tester);
    for (var i = 0; i < 3; i++) {
      await scrollToBottom(tester);
    }

    expect(requests.map((r) => r.url.queryParameters['cursor']), [null, '20']);
    expect(requests.first.url.queryParameters['limit'], '20');
    expect(find.text('紀錄 24'), findsOneWidget);
    expect(find.text('紀錄 20', skipOffstage: false), findsOneWidget);
  });

  testWidgets('切換類型篩選後從第一頁重來', (tester) async {
    final requests = <Map<String, String>>[];
    ApiClient.httpClient = MockClient((r) async {
      requests.add(r.url.queryParameters);
      final type = r.url.queryParameters['type'] ?? 'quiz';
      return jsonResponse({
        'records': [for (var i = 1; i <= 20; i++) _record(i, type: type)],
        'page_info': {'next_cursor': '20', 'has_more': true},
      });
    });

    await tester.pumpWidget(const MaterialApp(home: HistoryScreen()));
    await pumpFrames(tester);
    await scrollToBottom(tester);
    expect(requests.last['cursor'], '20');

    await tester.tap(find.text('聽力測驗').first);
    await pumpFrames(tester);

    expect(requests.last, {'type': 'listening', 'limit': '20'});
  });

  test('fetchHistory 指定 limit 時只帶 limit、不帶 cursor（最近紀錄用）', () async {
    final queries = <Map<String, String>>[];
    ApiClient.httpClient = MockClient((r) async {
      queries.add(r.url.queryParameters);
      return jsonResponse({
        'records': [for (var i = 1; i <= 5; i++) _record(i)],
        'page_info': {'next_cursor': '5', 'has_more': true},
      });
    });

    final result = await HistoryService.fetchHistory(type: 'quiz', limit: 5);

    expect(queries.single, {'type': 'quiz', 'limit': '5'});
    expect(result.records, hasLength(5));
  });
}
