// 條款 409 TERMS_VERSION_OUTDATED：同意紀錄在法律上要站得住，
// 送出的必須是使用者畫面上看到的版本，後台改版時要換成新版並要求重新同意。

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/screens/terms/terms_consent_screen.dart';

import '../helpers/widget_test_helpers.dart';

Map<String, dynamic> _doc(int version) => {
  'doc_type': 'tos',
  'version': version,
  'title': '服務條款',
  // 新版夠長才需要重新捲到底；短內容首次排版就算讀完。
  'content_md': version == 1
      ? '第 1 版內容'
      : List.generate(80, (i) => '第 $i 段').join('\n\n'),
  'published_at': '2026-09-01T00:00:00.000Z',
  'consented': false,
  'consented_version': null,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<http.Request> posts;

  setUp(() {
    stubSecureStorage();
    posts = [];
    ApiClient.httpClient = MockClient((req) async {
      final Object body;
      final int status;
      if (req.method == 'GET') {
        if (req.url.path == '/api/terms/tos') {
          body = {'document': _doc(1), 'all_consented': false};
          status = 200;
        } else {
          body = {
            'error': {'code': 'TERMS_NOT_FOUND', 'message': '尚未發布'},
          };
          status = 404;
        }
      } else {
        posts.add(req);
        // 對齊後端 routes/terms.ts：最新狀態攤在回應最外層。
        body = {
          'error': {
            'code': 'TERMS_VERSION_OUTDATED',
            'message': '條款已更新，請重新閱讀最新版本後再同意',
          },
          'documents': [_doc(2)],
          'all_consented': false,
        };
        status = 409;
      }
      return http.Response(
        jsonEncode(body),
        status,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
  });

  tearDown(() => ApiClient.httpClient = http.Client());

  ElevatedButton agreeButton(WidgetTester tester) =>
      tester.widget<ElevatedButton>(find.byType(ElevatedButton));

  testWidgets('送出畫面上的版本；409 後換成新版並要求重新同意', (tester) async {
    await tester.pumpWidget(wrapScreen(const TermsConsentScreen()));
    await tester.pumpAndSettle();

    expect(find.text('第 1 版'), findsOneWidget);
    expect(agreeButton(tester).onPressed, isNotNull);

    await tester.tap(find.text('同意《服務條款》'));
    await tester.pumpAndSettle();

    expect(posts, hasLength(1));
    expect(posts.single.url.path, '/api/terms/tos/consent');
    expect(jsonDecode(posts.single.body), {'version': 1});

    expect(find.text('第 2 版'), findsOneWidget);
    expect(find.text('第 1 版'), findsNothing);
    expect(find.text('條款已更新，請重新閱讀最新版本後再同意'), findsOneWidget);
    // 版本變了：閱讀進度被清掉，要重新捲到底才能同意。
    expect(agreeButton(tester).onPressed, isNull);
  });
}
