// 取代的人工重測：
//   「用未登入／資料未完善／未同意條款／正常四種帳號狀態各開一次 App，
//     看啟動畫面會把我帶去哪一頁」
//
// 這是最花時間的手動驗證之一（要反覆改後端資料或換帳號），而且改動 splash
// 的分支很容易漏掉其中一條。這裡用假回應把四條分支一次跑完。
//
// 做法：不呼叫 main()（會碰 Firebase / FCM），改用 buildTestApp 組一個
// 等價的 MaterialApp，並把四個目的地換成假畫面 —— 只驗「導到哪」，
// 不連帶 render 真正的登入頁或首頁。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fixtures.dart';
import '../helpers/flow_test_helpers.dart';
import '../helpers/widget_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(resetGlobals);
  tearDown(() {
    restoreHttp();
    resetGlobals();
  });

  /// splash 的四個可能目的地都換成假畫面，斷言時找文字即可。
  Widget app() => buildTestApp(
    initialRoute: '/splash',
    overrides: {
      '/login': (_) => fakeRoute('LOGIN'),
      '/complete-profile': (_) => fakeRoute('COMPLETE_PROFILE'),
      '/terms-consent': (_) => fakeRoute('TERMS'),
      '/home': (_) => fakeRoute('HOME'),
    },
  );

  /// splash 的分支包在 `Future.delayed(2500ms)` 裡（splash_screen.dart:32），
  /// 一定要先把時間推過去。pumpAndSettle 在這裡不能用。
  Future<void> pumpPastSplashDelay(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await pumpFrames(tester);
  }

  testWidgets('未登入時導向登入頁，且不會去打任何 API', (tester) async {
    // 不給 token = 未登入。此時 splash 應該在查任何帳號資料之前就導走。
    stubCommonChannels();
    installMockClient(const {});

    await tester.pumpWidget(app());
    await pumpPastSplashDelay(tester);

    expect(find.text('LOGIN'), findsOneWidget);
  });

  testWidgets('已登入但資料未完善時導向完善資料頁', (tester) async {
    stubCommonChannels(token: 'test-token');
    final me = loadFixtureMap('get_api_me.json')..['profile_completed'] = false;
    installMockClient({
      '/api/account/status': loadFixtureMap('get_api_account_status.json'),
      '/api/me': me,
      '/api/terms': loadFixtureMap('get_api_terms.json'),
    });

    await tester.pumpWidget(app());
    await pumpPastSplashDelay(tester);

    expect(find.text('COMPLETE_PROFILE'), findsOneWidget);
  });

  testWidgets('資料已完善但條款未全同意時導向條款頁', (tester) async {
    stubCommonChannels(token: 'test-token');
    final terms = loadFixtureMap('get_api_terms.json')
      ..['all_consented'] = false;
    installMockClient({
      '/api/account/status': loadFixtureMap('get_api_account_status.json'),
      '/api/me': loadFixtureMap('get_api_me.json'),
      '/api/terms': terms,
    });

    await tester.pumpWidget(app());
    await pumpPastSplashDelay(tester);

    expect(find.text('TERMS'), findsOneWidget);
  });

  testWidgets('狀態都正常時導向首頁', (tester) async {
    stubCommonChannels(token: 'test-token');
    installMockClient({
      '/api/account/status': loadFixtureMap('get_api_account_status.json'),
      '/api/me': loadFixtureMap('get_api_me.json'),
      '/api/terms': loadFixtureMap('get_api_terms.json'),
    });

    await tester.pumpWidget(app());
    await pumpPastSplashDelay(tester);

    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('帳號狀態查詢失敗不擋啟動，仍然進得了首頁（離線容錯）', (tester) async {
    // splash_screen.dart:42-46 刻意把 /api/account/status 的失敗吞掉，
    // 免得連不上網就卡在啟動畫面。這條容錯很容易在重構時被弄掉。
    stubCommonChannels(token: 'test-token');
    installMockClient({
      '/api/account/status': errorResponse('SERVER_ERROR', status: 500),
      '/api/me': loadFixtureMap('get_api_me.json'),
      '/api/terms': loadFixtureMap('get_api_terms.json'),
    });

    await tester.pumpWidget(app());
    await pumpPastSplashDelay(tester);

    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('帳號被鎖定時進首頁且帶著唯讀橫幅', (tester) async {
    // 橫幅掛在 MaterialApp.builder，所以 splash 導完頁就該看得到。
    stubCommonChannels(token: 'test-token');
    final status = loadFixtureMap('get_api_account_status.json')
      ..['status'] = 'locked';
    installMockClient({
      '/api/account/status': status,
      '/api/me': loadFixtureMap('get_api_me.json'),
      '/api/terms': loadFixtureMap('get_api_terms.json'),
    });

    await tester.pumpWidget(app());
    await pumpPastSplashDelay(tester);

    expect(find.text('HOME'), findsOneWidget);
    expect(find.text(readOnlyBannerText), findsOneWidget);
  });
}
