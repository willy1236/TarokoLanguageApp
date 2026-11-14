// 商店卡片：兌換與配戴要能分辨；已擁有的商品不再顯示價格。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/shared/widgets/shop_item_card.dart';

Widget _card({
  bool owned = false,
  String? actionLabel,
  ShopActionKind kind = ShopActionKind.equip,
  VoidCallback? onAction,
}) => MaterialApp(
  home: Scaffold(
    body: SizedBox(
      width: 130,
      height: 240,
      child: ShopItemCard(
        name: '頭像（紅）1',
        price: 50,
        isGold: false,
        icon: Icons.face_rounded,
        owned: owned,
        actionLabel: actionLabel,
        actionKind: kind,
        onAction: onAction,
      ),
    ),
  ),
);

BoxDecoration _buttonDecoration(WidgetTester tester, String label) {
  final container = tester.widget<Container>(
    find.ancestor(of: find.text(label), matching: find.byType(Container)).first,
  );
  return container.decoration! as BoxDecoration;
}

void main() {
  testWidgets('未擁有：顯示價格', (tester) async {
    await tester.pumpWidget(_card());
    expect(find.text('50'), findsOneWidget);
  });

  testWidgets('已擁有：不顯示價格', (tester) async {
    await tester.pumpWidget(_card(owned: true));
    expect(find.text('50'), findsNothing);
    expect(find.text('已擁有'), findsOneWidget);
  });

  testWidgets('兌換是實心酒紅，配戴是外框線，兩者外觀不同', (tester) async {
    await tester.pumpWidget(
      _card(actionLabel: '兌換', kind: ShopActionKind.purchase, onAction: () {}),
    );
    final purchase = _buttonDecoration(tester, '兌換');
    expect(purchase.color, AppColors.primary);
    expect(purchase.border, isNull);

    await tester.pumpWidget(
      _card(owned: true, actionLabel: '配戴', onAction: () {}),
    );
    final equip = _buttonDecoration(tester, '配戴');
    expect(equip.color, Colors.transparent);
    expect(equip.border, isNotNull);
  });

  testWidgets('停用（已配戴）是灰底，不可點', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_card(owned: true, actionLabel: '已配戴'));
    expect(_buttonDecoration(tester, '已配戴').color, AppColors.creamDeep);
    await tester.tap(find.text('已配戴'));
    expect(taps, 0);
  });
}
