// 關於頁「資料來源與授權」區塊：內容全部來自 GET /api/data-sources。
// 成功時逐字顯示每筆來源、連結用外部瀏覽器開；失敗時只顯示失敗文案，
// 不能冒出任何寫死的來源文字；窄螢幕一般／長輩模式都不 overflow。

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/screens/profile/about_app_screen.dart';
import 'package:flutter_application_1/services/senior_mode_controller.dart';

import '../helpers/fixtures.dart';
import '../helpers/flow_test_helpers.dart';
import '../helpers/widget_test_helpers.dart';

const _fixture = 'get_api_data_sources.json';
const _path = '/api/data-sources';
const _failureText = '暫時無法載入資料來源，請稍後再試';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  final json = loadFixtureMap(_fixture);
  final sources = loadFixtureList(_fixture, 'sources');

  setUp(stubSecureStorage);
  tearDown(restoreHttp);

  /// 打開關於頁、等 API 回來，並捲到最底下的資料來源區塊。
  Future<void> pumpAbout(WidgetTester tester) async {
    usePhoneSurface(tester, size: const Size(320, 800));
    await tester.pumpWidget(const MaterialApp(home: AboutAppScreen()));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -8000));
    await tester.pumpAndSettle();
  }

  testWidgets('成功：依序顯示每筆名稱、用途與完整標示，沒有連結的來源不出現連結', (tester) async {
    installMockClient({_path: json});
    await pumpAbout(tester);

    expect(find.text(json['title'] as String), findsOneWidget);
    double? lastY;
    for (final s in sources) {
      final name = find.text(s['name'] as String);
      expect(name, findsOneWidget);
      final y = tester.getTopLeft(name).dy;
      if (lastY != null) expect(y, greaterThan(lastY), reason: '要照回應順序排');
      lastY = y;
      expect(find.text(s['attribution'] as String), findsOneWidget);
      for (final tag in s['used_for'] as List) {
        expect(find.text(tag as String), findsWidgets);
      }
    }
    final linkCount = sources.fold<int>(
      0,
      (n, s) => n + (s['links'] as List).length,
    );
    expect(find.byIcon(Icons.open_in_new), findsNWidgets(linkCount));
    expect(find.text(_failureText), findsNothing);
  });

  testWidgets('點連結用外部瀏覽器開對應網址，開不了時提示', (tester) async {
    final calls = <MethodCall>[];
    var result = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/url_launcher'),
          (call) async {
            calls.add(call);
            return result;
          },
        );
    installMockClient({_path: json});
    await pumpAbout(tester);

    final firstLink = (sources.first['links'] as List).first as Map;
    await tester.tap(find.byIcon(Icons.open_in_new).first);
    await tester.pumpAndSettle();
    expect(calls.single.arguments['url'], firstLink['url']);
    expect(calls.single.arguments['useWebView'], isFalse);
    expect(find.text('無法開啟連結'), findsNothing);

    result = false;
    await tester.tap(find.byIcon(Icons.open_in_new).first);
    await tester.pumpAndSettle();
    expect(find.text('無法開啟連結'), findsOneWidget);
  });

  testWidgets('讀取中顯示載入指示，品牌內容已經出現', (tester) async {
    installMockClient({
      _path: json,
    }, delayFor: (_) => const Duration(seconds: 1));
    usePhoneSurface(tester, size: const Size(320, 800));
    await tester.pumpWidget(const MaterialApp(home: AboutAppScreen()));
    await tester.pump();

    final loader = find.byType(CircularProgressIndicator, skipOffstage: false);
    expect(find.text('我們的使命'), findsOneWidget);
    expect(loader, findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(loader, findsNothing);
  });

  testWidgets('讀取失敗：只顯示失敗文案，不出現任何來源文字', (tester) async {
    installMockClient({_path: errorResponse('INTERNAL', status: 500)});
    await pumpAbout(tester);

    expect(find.text(_failureText), findsOneWidget);
    expect(find.text('資料來源與授權'), findsOneWidget);
    for (final s in sources) {
      expect(find.text(s['name'] as String, skipOffstage: false), findsNothing);
    }
    expect(find.byIcon(Icons.open_in_new), findsNothing);
  });

  for (final senior in [false, true]) {
    group(senior ? '長輩模式' : '一般模式', () {
      // 在 testWidgets 的 FakeAsync 內切換會卡住，改在 setUp 切。
      setUp(() => seniorModeController.setEnabled(senior));
      tearDown(() => seniorModeController.setEnabled(false));

      testWidgets('320dp 寬度顯示完整區塊不 overflow', (tester) async {
        expect(seniorModeController.enabled, senior);
        installMockClient({_path: json});
        await pumpAbout(tester);
        expect(find.text(sources.last['name'] as String), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
  }
}
