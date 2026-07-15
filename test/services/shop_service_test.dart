import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_1/core/constants/api.dart';
import 'package:flutter_application_1/services/shop_service.dart';

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

  group('ShopService.fetchAvatarCatalog', () {
    test('路由不存在的 404（純文字 body）時拋出 ShopFeatureUnavailableException', () async {
      final client = MockClient((request) async {
        expect(
          request.url.toString(),
          ApiConfig.baseUrl + ApiConfig.shopAvatars,
        );
        return http.Response('Cannot GET /api/shop/avatars', 404);
      });

      await expectLater(
        runWithClient(client, () => ShopService.fetchAvatarCatalog()),
        throwsA(isA<ShopFeatureUnavailableException>()),
      );
    });

    test('連線失敗時拋出 ShopFeatureUnavailableException', () async {
      final client = MockClient((request) async {
        throw const SocketException('connection failed');
      });

      await expectLater(
        runWithClient(client, () => ShopService.fetchAvatarCatalog()),
        throwsA(isA<ShopFeatureUnavailableException>()),
      );
    });

    test('解析 GET /api/shop/avatars 回應為 AvatarShopItem 清單', () async {
      final client = MockClient((request) async {
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'avatars': [
                {
                  'id': 'avatar_general_01',
                  'name': '頭像 1',
                  'price': 50,
                  'rarity': 'common',
                  'unlock_condition': null,
                  'image_url': null,
                  'is_owned': true,
                },
                {
                  'id': 'avatar_general_10',
                  'name': '頭像 10',
                  'price': 500,
                  'rarity': 'gold',
                  'unlock_condition': '完成每日任務累積 30 天',
                  'image_url': null,
                  'is_owned': false,
                },
              ],
            }),
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final avatars = await runWithClient(
        client,
        () => ShopService.fetchAvatarCatalog(),
      );

      expect(avatars, hasLength(2));
      expect(avatars[0].id, 'avatar_general_01');
      expect(avatars[0].isOwned, isTrue);
      expect(avatars[1].rarity, 'gold');
      expect(avatars[1].unlockCondition, '完成每日任務累積 30 天');
    });
  });

  group('ShopService.fetchMe', () {
    test('解析 GET /api/me 回應，缺少的欄位使用預設值', () async {
      final client = MockClient((request) async {
        expect(
          request.url.toString(),
          ApiConfig.baseUrl + ApiConfig.meEndpoint,
        );
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'uid': 'u1',
              'display_name': '小明',
              'avatar_url': 'https://example.com/a.png',
            }),
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final user = await runWithClient(client, () => ShopService.fetchMe());

      expect(user.uid, 'u1');
      expect(user.displayName, '小明');
      expect(user.avatarId, isNull);
      expect(user.ownedAvatarIds, isEmpty);
      expect(user.millet, 0);
    });
  });

  group('ShopService.purchaseAvatar', () {
    test('路由不存在的 404（純文字 body）時拋出 ShopFeatureUnavailableException', () async {
      final client = MockClient((request) async {
        return http.Response('Not Found', 404);
      });

      await expectLater(
        runWithClient(client, () => ShopService.purchaseAvatar('a1')),
        throwsA(isA<ShopFeatureUnavailableException>()),
      );
    });

    test('連線失敗時拋出 ShopFeatureUnavailableException', () async {
      final client = MockClient((request) async {
        throw const SocketException('connection failed');
      });

      await expectLater(
        runWithClient(client, () => ShopService.purchaseAvatar('a1')),
        throwsA(isA<ShopFeatureUnavailableException>()),
      );
    });

    test(
      '路由已存在但業務邏輯拒絕（帶正式 error.code 的 404）時拋出 ShopApiException，'
      '而非誤判為功能尚未開放',
      () async {
        final client = MockClient((request) async {
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'error': {
                  'code': 'AVATAR_NOT_FOUND',
                  'message': '頭像不存在',
                },
              }),
            ),
            404,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        });

        try {
          await runWithClient(client, () => ShopService.purchaseAvatar('a1'));
          fail('應該要拋出例外');
        } on ShopApiException catch (e) {
          expect(e.code, 'AVATAR_NOT_FOUND');
        }
      },
    );

    test('餘額不足（400 INSUFFICIENT_BALANCE）時拋出 ShopApiException', () async {
      final client = MockClient((request) async {
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'error': {
                'code': 'INSUFFICIENT_BALANCE',
                'message': '小米幣不足',
              },
            }),
          ),
          400,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      try {
        await runWithClient(client, () => ShopService.purchaseAvatar('a1'));
        fail('應該要拋出例外');
      } on ShopApiException catch (e) {
        expect(e.code, 'INSUFFICIENT_BALANCE');
      }
    });
  });

  group('ShopService.equipAvatar', () {
    test('404 時拋出 ShopFeatureUnavailableException', () async {
      final client = MockClient((request) async {
        return http.Response('Not Found', 404);
      });

      await expectLater(
        runWithClient(client, () => ShopService.equipAvatar('a1')),
        throwsA(isA<ShopFeatureUnavailableException>()),
      );
    });

    test('連線失敗時拋出 ShopFeatureUnavailableException', () async {
      final client = MockClient((request) async {
        throw const SocketException('connection failed');
      });

      await expectLater(
        runWithClient(client, () => ShopService.equipAvatar('a1')),
        throwsA(isA<ShopFeatureUnavailableException>()),
      );
    });

    test(
      '後端回 200 但 avatarId 未變更（PATCH /api/me 靜默忽略未支援欄位）時，'
      '應視為失敗並拋出 ShopFeatureUnavailableException，而非回傳假成功的 UserModel',
      () async {
        final client = MockClient((request) async {
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'uid': 'u1',
                'display_name': '小明',
                // 後端忽略了 avatarId，回傳的仍是舊值（或 null），與請求的 'a1' 不一致。
                'avatar_id': 'old_avatar',
              }),
            ),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        });

        await expectLater(
          runWithClient(client, () => ShopService.equipAvatar('a1')),
          throwsA(isA<ShopFeatureUnavailableException>()),
        );
      },
    );

    test('送出的 PATCH body 使用 avatar_id（snake_case），並在後端確認一致時成功', () async {
      Map<String, dynamic>? sentBody;
      final client = MockClient((request) async {
        sentBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'uid': 'u1',
              'display_name': '小明',
              'avatar_id': 'a1',
            }),
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final user = await runWithClient(
        client,
        () => ShopService.equipAvatar('a1'),
      );

      expect(sentBody, containsPair('avatar_id', 'a1'));
      expect(sentBody, isNot(contains('avatarId')));
      expect(user.avatarId, 'a1');
    });
  });
}

/// http 套件的頂層函式（http.get/post/patch）會用 http.Client 的 zone 覆寫，
/// 用 http.runWithClient 把測試用的 MockClient 注入該 zone。
Future<T> runWithClient<T>(http.Client client, Future<T> Function() body) {
  return http.runWithClient(body, () => client);
}
