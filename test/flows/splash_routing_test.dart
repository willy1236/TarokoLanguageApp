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

import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/session_service.dart';
import 'package:flutter_application_1/shared/widgets/truku_widgets.dart';

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
      '/birth-date': (_) => fakeRoute('BIRTH_DATE'),
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

  testWidgets('舊使用者要補填出生日期時導向補填頁，先於條款', (tester) async {
    stubCommonChannels(token: 'test-token');
    final me = loadFixtureMap('get_api_me.json')
      ..['birth_date'] = null
      ..['needs_birth_date'] = true;
    final terms = loadFixtureMap('get_api_terms.json')
      ..['all_consented'] = false;
    installMockClient({
      '/api/account/status': loadFixtureMap('get_api_account_status.json'),
      '/api/me': me,
      '/api/terms': terms,
    });

    await tester.pumpWidget(app());
    await pumpPastSplashDelay(tester);

    expect(find.text('BIRTH_DATE'), findsOneWidget);
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

  group('JWT 已過期', () {
    final past = DateTime.now()
        .subtract(const Duration(days: 1))
        .toIso8601String();
    final realRefresh = SessionService.refreshSession;
    final realDeleteLocal = SessionService.deleteLocalToken;
    final realClearAuth = SessionService.clearAuth;
    late List<String> signOutCalls;
    late RefreshOutcome outcome;

    setUp(() {
      stubCommonChannels(token: 'test-token', expiresAt: past);
      signOutCalls = [];
      outcome = RefreshOutcome.offline;
      SessionService.refreshSession = () async => outcome;
      SessionService.deleteLocalToken = () async =>
          signOutCalls.add('deleteLocal');
      SessionService.clearAuth = () async => signOutCalls.add('clearAuth');
    });
    tearDown(() {
      SessionService.refreshSession = realRefresh;
      SessionService.deleteLocalToken = realDeleteLocal;
      SessionService.clearAuth = realClearAuth;
    });

    testWidgets('啟動時離線：顯示無法連線與重試，不導頁也不登出', (tester) async {
      installMockClient(const {});

      await tester.pumpWidget(app());
      await pumpPastSplashDelay(tester);

      expect(find.text('無法連線，請檢查網路'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, '重試'), findsOneWidget);
      expect(find.text('LOGIN'), findsNothing);
      expect(signOutCalls, isEmpty);
    });

    for (final (label, size, scale) in [
      ('iPhone SE 1 代 320×568', const Size(320, 568), 1.0),
      ('360×640、字體放大 1.3 倍', const Size(360, 640), 1.3),
      ('iPhone SE 375×667、字體放大 1.3 倍', const Size(375, 667), 1.3),
      ('iPhone SE 1 代 320×568、字體放大 1.5 倍（長輩模式上限）', const Size(320, 568), 1.5),
    ]) {
      testWidgets('小螢幕 $label：重試區在 logo 文字與菱形鏈下方、不超出畫面', (tester) async {
        usePhoneSurface(tester, size: size);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        installMockClient(const {});

        await tester.pumpWidget(app());
        await pumpPastSplashDelay(tester);
        // 等 logo 上移動畫跑完再量。
        await tester.pump(const Duration(milliseconds: 400));

        final logoText = tester.getRect(find.text('Kari Truku · Lnglungan'));
        final chain = tester.getRect(find.byType(TrukuChain).last);
        final message = tester.getRect(find.text('無法連線，請檢查網路'));
        final button = tester.getRect(
          find.widgetWithText(OutlinedButton, '重試'),
        );
        expect(chain.top, greaterThanOrEqualTo(logoText.bottom));
        expect(message.top, greaterThan(chain.bottom));
        expect(button.top, greaterThan(message.bottom));
        expect(button.bottom, lessThanOrEqualTo(size.height));
        expect(find.text('說我們的話 · 走我們的山'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('按重試且網路恢復後續期成功，照常進首頁', (tester) async {
      installMockClient({
        '/api/account/status': loadFixtureMap('get_api_account_status.json'),
        '/api/me': loadFixtureMap('get_api_me.json'),
        '/api/terms': loadFixtureMap('get_api_terms.json'),
      });
      await tester.pumpWidget(app());
      await pumpPastSplashDelay(tester);

      outcome = RefreshOutcome.ok;
      await tester.tap(find.widgetWithText(OutlinedButton, '重試'));
      await pumpFrames(tester);

      expect(find.text('HOME'), findsOneWidget);
      expect(signOutCalls, isEmpty);
    });

    testWidgets('按重試仍離線：回到重試畫面', (tester) async {
      installMockClient(const {});
      await tester.pumpWidget(app());
      await pumpPastSplashDelay(tester);

      await tester.tap(find.widgetWithText(OutlinedButton, '重試'));
      await pumpFrames(tester);

      expect(find.text('無法連線，請檢查網路'), findsOneWidget);
      expect(find.text('LOGIN'), findsNothing);
    });

    testWidgets('按重試後條款未同意：導向條款頁', (tester) async {
      installMockClient({
        '/api/account/status': loadFixtureMap('get_api_account_status.json'),
        '/api/me': loadFixtureMap('get_api_me.json'),
        '/api/terms': loadFixtureMap('get_api_terms.json')
          ..['all_consented'] = false,
      });
      await tester.pumpWidget(app());
      await pumpPastSplashDelay(tester);

      outcome = RefreshOutcome.ok;
      await tester.tap(find.widgetWithText(OutlinedButton, '重試'));
      await pumpFrames(tester);

      expect(find.text('TERMS'), findsOneWidget);
    });

    testWidgets('網路正常但續期被拒絕：完整登出並進登入頁', (tester) async {
      outcome = RefreshOutcome.rejected;
      installMockClient(const {});

      await tester.pumpWidget(app());
      await pumpPastSplashDelay(tester);

      expect(find.text('LOGIN'), findsOneWidget);
      expect(signOutCalls, ['deleteLocal', 'clearAuth']);
      expect(find.text('無法連線，請檢查網路'), findsNothing);
    });
  });
}
