import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_1/core/constants/api.dart';
import 'package:flutter_application_1/core/constants/avatar_catalog.dart';
import 'package:flutter_application_1/screens/profile/profile_screen.dart';

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

  Future<void> pumpProfile(WidgetTester tester, Map<String, dynamic> meJson) async {
    final client = MockClient((request) async {
      expect(request.url.toString(), ApiConfig.baseUrl + ApiConfig.meEndpoint);
      return http.Response.bytes(
        utf8.encode(jsonEncode(meJson)),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
      // fetchMe() 是非同步呼叫，先 pump 讓 initState 內的 Future 有機會執行。
      await tester.pump();
      await tester.pump();
    }, () => client);
  }

  testWidgets('avatarId 非 null 時渲染對應的 Image.asset', (tester) async {
    final item = kAvatarCatalog.first;
    await pumpProfile(tester, {
      'uid': 'u1',
      'avatar_id': item.id,
      'owned_avatar_ids': [item.id],
      'millet': 0,
    });

    final heroImageFinder = find.byWidgetPredicate(
      (w) =>
          w is Image &&
          w.image is AssetImage &&
          (w.image as AssetImage).assetName == item.assetPath &&
          w.width == 80,
    );
    expect(heroImageFinder, findsOneWidget);
  });

  testWidgets('avatarId 為 null 但 avatarUrl 非 null 時渲染 Image.network', (tester) async {
    await pumpProfile(tester, {
      'uid': 'u1',
      'avatar_url': 'https://example.com/avatar.png',
      'millet': 0,
    });

    // 測試環境下 TestWidgetsFlutterBinding 會讓所有 HttpClient 請求回傳 400，
    // Image.network 因此會觸發 errorBuilder 退回 Icons.person 佔位圖示；
    // 這裡驗證的是渲染路徑選對了 Image.network（而非 Image.asset），
    // 圖片載入失敗後 fallback 屬預期行為，不代表「無資料」情況。
    final networkImageFinder = find.byWidgetPredicate(
      (w) =>
          w is Image &&
          w.image is NetworkImage &&
          (w.image as NetworkImage).url == 'https://example.com/avatar.png',
    );
    expect(networkImageFinder, findsOneWidget);
  });

  testWidgets('avatarId 與 avatarUrl 皆為 null 時維持 Icons.person 佔位圖示', (tester) async {
    await pumpProfile(tester, {
      'uid': 'u1',
      'millet': 0,
    });

    expect(find.byIcon(Icons.person), findsOneWidget);
  });
}
