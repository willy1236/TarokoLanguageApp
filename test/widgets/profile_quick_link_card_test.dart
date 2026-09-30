// 個人頁快速入口卡片：收件匣那格有未讀時顯示數字徽章。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/screens/profile/widgets/profile_rows.dart';

void main() {
  Future<void> pump(WidgetTester tester, int count) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: profileQuickLinkCard(
          ProfileQuickLink(
            icon: Icons.inbox_outlined,
            label: '收件匣',
            onTap: () {},
          ),
          seniorMode: false,
          badgeCount: count,
        ),
      ),
    ),
  );

  testWidgets('有未讀顯示數字，超過 99 顯示 99+，沒有未讀不顯示徽章', (tester) async {
    await pump(tester, 3);
    expect(find.text('3'), findsOneWidget);

    await pump(tester, 120);
    expect(find.text('99+'), findsOneWidget);

    await pump(tester, 0);
    expect(find.byType(Badge), findsNothing);
  });
}
