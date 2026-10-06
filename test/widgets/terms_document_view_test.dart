// 條款顯示元件：版本號可不給（後台預覽讀不到版本時），給了照舊顯示。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/screens/terms/widgets/terms_document_view.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  testWidgets('給版本號時顯示「第 N 版」', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const TermsDocumentView(title: '服務條款', version: 3, contentMd: '內文'),
      ),
    );
    expect(find.text('第 3 版'), findsOneWidget);
  });

  testWidgets('不給版本號時不顯示版本那一行，標題與全文照常', (tester) async {
    await tester.pumpWidget(
      _wrap(const TermsDocumentView(title: '服務條款', contentMd: '內文')),
    );
    expect(find.textContaining(RegExp(r'第 \d+ 版')), findsNothing);
    expect(find.text('服務條款'), findsOneWidget);
    expect(find.text('內文'), findsOneWidget);
  });
}
