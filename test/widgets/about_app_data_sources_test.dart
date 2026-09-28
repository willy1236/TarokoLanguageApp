// 關於頁「資料來源與授權」區塊：開關關閉時完全不出現；打開時窄螢幕不 overflow。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/screens/profile/about_app_screen.dart';

import '../helpers/flow_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpAbout(WidgetTester tester, {bool? show}) async {
    usePhoneSurface(tester, size: const Size(320, 800));
    await tester.pumpWidget(
      MaterialApp(home: AboutAppScreen(debugShowDataSources: show)),
    );
    await tester.pump();
  }

  testWidgets('開關預設關閉：不出現資料來源與授權區塊', (tester) async {
    await pumpAbout(tester);
    expect(find.text('資料來源與授權', skipOffstage: false), findsNothing);
  });

  testWidgets('打開時在 320dp 寬度顯示區塊且不 overflow', (tester) async {
    await pumpAbout(tester, show: true);
    await tester.scrollUntilVisible(
      find.text('資料來源與授權'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('資料來源與授權'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
