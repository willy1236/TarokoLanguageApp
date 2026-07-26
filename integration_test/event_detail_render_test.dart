// ignore_for_file: avoid_print
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flutter_application_1/firebase_options.dart';
import 'package:flutter_application_1/screens/plaza/event_detail_screen.dart';

// 直接 pump EventDetailScreen(eventId: 6)（已知是 effective_status=ended 的活動，
// 見 api_inspector_test.dart 的輸出），繞過導覽流程，專門抓渲染期間真正丟出的例外。
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('EventDetailScreen 渲染已結束活動 (id=6) 不應丟例外', (tester) async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

    await tester.pumpWidget(const MaterialApp(
      home: EventDetailScreen(eventId: 6),
    ));

    // 給 _load() 的 Future.wait 足夠時間完成。
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(tester.takeException(), isNull, reason: '渲染已結束活動不應丟例外');

    // 迴歸重點：底部行動列的 disabled 按鈕曾用裸 Center，在 Scaffold
    // bottomNavigationBar 的有界高度下撐滿整個高度，把 CustomScrollView 的
    // 高度擠成 0，導致詳情內容（hero、時間、地點…）完全不渲染。
    final csvSize = tester.getSize(find.byType(CustomScrollView));
    print('CustomScrollView size: $csvSize');
    expect(csvSize.height, greaterThan(0),
        reason: 'body 被底部行動列擠成 0 高，詳情內容不會顯示');

    // hero 標題與底部狀態字樣都應該出現。
    expect(find.text('403驗證用活動'), findsOneWidget);
    expect(find.text('活動已結束'), findsOneWidget);

    for (final el in find.byType(Text).evaluate()) {
      print('Text: "${(el.widget as Text).data}"');
    }
  });
}
