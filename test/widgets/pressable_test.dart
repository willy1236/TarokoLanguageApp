// Pressable：點擊、按壓回饋與 button 語意。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/shared/widgets/pressable.dart';

void main() {
  testWidgets('點擊呼叫 onTap；按住時淡出、放開恢復', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Pressable(onTap: () => taps++, child: const Text('進入')),
      ),
    );
    double opacity() =>
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity;

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('進入')),
    );
    await tester.pump();
    expect(opacity(), lessThan(1));
    await gesture.up();
    await tester.pump();
    expect(opacity(), 1);
    expect(taps, 1);
  });

  testWidgets('語意是 button，文字併入 label，selected 狀態帶出', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Pressable(onTap: () {}, selected: true, child: const Text('初級')),
      ),
    );
    expect(
      tester.getSemantics(find.text('初級')),
      isSemantics(
        label: '初級',
        isButton: true,
        isSelected: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('semanticLabel 取代子孫內容（icon 按鈕用）', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Pressable(
          onTap: () {},
          semanticLabel: '查看作者個人頁',
          child: const Icon(Icons.person),
        ),
      ),
    );
    expect(
      tester.getSemantics(find.byIcon(Icons.person)),
      isSemantics(label: '查看作者個人頁', isButton: true, hasTapAction: true),
    );
    handle.dispose();
  });

  testWidgets('onTap 為 null：不回應點擊', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Pressable(onTap: null, child: Text('停用'))),
    );
    await tester.tap(find.text('停用'));
    await tester.pump();
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      1,
    );
  });
}
