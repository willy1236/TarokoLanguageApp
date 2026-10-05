// 小米幣明細：用 page_info 的游標往下捲，到 has_more == false 為止。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/screens/millet/millet_ledger_screen.dart';
import 'package:flutter_application_1/services/senior_mode_controller.dart';
import 'package:flutter_application_1/shared/widgets/async_state_view.dart';
import 'package:flutter_application_1/shared/widgets/load_more_retry.dart';
import 'package:flutter_application_1/shared/widgets/truku_empty_state.dart';

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
    expect(requests.last.url.queryParameters, {
      'cursor': 'c-21',
      'limit': '20',
    });
    expect(find.textContaining('紀錄 16 ·', skipOffstage: false), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('剛好 20 筆且 has_more == false：捲到底不會多打一次空請求', (tester) async {
    var calls = 0;
    ApiClient.httpClient = MockClient((r) async {
      calls++;
      return jsonResponse({
        'transactions': [for (var i = 20; i > 0; i--) _tx(i)],
        // 帶了游標但 has_more 為 false：要看 has_more，不能只看游標在不在。
        'page_info': {'next_cursor': '1', 'has_more': false},
      });
    });

    await tester.pumpWidget(app());
    await pumpFrames(tester);
    await scrollToBottom(tester);

    expect(calls, 1);
    expect(find.textContaining('紀錄 1 ·', skipOffstage: false), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('翻頁失敗：底部顯示重試，捲動不再自動重打，點了才重新請求', (tester) async {
    var nextPageCalls = 0;
    var failNext = true;
    ApiClient.httpClient = MockClient((r) async {
      final cursor = r.url.queryParameters['cursor'];
      if (cursor == null) {
        return jsonResponse({
          'transactions': [for (var i = 40; i > 20; i--) _tx(i)],
          'page_info': {'next_cursor': 'c-21', 'has_more': true},
        });
      }
      nextPageCalls++;
      if (failNext) return errorResponse('SERVER_ERROR', status: 500);
      return jsonResponse({
        'transactions': [for (var i = 20; i > 15; i--) _tx(i)],
        'page_info': {'next_cursor': null, 'has_more': false},
      });
    });

    await tester.pumpWidget(app());
    await pumpFrames(tester);
    await scrollToBottom(tester);
    await scrollToBottom(tester);

    expect(nextPageCalls, 1);
    expect(find.text('載入失敗，點此重試'), findsOneWidget);

    failNext = false;
    await tester.tap(find.text('載入失敗，點此重試'));
    await pumpFrames(tester, times: 10);

    expect(nextPageCalls, 2);
    expect(find.text('載入失敗，點此重試'), findsNothing);
    await scrollToBottom(tester);
    expect(find.textContaining('紀錄 16 ·', skipOffstage: false), findsOneWidget);
  });

  group('切換長輩模式時畫面跟著變', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));
    tearDown(() => seniorModeController.setEnabled(false));

    Future<void> toggleSenior(WidgetTester tester) async {
      await seniorModeController.setEnabled(true);
      await tester.pump();
    }

    testWidgets('錯誤畫面', (tester) async {
      ApiClient.httpClient = MockClient(
        (_) async => errorResponse('SERVER_ERROR', status: 500),
      );
      await tester.pumpWidget(app());
      await pumpFrames(tester);
      bool senior() =>
          tester.widget<TrukuErrorView>(find.byType(TrukuErrorView)).seniorMode;
      expect(senior(), isFalse);

      await toggleSenior(tester);
      expect(senior(), isTrue);
    });

    testWidgets('空狀態', (tester) async {
      ApiClient.httpClient = MockClient(
        (_) async => jsonResponse({
          'transactions': <dynamic>[],
          'page_info': {'next_cursor': null, 'has_more': false},
        }),
      );
      await tester.pumpWidget(app());
      await pumpFrames(tester);
      bool senior() => tester
          .widget<TrukuEmptyState>(find.byType(TrukuEmptyState))
          .seniorMode;
      expect(senior(), isFalse);

      await toggleSenior(tester);
      expect(senior(), isTrue);
    });

    testWidgets('翻頁失敗的重試列', (tester) async {
      ApiClient.httpClient = MockClient((r) async {
        if (r.url.queryParameters['cursor'] != null) {
          return errorResponse('SERVER_ERROR', status: 500);
        }
        return jsonResponse({
          'transactions': [for (var i = 40; i > 20; i--) _tx(i)],
          'page_info': {'next_cursor': 'c-21', 'has_more': true},
        });
      });
      await tester.pumpWidget(app());
      await pumpFrames(tester);
      await scrollToBottom(tester);
      await scrollToBottom(tester);
      bool senior() =>
          tester.widget<LoadMoreRetry>(find.byType(LoadMoreRetry)).seniorMode;
      expect(senior(), isFalse);

      await toggleSenior(tester);
      expect(senior(), isTrue);
    });
  });
}
