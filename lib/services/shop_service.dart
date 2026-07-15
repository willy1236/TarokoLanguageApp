// 頭像兌換／更換 API 呼叫骨架（issue #12）
//
// 後端目前只有 GET /api/me，尚未提供頭像商店相關端點：
//   - GET /api/shop/avatars（尚未存在）
//   - POST /api/shop/avatars/{id}/purchase（尚未存在）
//   - PATCH /api/me 帶 avatar_id（尚未存在）
//
// 錯誤分流原則：路由真的還不存在時，Express 預設 404 回的是純文字（如
// "Cannot GET /api/shop/avatars"），不是 app 的 JSON 錯誤格式 {error:{code,message}}；
// 一旦後端部署完成，路由存在但業務邏輯拒絕時，才會回傳帶 code 的正式錯誤（例如
// AVATAR_NOT_FOUND／INSUFFICIENT_BALANCE／ALREADY_OWNED／UNLOCK_CONDITION_NOT_MET／
// AVATAR_NOT_OWNED，見 Truku_backend#1）。因此用「body 能否解析出 error.code」來分流：
//   - 解析得到 code → 路由已存在，是真正的業務錯誤 → 拋 [ShopApiException]（帶 code）
//   - 解析不到（純文字/HTML/連線失敗）→ 路由還不存在 → 拋 [ShopFeatureUnavailableException]
// 讓呼叫端可以分別處理「功能尚未開放」與「這次操作真的被拒絕」兩種情境。
//
// HTTP 呼叫模式沿用 lib/services/auth_service.dart：
//   - 用 package:http 的 http.get/post/patch
//   - Authorization header 帶 Bearer token（token 由 AuthService.currentToken() 取得）
//   - jsonDecode(resp.body) 解析回應

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../core/constants/api.dart';
import '../models/avatar_shop_item.dart';
import '../models/user_model.dart';
import 'auth_service.dart';

class ShopService {
  /// 呼叫 GET /api/shop/avatars（尚未存在的端點），取得後端算好的完整頭像目錄
  /// （含 image_url／is_owned）。路由還不存在時拋 [ShopFeatureUnavailableException]，
  /// 呼叫端應 fallback 使用本地 kAvatarCatalog。
  static Future<List<AvatarShopItem>> fetchAvatarCatalog() async {
    final token = await AuthService.currentToken();
    late final http.Response resp;
    try {
      resp = await http.get(
        Uri.parse(ApiConfig.baseUrl + ApiConfig.shopAvatars),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
    } on SocketException {
      throw ShopFeatureUnavailableException('頭像商店功能尚未開放');
    }

    _throwIfError(resp, unavailableMessage: '頭像商店功能尚未開放');

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final list = data['avatars'] as List<dynamic>? ?? [];
    return list
        .map((e) => AvatarShopItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 呼叫既有 GET /api/me，解析為 [UserModel]。
  /// 後端目前不會回傳 avatar_id/owned_avatar_ids/millet，這些欄位會是 UserModel 的預設值
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

    _throwIfError(resp, unavailableMessage: '無法取得使用者資料');

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return UserModel.fromJson(data);
  }

  /// 呼叫 POST /api/shop/avatars/{id}/purchase（尚未存在的端點）。
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

    _throwIfError(resp, unavailableMessage: '頭像商店功能尚未開放');

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return UserModel.fromJson(data);
  }

  /// 呼叫 PATCH /api/me 帶 avatar_id（尚未存在的行為）。
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

    _throwIfError(resp, unavailableMessage: '更換頭像功能尚未開放');

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final updated = UserModel.fromJson(data);

    // PATCH /api/me 是既有端點，即使後端尚未支援 avatar_id 欄位，也可能靜默忽略並回傳 200。
    // 若回傳的 avatar_id 與請求的不一致，代表後端其實沒有真的套用這次更換，
    // 不可視為成功，否則會誤導使用者「已配戴」但其實沒有持久化。
    if (updated.avatarId != avatarId) {
      throw ShopFeatureUnavailableException('更換頭像功能尚未開放');
    }

    return updated;
  }

  /// 非 200 時分流拋出：body 能解析出 error.code → [ShopApiException]（真正的業務錯誤）；
  /// 否則（純文字/HTML，代表路由還不存在）→ [ShopFeatureUnavailableException]。
  static void _throwIfError(
    http.Response resp, {
    required String unavailableMessage,
  }) {
    if (resp.statusCode == 200) return;
    final apiError = _tryParseApiError(resp.body);
    if (apiError != null) throw apiError;
    throw ShopFeatureUnavailableException(unavailableMessage);
  }

  static ShopApiException? _tryParseApiError(String body) {
    try {
      final j = jsonDecode(body);
      final error = j['error'] as Map<String, dynamic>?;
      final code = error?['code'] as String?;
      if (code == null) return null;
      return ShopApiException(code, error?['message'] as String? ?? '請求失敗');
    } catch (_) {
      return null;
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

/// 後端路由已存在、回傳正式 {error:{code,message}} 格式的業務錯誤時拋出（見
/// Truku_backend#1：AVATAR_NOT_FOUND／INSUFFICIENT_BALANCE／ALREADY_OWNED／
/// UNLOCK_CONDITION_NOT_MET／AVATAR_NOT_OWNED 等），呼叫端可依 [code] 判斷後續行為，
/// 不應與「功能尚未開放」混為一談。
class ShopApiException implements Exception {
  final String code;
  final String message;
  ShopApiException(this.code, this.message);
  @override
  String toString() => message;
}
