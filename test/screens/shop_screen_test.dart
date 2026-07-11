import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_1/core/constants/api.dart';
import 'package:flutter_application_1/screens/shop/shop_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ShopService 內部經由 AuthService.currentToken() 讀取 flutter_secure_storage，
  // 測試環境沒有平台實作，用 mock method channel 讓它一律回傳 null（視為未登入/無 token）。
  const secureStorageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  TestWidgetsFlutterBinding.ensureInitialized()
      .defaultBinaryMessenger
      .setMockMethodCallHandler(secureStorageChannel, (call) async {
    if (call.method == 'read') return null;
    return null;
  });

  Future<void> pumpShop(
    WidgetTester tester, {
    required List<String> ownedAvatarIds,
    required int coins,
  }) async {
    final client = MockClient((request) async {
      expect(request.url.toString(), ApiConfig.baseUrl + ApiConfig.meEndpoint);
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'uid': 'u1',
            'display_name': '小明',
            'owned_avatar_ids': ownedAvatarIds,
            'coins': coins,
          }),
        ),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: ShopScreen()));
      // fetchMe() 是非同步呼叫，先 pump 讓 initState 內的 Future 有機會執行。
      await tester.pump();
      await tester.pump();
    }, () => client);
  }

  testWidgets('切換到「頭像 Lukus」分類會過濾出頭像清單，且徽章分類消失', (tester) async {
    await pumpShop(tester, ownedAvatarIds: ['avatar_general_01'], coins: 1000);

    // 預設「全部」分類同時看得到彩徽區塊與頭像區塊。
    expect(find.text('彩徽'), findsOneWidget);
    expect(find.text('頭像 Lukus'), findsWidgets);

    await tester.tap(find.text('頭像 Lukus').last);
    await tester.pump();

    // 切到頭像分類後，彩徽／金徽區塊應該被過濾掉。
    expect(find.text('彩徽'), findsNothing);
    expect(find.text('金徽'), findsNothing);
  });

  testWidgets('頭像卡片依 owned/locked/purchasable 顯示對應狀態', (tester) async {
    await pumpShop(tester, ownedAvatarIds: ['avatar_general_01'], coins: 1000);

    await tester.tap(find.text('頭像 Lukus').last);
    await tester.pump();

    // 已擁有的頭像應顯示「配戴」按鈕與「已擁有」標籤。
    expect(find.text('配戴'), findsWidgets);
    expect(find.text('已擁有'), findsWidgets);

    // 未擁有、金幣充足、且無解鎖條件的頭像應顯示「兌換」按鈕。
    expect(find.text('兌換'), findsWidgets);

    // 有解鎖條件（金頭像）且未擁有時應顯示解鎖條件文字，不顯示按鈕。
    expect(find.text('完成每日任務累積 30 天'), findsWidgets);
  });

  testWidgets('coins 為 0（真實後端預設值）時，未擁有且未鎖定的頭像仍應顯示可點擊的「兌換」按鈕', (tester) async {
    await pumpShop(tester, ownedAvatarIds: const [], coins: 0);

    await tester.tap(find.text('頭像 Lukus').last);
    await tester.pump();

    // 即使 coins 不足，兌換按鈕仍必須渲染，讓兌換流程可被觸及／測試。
    expect(find.text('兌換'), findsWidgets);
  });

  testWidgets('點擊兌換按鈕呼叫尚未存在的後端端點時顯示「功能尚未開放」', (tester) async {
    await pumpShop(tester, ownedAvatarIds: const [], coins: 1000);

    await tester.tap(find.text('頭像 Lukus').last);
    await tester.pump();

    final client = MockClient((request) async {
      return http.Response('Not Found', 404);
    });

    await http.runWithClient(() async {
      await tester.tap(find.text('兌換').first);
      await tester.pump();
    }, () => client);

    expect(find.text('功能尚未開放'), findsOneWidget);
  });
}
