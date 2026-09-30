import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/main.dart' show navigatorKey;
import 'package:flutter_application_1/screens/account/account_delete_screen.dart';
import 'package:flutter_application_1/screens/terms/terms_consent_screen.dart';

const _jsonHeaders = {'content-type': 'application/json; charset=utf-8'};

Map<String, dynamic> _doc(
  String type, {
  int version = 1,
  bool consented = false,
  String? content,
}) => {
  'doc_type': type,
  'version': version,
  'title': type == 'tos' ? '服務條款' : '隱私權政策',
  'content_md': content ?? '$type 內文 v$version',
  'published_at': '2026-08-01T00:00:00.000Z',
  'consented': consented,
  'consented_version': consented ? version : null,
};

String _longContent(String prefix) =>
    List.generate(80, (i) => '$prefix $i 段').join('\n\n');

http.Response _ok(Object body) =>
    http.Response(jsonEncode(body), 200, headers: _jsonHeaders);

http.Response _err(int status, String code, {Map<String, dynamic>? extra}) =>
    http.Response(
      jsonEncode({
        'error': {'code': code, 'message': code},
        ...?extra,
      }),
      status,
      headers: _jsonHeaders,
    );

/// ApiClient 靠 resp.request 的路徑判斷要不要導頁，MockClient 不會幫忙帶。
http.Response _withRequest(http.Response r, http.Request req) =>
    http.Response(r.body, r.statusCode, headers: r.headers, request: req);

/// GET /api/terms/:type 回 [docs] 內對應的文件（沒有的回 404 TERMS_NOT_FOUND），
/// POST 交給 [onConsent]。
MockClient _server(
  Map<String, Map<String, dynamic>> docs, {
  http.Response Function(http.Request req)? onConsent,
  List<String>? log,
}) => MockClient((req) async {
  log?.add('${req.method} ${req.url.path}');
  if (req.method == 'POST') return _withRequest(onConsent!(req), req);
  if (!req.url.path.startsWith('/api/terms/')) return _err(404, 'NOT_FOUND');
  final d = docs[req.url.pathSegments.last];
  if (d == null) return _err(404, 'TERMS_NOT_FOUND');
  return _ok({
    'document': d,
    'all_consented': docs.values.every((x) => x['consented'] == true),
  });
});

Future<void> _pumpScreen(WidgetTester tester, {bool readOnly = false}) async {
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigatorKey,
      routes: {
        '/': (_) => TermsConsentScreen(readOnly: readOnly),
        '/home': (_) => const Scaffold(body: Text('HOME')),
        '/terms-consent': (_) => const Scaffold(body: Text('LOOP')),
      },
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async => null,
        );
  });

  tearDown(() => ApiClient.httpClient = http.Client());

  ElevatedButton button(WidgetTester tester) =>
      tester.widget<ElevatedButton>(find.byType(ElevatedButton));

  testWidgets('兩份都未同意：一次一份，同意後才進下一份，最後進首頁', (tester) async {
    final log = <String>[];
    final bodies = <String>[];
    ApiClient.httpClient = _server(
      {'tos': _doc('tos'), 'privacy': _doc('privacy')},
      log: log,
      onConsent: (req) {
        bodies.add('${req.url.path} ${req.body}');
        final type = req.url.pathSegments[2];
        return _ok({
          'document': _doc(type, consented: true),
          'all_consented': type == 'privacy',
        });
      },
    );

    await _pumpScreen(tester);

    expect(find.text('第 1 份／共 2 份'), findsOneWidget);
    expect(find.text('tos 內文 v1'), findsOneWidget);
    expect(find.text('privacy 內文 v1'), findsNothing);
    expect(find.byType(TabBar), findsNothing);

    await tester.tap(find.text('同意《服務條款》'));
    await tester.pumpAndSettle();

    expect(bodies, ['/api/terms/tos/consent {"version":1}']);
    expect(find.text('第 2 份／共 2 份'), findsOneWidget);
    expect(find.text('privacy 內文 v1'), findsOneWidget);
    expect(find.text('HOME'), findsNothing);

    await tester.tap(find.text('同意《隱私權政策》'));
    await tester.pumpAndSettle();

    expect(bodies.last, '/api/terms/privacy/consent {"version":1}');
    expect(find.text('HOME'), findsOneWidget);
    expect(log.contains('POST /api/terms/consent'), isFalse);
  });

  testWidgets('只有一份改版：已同意的那份不出現，顯示第 1 份／共 1 份', (tester) async {
    ApiClient.httpClient = _server(
      {
        'tos': _doc('tos', version: 2),
        'privacy': _doc('privacy', consented: true),
      },
      onConsent: (req) => _ok({
        'document': _doc('tos', version: 2, consented: true),
        'all_consented': true,
      }),
    );

    await _pumpScreen(tester);

    expect(find.text('第 1 份／共 1 份'), findsOneWidget);
    expect(find.text('tos 內文 v2'), findsOneWidget);
    expect(find.text('同意《隱私權政策》'), findsNothing);

    await tester.tap(find.text('同意《服務條款》'));
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('兩份都已同意時直接離開同意畫面', (tester) async {
    ApiClient.httpClient = _server({
      'tos': _doc('tos', consented: true),
      'privacy': _doc('privacy', consented: true),
    });

    await _pumpScreen(tester);

    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('某種條款尚未發布（404）時略過，不當錯誤', (tester) async {
    ApiClient.httpClient = _server({'tos': _doc('tos')});

    await _pumpScreen(tester);

    expect(find.text('重試'), findsNothing);
    expect(find.text('第 1 份／共 1 份'), findsOneWidget);
    expect(find.text('tos 內文 v1'), findsOneWidget);
  });

  testWidgets('兩種條款都沒發布時顯示「目前沒有條款內容」', (tester) async {
    ApiClient.httpClient = _server({});

    await _pumpScreen(tester);

    expect(find.text('重試'), findsNothing);
    expect(find.text('目前沒有條款內容'), findsOneWidget);
  });

  testWidgets('內容超過一頁時捲到底才解鎖同意按鈕', (tester) async {
    ApiClient.httpClient = _server({
      'tos': _doc('tos', content: _longContent('段落')),
    });

    await _pumpScreen(tester);

    expect(button(tester).onPressed, isNull);
    expect(find.text('請先閱讀至《服務條款》最下方'), findsOneWidget);

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -20000),
    );
    await tester.pumpAndSettle();

    expect(button(tester).onPressed, isNotNull);
    expect(find.text('請先閱讀至《服務條款》最下方'), findsNothing);
  });

  testWidgets('送出時 409：換成最新版、停在該份、需重新捲到底', (tester) async {
    ApiClient.httpClient = _server(
      {'tos': _doc('tos'), 'privacy': _doc('privacy')},
      onConsent: (req) => _err(
        409,
        'TERMS_VERSION_OUTDATED',
        extra: {
          'documents': [
            _doc('tos', version: 2, content: _longContent('新')),
            _doc('privacy'),
          ],
          'all_consented': false,
        },
      ),
    );

    await _pumpScreen(tester);
    await tester.tap(find.text('同意《服務條款》'));
    await tester.pumpAndSettle();

    expect(find.text('第 1 份／共 2 份'), findsOneWidget);
    expect(find.text('第 2 版'), findsOneWidget);
    expect(button(tester).onPressed, isNull);
  });

  testWidgets('最後一份同意成功但 all_consented 為 false：重新載入剩下的且需重新捲到底', (tester) async {
    var tosVersion = 1;
    var privacyConsented = false;
    ApiClient.httpClient = MockClient((req) async {
      final type = req.url.pathSegments.last == 'consent'
          ? req.url.pathSegments[2]
          : req.url.pathSegments.last;
      final d = type == 'tos'
          ? _doc('tos', version: tosVersion, content: _longContent('段落'))
          : _doc('privacy', consented: privacyConsented);
      if (req.method == 'POST') {
        // privacy 送出的同時 tos 剛好出新版。
        tosVersion = 2;
        privacyConsented = true;
        return _withRequest(
          _ok({
            'document': _doc('privacy', consented: true),
            'all_consented': false,
          }),
          req,
        );
      }
      return _ok({'document': d, 'all_consented': false});
    });

    await _pumpScreen(tester);
    // tos 內容較長，先捲到底才能同意。
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -20000),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('同意《服務條款》'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('同意《隱私權政策》'));
    await tester.pumpAndSettle();

    expect(find.text('HOME'), findsNothing);
    expect(find.text('第 1 份／共 1 份'), findsOneWidget);
    expect(find.text('第 2 版'), findsOneWidget);
    expect(button(tester).onPressed, isNull);
  });

  testWidgets('同意畫面送出被回 403 CONSENT_REQUIRED 不會再導去同意畫面', (tester) async {
    ApiClient.httpClient = _server({
      'tos': _doc('tos'),
    }, onConsent: (req) => _err(403, 'CONSENT_REQUIRED'));

    await _pumpScreen(tester);
    await tester.tap(find.text('同意《服務條款》'));
    await tester.pumpAndSettle();

    expect(find.text('LOOP'), findsNothing);
    expect(find.byType(TermsConsentScreen), findsOneWidget);
  });

  testWidgets('唯讀模式以 TabBar 顯示兩份（含已同意的），沒有同意按鈕', (tester) async {
    ApiClient.httpClient = _server({
      'tos': _doc('tos', consented: true),
      'privacy': _doc('privacy', consented: true),
    });

    await _pumpScreen(tester, readOnly: true);

    expect(find.byType(TabBar), findsOneWidget);
    expect(find.text('tos 內文 v1'), findsOneWidget);

    await tester.tap(
      find.descendant(of: find.byType(TabBar), matching: find.text('隱私權政策')),
    );
    await tester.pumpAndSettle();

    expect(find.text('privacy 內文 v1'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsNothing);
    expect(find.text('HOME'), findsNothing);
  });

  testWidgets('條文內文開頭與標題重複時不重複顯示標題', (tester) async {
    ApiClient.httpClient = _server({
      'tos': _doc('tos', content: '# 服務條款\n\n最後更新日期：2026年08月23日'),
    });

    await _pumpScreen(tester);

    expect(find.text('服務條款'), findsOneWidget);
    expect(find.textContaining('最後更新日期'), findsOneWidget);
  });

  testWidgets('沒捲到底也能按「不同意，刪除帳號」，開刪除帳號確認頁', (tester) async {
    ApiClient.httpClient = _server({
      'tos': _doc('tos', content: _longContent('段落')),
    });

    await _pumpScreen(tester);
    expect(button(tester).onPressed, isNull);

    await tester.tap(find.text('不同意，刪除帳號'));
    await tester.pumpAndSettle();

    expect(find.byType(AccountDeleteScreen), findsOneWidget);
  });

  testWidgets('沒同意也能按「下載我的資料」，匯出後留在同意畫面', (tester) async {
    final log = <String>[];
    ApiClient.httpClient = MockClient((req) async {
      log.add('${req.method} ${req.url.path}');
      if (req.url.path == '/api/account/export') {
        return _withRequest(_ok({'user': {}}), req);
      }
      return _ok({'document': _doc('tos'), 'all_consented': false});
    });

    await _pumpScreen(tester);
    await tester.tap(find.text('下載我的資料'));
    await tester.pumpAndSettle();

    expect(log, contains('GET /api/account/export'));
    expect(find.text('LOOP'), findsNothing);
    expect(find.text('同意《服務條款》'), findsOneWidget);
  });

  testWidgets('唯讀檢視沒有刪除帳號與下載資料的入口', (tester) async {
    ApiClient.httpClient = _server({'tos': _doc('tos', consented: true)});

    await _pumpScreen(tester, readOnly: true);

    expect(find.text('不同意，刪除帳號'), findsNothing);
    expect(find.text('下載我的資料'), findsNothing);
  });

  testWidgets('端點失敗時顯示錯誤與重試', (tester) async {
    ApiClient.httpClient = MockClient((_) async => _err(500, 'INTERNAL'));

    await _pumpScreen(tester);

    expect(find.text('重試'), findsOneWidget);
  });
}
