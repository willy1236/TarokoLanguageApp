// 小米幣明細：用 page_info 的游標往下捲，到 has_more == false 為止。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/screens/millet/millet_ledger_screen.dart';

import '../helpers/flow_test_helpers.dart';
import '../helpers/widget_test_helpers.dart';

Map<String, dynamic> _tx(int id) => {
  'id': '$id',
  'delta': 50,
  'reason': 'checkin',
  'ref_id': '紀錄 $id',
  'balance_after': 100,
  'created_at': '2026-09-13T02:45:33.107Z',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(stubCommonChannels);
  tearDown(restoreHttp);

  Widget app() => const MaterialApp(home: MilletLedgerScreen());

  Future<void> scrollToBottom(WidgetTester tester) async {
    await tester.fling(find.byType(ListView), const Offset(0, -5000), 3000);
    await pumpFrames(tester, times: 10);
  }

  testWidgets('往下捲帶上一頁的 page_info.next_cursor，不再送 before', (tester) async {
    final requests = <http.BaseRequest>[];
    ApiClient.httpClient = MockClient((r) async {
      requests.add(r);
      final cursor = r.url.queryParameters['cursor'];
      return jsonResponse(
        cursor == null
            ? {
                'transactions': [for (var i = 40; i > 20; i--) _tx(i)],
                'page_info': {'next_cursor': 'c-21', 'has_more': true},
              }
            : {
                'transactions': [for (var i = 20; i > 15; i--) _tx(i)],
                'page_info': {'next_cursor': null, 'has_more': false},
              },
      );
    });

    await tester.pumpWidget(app());
    await pumpFrames(tester);
    expect(requests.single.url.queryParameters, {'limit': '20'});

    await scrollToBottom(tester);
    await scrollToBottom(tester);

    expect(requests, hasLength(2));
    expect(requests.last.url.queryParameters, {'cursor': 'c-21', 'limit': '20'});
    expect(find.textContaining('紀錄 16 ·', skipOffstage: false), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('剛好 20 筆且 has_more == false：捲到底不會多打一次空請求', (tester) async {
    var calls = 0;
    ApiClient.httpClient = MockClient((r) async {
      calls++;
      return jsonResponse({
        'transactions': [for (var i = 20; i > 0; i--) _tx(i)],
        'page_info': {'next_cursor': null, 'has_more': false},
      });
    });

    await tester.pumpWidget(app());
    await pumpFrames(tester);
    await scrollToBottom(tester);

    expect(calls, 1);
    expect(find.textContaining('紀錄 1 ·', skipOffstage: false), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
