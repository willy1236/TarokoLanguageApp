// 小米幣查帳：以好友碼查人後顯示對帳結果與明細，捲到底載下一頁。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/main.dart' show scaffoldMessengerKey;
import 'package:flutter_application_1/screens/admin/admin_millet_screen.dart';
import 'package:flutter_application_1/screens/millet/widgets/millet_transaction_row.dart';

import '../../helpers/fixtures.dart';
import '../../helpers/widget_test_helpers.dart';

Widget _app() => MaterialApp(
  scaffoldMessengerKey: scaffoldMessengerKey,
  home: const AdminMilletScreen(),
);

Map<String, dynamic> _tx(int id) => {
  'id': '$id',
  'delta': 50,
  'reason': 'checkin',
  'ref_id': '2026-09-$id',
  'balance_after': 100 + id,
  'created_at': '2026-09-17T11:13:05.777Z',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(stubCommonChannels);
  tearDown(restoreHttp);

  List<http.Request> install({
    Map<String, dynamic>? reconcile,
    http.Response? transactionsError,
    bool Function()? failSecondPage,
  }) {
    final requests = <http.Request>[];
    ApiClient.httpClient = MockClient((r) async {
      requests.add(r);
      switch (r.url.path) {
        case '/api/admin/users/lookup':
          return jsonResponse(
            loadFixtureMap('get_api_admin_users_lookup.json'),
          );
        case '/api/admin/millet/reconcile':
          return jsonResponse(
            reconcile ?? loadFixtureMap('get_api_admin_millet_reconcile.json'),
          );
        default:
          if (transactionsError != null) return transactionsError;
          final second = r.url.queryParameters['cursor'] == 'p2';
          if (second && (failSecondPage?.call() ?? false)) {
            return errorResponse('INTERNAL', status: 500);
          }
          return jsonResponse({
            'transactions': [
              for (var i = 0; i < 10; i++) _tx(second ? 20 + i : 10 + i),
            ],
            'page_info': {
              'next_cursor': second ? null : 'p2',
              'has_more': !second,
            },
          });
      }
    });
    return requests;
  }

  Future<void> lookUp(WidgetTester tester) async {
    await tester.pumpWidget(_app());
    await tester.enterText(find.byType(TextField), 'TESTCODE');
    await tester.tap(find.text('查詢'));
    await tester.pumpAndSettle();
  }

  testWidgets('查人後以 uid 查對帳與明細；不一致時醒目標示差額', (tester) async {
    final requests = install();
    await lookUp(tester);

    final millet = requests.where((r) => r.url.path.contains('/millet/'));
    expect(millet.map((r) => r.url.queryParameters['uid']), everyElement('20'));
    expect(find.text('不一致'), findsOneWidget);
    expect(find.textContaining('差額 500'), findsOneWidget);
    expect(find.byType(MilletTransactionRow), findsWidgets);
  });

  testWidgets('帳平時顯示一致、沒有差額說明', (tester) async {
    install(
      reconcile: {'uid': 20, 'ledger_sum': 350, 'user_millet': 350, 'ok': true},
    );
    await lookUp(tester);

    expect(find.text('一致'), findsOneWidget);
    expect(find.textContaining('差額'), findsNothing);
  });

  testWidgets('捲到底用 next_cursor 載下一頁', (tester) async {
    final requests = install();
    await lookUp(tester);

    await tester.drag(find.byType(ListView), const Offset(0, -3000));
    await tester.pumpAndSettle();

    expect(
      requests.where((r) => r.url.queryParameters['cursor'] == 'p2'),
      hasLength(1),
    );
  });

  testWidgets('下一頁載入失敗：顯示重試列，再捲動不自動重打，點重試才重送', (tester) async {
    var fail = true;
    final requests = install(failSecondPage: () => fail);
    await lookUp(tester);
    int secondPages() =>
        requests.where((r) => r.url.queryParameters['cursor'] == 'p2').length;

    await tester.drag(find.byType(ListView), const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(secondPages(), 1);
    expect(find.text('載入失敗，點此重試'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, 300));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(secondPages(), 1, reason: '失敗後捲動不自動重打');

    fail = false;
    await tester.tap(find.text('載入失敗，點此重試'));
    await tester.pumpAndSettle();
    expect(secondPages(), 2);
    expect(find.text('載入失敗，點此重試'), findsNothing);
  });

  testWidgets('USER_NOT_FOUND 顯示後端 message', (tester) async {
    install(
      transactionsError: errorResponse(
        'USER_NOT_FOUND',
        status: 404,
        message: '找不到這位使用者',
      ),
    );
    await lookUp(tester);

    expect(find.text('找不到這位使用者'), findsOneWidget);
    expect(find.byType(MilletTransactionRow), findsNothing);
  });
}
