import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_1/core/constants/api.dart';
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

  /// [avatarCatalog] 為 null 時模擬 GET /api/shop/avatars 尚未開放（404），
  /// 對應 profile_screen.dart 不做本地素材 fallback 的現況。
  Future<void> pumpProfile(
    WidgetTester tester,
    Map<String, dynamic> meJson, {
    List<Map<String, dynamic>>? avatarCatalog,
  }) async {
    final client = MockClient((request) async {
      final url = request.url.toString();
      if (url == ApiConfig.baseUrl + ApiConfig.meEndpoint) {
        return http.Response.bytes(
          utf8.encode(jsonEncode(meJson)),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (url == ApiConfig.baseUrl + ApiConfig.shopAvatars) {
        if (avatarCatalog == null) {
          return http.Response('Not Found', 404);
        }
        return http.Response.bytes(
          utf8.encode(jsonEncode({'avatars': avatarCatalog})),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response('Not Found', 404);
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
      // fetchMe()／fetchAvatarCatalog() 是非同步呼叫，先 pump 讓 initState 內的 Future 有機會執行。
      await tester.pump();
      await tester.pump();
    }, () => client);
  }

  testWidgets('avatarId 非 null 且後端目錄有對應 image_url 時渲染 Image.network', (tester) async {
    await pumpProfile(
      tester,
      {
        'uid': 'u1',
        'avatar_id': 'avatar_general_01',
        'owned_avatar_ids': ['avatar_general_01'],
        'millet': 0,
      },
      avatarCatalog: [
        {
          'id': 'avatar_general_01',
          'name': '頭像 1',
          'price': 50,
          'rarity': 'common',
          'unlock_condition': null,
          'image_url': 'https://example.com/avatar_general_01.png',
          'is_owned': true,
        },
      ],
    );

    final heroImageFinder = find.byWidgetPredicate(
      (w) =>
          w is Image &&
          w.image is NetworkImage &&
          (w.image as NetworkImage).url ==
              'https://example.com/avatar_general_01.png' &&
          w.width == 80,
    );
    expect(heroImageFinder, findsOneWidget);
  });

  testWidgets(
    'avatarId 非 null 但後端目錄拿不到（功能尚未開放）時顯示預設圖示，不 fallback 顯示 avatarUrl',
    (tester) async {
      await pumpProfile(tester, {
        'uid': 'u1',
        'avatar_id': 'avatar_general_01',
        'avatar_url': 'https://example.com/google.png',
        'millet': 0,
      });

      // 使用者已選內建頭像，拿不到對應圖片時應顯示預設圖示，
      // 不能 fallback 顯示 avatarUrl（那會誤導成「這是目前配戴的頭像」）。
      expect(find.byIcon(Icons.person), findsOneWidget);
      final networkImageFinder = find.byWidgetPredicate(
        (w) => w is Image && w.image is NetworkImage,
      );
      expect(networkImageFinder, findsNothing);
    },
  );

  testWidgets('avatarId 為 null 但 avatarUrl 非 null 時渲染 Image.network', (tester) async {
    await pumpProfile(tester, {
      'uid': 'u1',
      'avatar_url': 'https://example.com/avatar.png',
      'millet': 0,
    });

    // 測試環境下 TestWidgetsFlutterBinding 會讓所有 HttpClient 請求回傳 400，
    // Image.network 因此會觸發 errorBuilder 退回 Icons.person 佔位圖示；
    // 這裡驗證的是渲染路徑選對了 Image.network（而非其他來源），
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
