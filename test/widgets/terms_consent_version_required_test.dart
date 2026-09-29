// 條款 400 VERSION_REQUIRED：後端要求帶版本號，收到代表 App 太舊，請使用者更新。

import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/screens/terms/terms_consent_screen.dart';

import '../helpers/widget_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(stubSecureStorage);
  tearDown(restoreHttp);

  testWidgets('送出收到 400 VERSION_REQUIRED 時提示更新 App', (tester) async {
    ApiClient.httpClient = MockClient((req) async {
      if (req.method == 'GET') {
        if (req.url.path != '/api/terms/tos') {
          return errorResponse('TERMS_NOT_FOUND', status: 404);
        }
        return jsonResponse({
          'document': {
            'doc_type': 'tos',
            'version': 1,
            'title': '服務條款',
            'content_md': '內容',
            'published_at': '2026-09-01T00:00:00.000Z',
            'consented': false,
            'consented_version': null,
          },
          'all_consented': false,
        });
      }
      return errorResponse('VERSION_REQUIRED', message: 'versions is required');
    });

    await tester.pumpWidget(wrapScreen(const TermsConsentScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('同意《服務條款》'));
    await tester.pumpAndSettle();

    expect(find.text('請更新 App 到最新版'), findsOneWidget);
    expect(find.text('versions is required'), findsNothing);
  });
}
