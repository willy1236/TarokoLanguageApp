import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/screens/forum/widgets/forum_report_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ApiClient 內部經由 AuthService.currentToken() 讀取 flutter_secure_storage，
  // 該套件在測試環境沒有原生實作，需 mock method channel 讓它回傳 null（視為未登入）。
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
  });

  tearDown(() => ApiClient.httpClient = http.Client());

  testWidgets('填寫理由後送出，帶上 target_type 與 target_id', (tester) async {
    Map<String, dynamic>? sent;
    ApiClient.httpClient = MockClient((req) async {
      sent = jsonDecode(req.body) as Map<String, dynamic>;
      return http.Response(jsonEncode({'ok': true}), 201);
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showForumReportSheet(
              context,
              targetType: 'comment',
              targetId: 11,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '廣告');
    // enterText 送出的文字輸入更新是非同步流程，需先 pump 讓 onChanged
    // 觸發 setState 並重新 build，送出鈕才會從 disabled 轉為可按，
    // 否則緊接著的 tap 會落在還沒更新的按鈕上而完全沒有效果。
    await tester.pump();
    await tester.tap(find.text('送出檢舉'));
    await tester.pumpAndSettle();

    expect(sent, {'target_type': 'comment', 'target_id': 11, 'reason': '廣告'});
    expect(find.text('已收到檢舉'), findsOneWidget);
  });

  testWidgets('理由留空時送出鈕不可按', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showForumReportSheet(
              context,
              targetType: 'post',
              targetId: 1,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });
}
