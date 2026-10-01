// 共用回報面板：失敗時面板與內容保留、錯誤轉譯回呼、字數上限依參數。
// 論壇檢舉的既有行為由 forum_report_sheet_test.dart 涵蓋。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/shared/widgets/report_sheet.dart';

void main() {
  late bool? result;

  Future<void> open(
    WidgetTester tester, {
    required Future<void> Function(String reason) onSubmit,
    String Function(Object error)? errorMessage,
    int maxLength = 500,
  }) async {
    result = null;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async => result = await showReportSheet(
                context,
                title: '檢舉此訊息',
                description: '請說明檢舉的原因，管理員會再確認。',
                hintText: '例如：騷擾、詐騙',
                submitLabel: '送出檢舉',
                successMessage: '已送出檢舉',
                maxLength: maxLength,
                onSubmit: onSubmit,
                errorMessage: errorMessage,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> typeAndSubmit(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pump();
    await tester.tap(find.text('送出檢舉'));
    await tester.pumpAndSettle();
  }

  testWidgets('成功：送出去頭尾空白的內容、關面板、提示成功並回傳 true', (tester) async {
    String? sent;
    await open(tester, onSubmit: (reason) async => sent = reason);

    await typeAndSubmit(tester, '  騷擾  ');

    expect(sent, '騷擾');
    expect(find.text('檢舉此訊息'), findsNothing);
    expect(find.text('已送出檢舉'), findsOneWidget);
    expect(result, isTrue);
  });

  testWidgets('失敗：面板保留、內容還在，顯示後端訊息', (tester) async {
    await open(
      tester,
      onSubmit: (_) async => throw ApiException(
        statusCode: 429,
        code: 'RATE_LIMITED',
        message: '操作太頻繁',
      ),
    );

    await typeAndSubmit(tester, '騷擾');

    expect(find.text('檢舉此訊息'), findsOneWidget);
    expect(find.text('操作太頻繁'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '騷擾',
    );
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNotNull, reason: '失敗後可以再送一次');
  });

  testWidgets('錯誤轉譯回呼生效', (tester) async {
    await open(
      tester,
      onSubmit: (_) async => throw StateError('boom'),
      errorMessage: (_) => '找不到此題目，可能資料已異動',
    );

    await typeAndSubmit(tester, '答案有誤');

    expect(find.text('找不到此題目，可能資料已異動'), findsOneWidget);
  });

  testWidgets('直接關掉面板回傳 false', (tester) async {
    await open(tester, onSubmit: (_) async {});

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.text('檢舉此訊息'), findsNothing);
    expect(result, isFalse);
  });

  testWidgets('字數上限依參數，超過的部分輸入不進去', (tester) async {
    await open(tester, onSubmit: (_) async {}, maxLength: 5);

    await tester.enterText(find.byType(TextField), '一二三四五六七');
    await tester.pump();

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '一二三四五',
    );
    expect(find.text('5/5'), findsOneWidget);
  });
}
