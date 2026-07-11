// 頭像兌換／更換 API 呼叫骨架（issue #12）
//
// 後端目前只有 GET /api/me，尚未提供頭像商店相關端點：
//   - POST /api/shop/avatars/{id}/purchase（尚未存在）
//   - PATCH /api/me 帶 avatar_id（尚未存在）
// 呼叫這兩支時若後端回 404 或連線失敗，一律拋出 [ShopFeatureUnavailableException]，
// 讓呼叫端（Task 3、Task 4 的 UI）可以辨識並顯示「功能尚未開放」，而不是誤判為一般錯誤。
//
// HTTP 呼叫模式沿用 lib/services/auth_service.dart：
//   - 用 package:http 的 http.get/post/patch
//   - Authorization header 帶 Bearer token（token 由 AuthService.currentToken() 取得）
//   - jsonDecode(resp.body) 解析回應

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../core/constants/api.dart';
import '../models/user_model.dart';
import 'auth_service.dart';

class ShopService {
  /// 呼叫既有 GET /api/me，解析為 [UserModel]。
  /// 後端目前不會回傳 avatarId/ownedAvatarIds/coins，這些欄位會是 UserModel 的預設值
  /// （這是預期行為，不是 bug，見 user_model.dart 註解）。
  static Future<UserModel> fetchMe() async {
    final token = await AuthService.currentToken();
    late final http.Response resp;
    try {
      resp = await http.get(
        Uri.parse(ApiConfig.baseUrl + ApiConfig.meEndpoint),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
    } on SocketException {
      throw ShopFeatureUnavailableException('無法連線到伺服器');
    }

    if (resp.statusCode != 200) {
      throw ShopFeatureUnavailableException(_parseError(resp.body));
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return UserModel.fromJson(data);
  }

  /// 呼叫 POST /api/shop/avatars/{id}/purchase（尚未存在的端點）。
  /// 404 或連線失敗時拋出 [ShopFeatureUnavailableException]。
  static Future<UserModel> purchaseAvatar(String avatarId) async {
    final token = await AuthService.currentToken();
    late final http.Response resp;
    try {
      resp = await http.post(
        Uri.parse(
          ApiConfig.baseUrl + ApiConfig.avatarPurchaseEndpoint(avatarId),
        ),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
    } on SocketException {
      throw ShopFeatureUnavailableException('頭像商店功能尚未開放');
    }

    if (resp.statusCode == 404) {
      throw ShopFeatureUnavailableException('頭像商店功能尚未開放');
    }
    if (resp.statusCode != 200) {
      throw ShopFeatureUnavailableException(_parseError(resp.body));
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return UserModel.fromJson(data);
  }

  /// 呼叫 PATCH /api/me 帶 avatar_id（尚未存在的行為）。
  /// 404 或連線失敗時拋出 [ShopFeatureUnavailableException]。
  static Future<UserModel> equipAvatar(String avatarId) async {
    final token = await AuthService.currentToken();
    late final http.Response resp;
    try {
      resp = await http.patch(
        Uri.parse(ApiConfig.baseUrl + ApiConfig.meEndpoint),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'avatar_id': avatarId}),
      );
    } on SocketException {
      throw ShopFeatureUnavailableException('更換頭像功能尚未開放');
    }

    if (resp.statusCode == 404) {
      throw ShopFeatureUnavailableException('更換頭像功能尚未開放');
    }
    if (resp.statusCode != 200) {
      throw ShopFeatureUnavailableException(_parseError(resp.body));
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final updated = UserModel.fromJson(data);

    // PATCH /api/me 是既有端點，即使後端尚未支援 avatarId 欄位，也可能靜默忽略並回傳 200。
    // 若回傳的 avatarId 與請求的不一致，代表後端其實沒有真的套用這次更換，
    // 不可視為成功，否則會誤導使用者「已配戴」但其實沒有持久化。
    if (updated.avatarId != avatarId) {
      throw ShopFeatureUnavailableException('更換頭像功能尚未開放');
    }

    return updated;
  }

  static String _parseError(String body) {
    try {
      final j = jsonDecode(body);
      return j['error']?['message'] ?? '請求失敗';
    } catch (_) {
      return '請求失敗';
    }
  }
}

/// 呼叫尚未存在的頭像商店端點（404）或連線失敗時拋出，
/// 讓呼叫端可以辨識並顯示「功能尚未開放」而非一般錯誤訊息。
class ShopFeatureUnavailableException implements Exception {
  final String message;
  ShopFeatureUnavailableException(this.message);
  @override
  String toString() => message;
}
