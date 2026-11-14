// 狀態列圖示明暗：米白底深色圖示、深色底淺色圖示。

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/shared/widgets/status_bar_scope.dart';

SystemUiOverlayStyle _styleOf(WidgetTester tester) => tester
    .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
    )
    .value;

void main() {
  testWidgets('onLight：Android 深色圖示、iOS 底色為淺', (tester) async {
    await tester.pumpWidget(
      const StatusBarScope.onLight(child: SizedBox.shrink()),
    );
    final style = _styleOf(tester);
    expect(style.statusBarIconBrightness, Brightness.dark);
    expect(style.statusBarBrightness, Brightness.light);
    expect(style.statusBarColor, Colors.transparent);
  });

  testWidgets('onDark：Android 淺色圖示、iOS 底色為深', (tester) async {
    await tester.pumpWidget(
      const StatusBarScope.onDark(child: SizedBox.shrink()),
    );
    final style = _styleOf(tester);
    expect(style.statusBarIconBrightness, Brightness.light);
    expect(style.statusBarBrightness, Brightness.dark);
  });

  group('樹上有多個 StatusBarScope 時，畫面上最內層、有畫出來的那個生效', () {
    SystemUiOverlayStyle? styleAtTop(WidgetTester tester) => tester
        .binding
        .renderViews
        .first
        .debugLayer!
        .find<SystemUiOverlayStyle>(const Offset(100, 10));

    Widget app(int index) => MaterialApp(
      home: StatusBarScope.onLight(
        child: Scaffold(
          body: IndexedStack(
            index: index,
            children: const [
              SizedBox.expand(),
              StatusBarScope.onDark(child: SizedBox.expand()),
            ],
          ),
        ),
      ),
    );

    testWidgets('顯示深色分頁：淺色圖示', (tester) async {
      await tester.pumpWidget(app(1));
      expect(styleAtTop(tester), StatusBarScope.darkBackgroundStyle);
    });

    testWidgets('切到沒有 scope 的分頁：落回外層預設的深色圖示，不殘留', (tester) async {
      await tester.pumpWidget(app(1));
      await tester.pumpWidget(app(0));
      expect(styleAtTop(tester), StatusBarScope.lightBackgroundStyle);
    });
  });
}
