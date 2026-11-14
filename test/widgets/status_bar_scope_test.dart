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
}
