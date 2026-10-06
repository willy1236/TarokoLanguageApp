import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/shared/widgets/module_header_actions.dart';

void main() {
  Widget host({required bool hasUnread, bool seniorMode = false}) =>
      MaterialApp(
        home: Scaffold(
          body: ModuleActionIcons(
            onSearch: () {},
            notificationsTooltip: '通知',
            onNotifications: () {},
            hasUnread: hasUnread,
            seniorMode: seniorMode,
          ),
        ),
      );

  const dot = ValueKey('module-unread-dot');

  testWidgets('有未讀時鈴鐺帶紅點，沒有就不畫', (tester) async {
    await tester.pumpWidget(host(hasUnread: true));
    expect(find.byKey(dot), findsOneWidget);

    await tester.pumpWidget(host(hasUnread: false));
    expect(find.byKey(dot), findsNothing);
  });

  testWidgets('長輩模式紅點放大', (tester) async {
    await tester.pumpWidget(host(hasUnread: true));
    final normal = tester.getSize(find.byKey(dot));

    await tester.pumpWidget(host(hasUnread: true, seniorMode: true));
    final senior = tester.getSize(find.byKey(dot));

    expect(senior.width, greaterThan(normal.width));
    expect(normal.width, greaterThanOrEqualTo(12));
  });
}
