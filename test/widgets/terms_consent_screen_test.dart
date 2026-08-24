import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/screens/terms/terms_consent_screen.dart';

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

  testWidgets('有條款內容時顯示標題與內文', (tester) async {
    ApiClient.httpClient = MockClient((req) async {
      expect(req.url.path, '/api/terms');
      return http.Response(
        jsonEncode({
          'documents': [
            {
              'doc_type': 'tos',
              'version': 1,
              'title': '服務條款',
              'content_md': '這是服務條款內文',
              'published_at': '2026-08-01T00:00:00.000Z',
              'consented': false,
              'consented_version': null,
            },
          ],
          'all_consented': false,
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    await tester.pumpWidget(const MaterialApp(home: TermsConsentScreen()));
    await tester.pumpAndSettle();

    expect(find.text('服務條款'), findsOneWidget);
    expect(find.text('這是服務條款內文'), findsOneWidget);
  });

  testWidgets('條文內文開頭與標題重複時不重複顯示標題', (tester) async {
    ApiClient.httpClient = MockClient((req) async {
      return http.Response(
        jsonEncode({
          'documents': [
            {
              'doc_type': 'tos',
              'version': 1,
              'title': '織語者 服務條款',
              'content_md': '# 織語者 服務條款\n\n最後更新日期：2026年08月23日',
              'published_at': '2026-08-01T00:00:00.000Z',
              'consented': false,
              'consented_version': null,
            },
          ],
          'all_consented': false,
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    await tester.pumpWidget(const MaterialApp(home: TermsConsentScreen()));
    await tester.pumpAndSettle();

    expect(find.text('織語者 服務條款'), findsOneWidget);
    expect(find.textContaining('最後更新日期'), findsOneWidget);
  });

  testWidgets('唯讀檢視帶 titleKeyword 時只顯示對應的單一文件', (tester) async {
    ApiClient.httpClient = MockClient((req) async {
      return http.Response(
        jsonEncode({
          'documents': [
            {
              'doc_type': 'tos',
              'version': 1,
              'title': '織語者 服務條款',
              'content_md': '服務條款內文',
              'published_at': '2026-08-01T00:00:00.000Z',
              'consented': true,
              'consented_version': 1,
            },
            {
              'doc_type': 'privacy',
              'version': 1,
              'title': '織語者 隱私權政策',
              'content_md': '隱私權政策內文',
              'published_at': '2026-08-01T00:00:00.000Z',
              'consented': true,
              'consented_version': 1,
            },
          ],
          'all_consented': true,
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: TermsConsentScreen(readOnly: true, titleKeyword: '隱私權政策'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('織語者 隱私權政策'), findsOneWidget);
    expect(find.text('隱私權政策內文'), findsOneWidget);
    expect(find.text('織語者 服務條款'), findsNothing);
    expect(find.text('服務條款內文'), findsNothing);
    // 唯讀檢視不出現同意按鈕。
    expect(find.text('我已閱讀並同意'), findsNothing);
  });

  testWidgets('後端回傳空 documents 時顯示「目前沒有條款內容」提示', (tester) async {
    ApiClient.httpClient = MockClient(
      (_) async => http.Response(
        jsonEncode({'documents': [], 'all_consented': true}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );

    await tester.pumpWidget(const MaterialApp(home: TermsConsentScreen()));
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('重試'), findsNothing);
    expect(find.text('目前沒有條款內容'), findsOneWidget);
  });

  testWidgets('端點失敗時顯示錯誤與重試', (tester) async {
    ApiClient.httpClient = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'error': {'code': 'NOT_FOUND', 'message': '找不到資源'},
        }),
        404,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );

    await tester.pumpWidget(const MaterialApp(home: TermsConsentScreen()));
    await tester.pumpAndSettle();

    expect(find.text('重試'), findsOneWidget);
  });
}
